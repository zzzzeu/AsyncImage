import Foundation
import UIKit
import CommonCrypto

public final class ImageService: NSObject {
    public enum ImageError: Error {
        case decodingError
        case taskCancel
        case downloadError(Error)
        case invalidURLResponse
        
        public var isCanceled: Bool {
            guard case .taskCancel = self else { return false }
            return true
        }
    }
    
    struct Completion {
        let scale: CGFloat
        let handler: (Result<UIImage, ImageError>) -> Void
    }
    
    public static let shared = ImageService()
    
    let memoryCache = LRUCache<URL, Cache>(30 * 1024 * 1024)
    let lock = NSLock()
    let session: URLSession
    let sessionDelegat = SessionDelegate()
    let ioQueue: DispatchQueue
    
    lazy var folderURL: URL = {
        let url: URL
        do {
            url = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
        } catch let error {
            fatalError("\(error)")
        }
        let folderUrl = url.appendingPathComponent("com.zeu.cache", isDirectory: true)
        if FileManager.default.fileExists(atPath: folderUrl.path) {
            return folderUrl
        }
        
        do {
            try FileManager.default.createDirectory(
                atPath: folderUrl.path,
                withIntermediateDirectories: true,
                attributes: nil)
        } catch let error {
            print(error)
        }
        return folderUrl
    }()
    
    private override init() {
        ioQueue = DispatchQueue(label: "com.zeu.AsyncImage.ioQueue")
        session = URLSession(configuration: .ephemeral, delegate: sessionDelegat, delegateQueue: nil)
        super.init()
        sessionDelegat.onTaskFinished = { [weak self] url, cache in
            self?.storeToMemory(url: url, cache: cache)
            self?.storeToDisk(value: cache.data, forKey: url.absoluteString)
        }
    }
    
    public func fetchImage(url: URL, scale: CGFloat, completionHandler: @escaping (Result<UIImage, ImageError>) -> Void) -> DownloadTask? {
        if let image = fetchImageInMemory(url: url, scale: scale) {
            completionHandler(.success(image))
            return nil
        }
        if isDiskCached(for: url.absoluteString) {
            fetchFromDisk(forKey: url.absoluteString) { data in
                if let data = data {
                    self.storeToMemory(url: url, cache: Cache(data: data, cacheType: .downloaded))
                    if let image = UIImage(data: data, scale: scale) {
                        completionHandler(.success(image))
                        return
                    }
                }
                completionHandler(.failure(.decodingError))
            }
            return nil
        } else {
            let task = addDownloadTask(url: url, completion: Completion(scale: scale, handler: completionHandler))
            task.dataTask.resume()
            return task
        }
    }
}

extension ImageService {
    func addDownloadTask(url: URL, completion: Completion) -> DownloadTask {
        let downloadTask: DownloadTask
        if let existingTask = sessionDelegat.task(for: url) {
            downloadTask = sessionDelegat.append(existingTask, completion: completion)
        } else {
            let sessionDataTask: URLSessionDataTask
            lock.lock()
            defer {
                lock.unlock()
            }
            if let cache = memoryCache[url], case .resumable(let validator) = cache.cacheType {
                var urlRequest = URLRequest(url: url)
                var headers = urlRequest.allHTTPHeaderFields ?? [:]
                headers["Range"] = "bytes=\(cache.memoryCost)-"
                headers["If-Range"] = validator
                urlRequest.allHTTPHeaderFields = headers
                sessionDataTask = session.dataTask(with: urlRequest)
                downloadTask = sessionDelegat.addTask(sessionDataTask, url: url, data: cache.data, completion: completion)
            } else {
                downloadTask = sessionDelegat.addTask(session.dataTask(with: url), url: url, completion: completion)
            }
        }
        return downloadTask
    }
    
}

extension ImageService {
    func storeToMemory(url: URL, cache: Cache) {
        lock.lock()
        memoryCache[url] = cache
        lock.unlock()
    }
    
    func fetchImageInMemory(url: URL, scale: CGFloat) -> UIImage? {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let data = memoryCache[url]?.data, let image = UIImage(data: data, scale: scale) {
            return image
        } else {
            return nil
        }
    }
}

extension ImageService {
    func isDiskCached(for key: String) -> Bool {
        FileManager.default.fileExists(atPath: cacheFileURL(forKey: key).path)
    }
    
    func cacheFileURL(forKey key: String) -> URL {
        folderURL.appendingPathComponent(key.sha256)
    }
    
    func storeToDisk(value: Data, forKey key: String) {
        ioQueue.async {
            let fileURL = self.cacheFileURL(forKey: key)
            let now = Date()
            let attributes: [FileAttributeKey : Any] = [.creationDate: Date(timeIntervalSince1970: ceil(now.timeIntervalSince1970))]
            FileManager.default.createFile(atPath: fileURL.path, contents: value, attributes: attributes)
        }
    }
    
    func fetchFromDisk(forKey key: String, completion: @escaping (Data?) -> Void) {
        ioQueue.async {
            let fileManager = FileManager.default
            let fileURL = self.cacheFileURL(forKey: key)
            let filePath = fileURL.path
            guard fileManager.fileExists(atPath: filePath) else {
                completion(nil)
                return
            }
            do {
                let data = try Data(contentsOf: fileURL)
                completion(data)
            } catch {
                completion(nil)
            }
        }
    }
}

struct Cache: MemoryCostValue {
    enum CacheType: Equatable {
        case downloaded
        case resumable(String?)
    }
    var data: Data
    var cacheType: CacheType
    
    var memoryCost: Int {
        return data.count
    }
}

public struct DownloadTask {
    let dataTask: DataTask
    let cancelToken: Int
    
    func cancel() {
        dataTask.cancel(token: cancelToken)
    }
}

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
