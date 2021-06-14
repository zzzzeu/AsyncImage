import Foundation
import UIKit

final class SessionDelegate: NSObject {
    var tasks: [URL: DataTask] = [:]
    var onTaskFinished: ((URL, Cache) -> Void)?
    var lock = NSLock()
    
    func addTask(_ dataTask: URLSessionDataTask, url: URL, data: Data? = nil, completion: ImageService.Completion) -> DownloadTask {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        let task = DataTask(task: dataTask, url: url)
        if let data = data {
            task.data = data
        }
        task.onCancelled = { [weak self] url, token, completion in
            guard let self = self, let task = self.task(for: url) else {
                return
            }
            
            let error = ImageService.ImageError.taskCancel
            completion.handler(.failure(error))
            if !task.containsCompletions {
                let dataTask = task.task
                
                self.lock.lock()
                dataTask.cancel()
                self.tasks[url] = nil
                self.lock.unlock()
                
            }
        }
        let token = task.addCompletion(completion)
        tasks[url] = task
        return DownloadTask(dataTask: task, cancelToken: token)
    }
    
    func append(_ task: DataTask, completion: ImageService.Completion) -> DownloadTask {
        let token = task.addCompletion(completion)
        return DownloadTask(dataTask: task, cancelToken: token)
    }
    
    func task(for url: URL) -> DataTask? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return tasks[url]
    }
    
    func task(for task: URLSessionTask) -> DataTask? {
        guard let url = task.originalRequest?.url, let dataTask = self.task(for: url) else {
            return nil
        }
        return dataTask
    }
}

extension SessionDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            onCompleted(task: dataTask, error: .invalidURLResponse)
            completionHandler(.cancel)
            return
        }
        let httpStatusCode = httpResponse.statusCode
        guard (200..<400).contains(httpStatusCode) else {
            onCompleted(task: dataTask, error: .invalidURLResponse)
            completionHandler(.cancel)
            return
        }
        if httpStatusCode == 200, let task = self.task(for: dataTask) {
            task.data = Data()
        }
        completionHandler(.allow)
    }
        
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = self.task(for: dataTask) else {
            return
        }
        task.didReceiveData(data)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            onCompleted(task: task, error: .downloadError(error))
            return
        }
        onCompleted(task: task)
    }
    
    func onCompleted(task: URLSessionTask, error: ImageService.ImageError? = nil) {
        guard let dataTask = self.task(for: task) else {
            return
        }
        onCompleted(dataTask: dataTask, error: error)
    }
    
    func onCompleted(dataTask: DataTask, error: ImageService.ImageError? = nil) {
        lock.lock()
        tasks[dataTask.url] = nil
        lock.unlock()
        if error == nil {
            dataTask.complete(result: .success(dataTask.data))
            onTaskFinished?(dataTask.url, Cache(data: dataTask.data, cacheType: .downloaded))
        } else {
            guard !dataTask.data.isEmpty,
                  let response = dataTask.task.response as? HTTPURLResponse,
                  dataTask.data.count < response.expectedContentLength,
                  response.statusCode == 200 || response.statusCode == 206,
                  let acceptRanges = response.allHeaderFields["Accept-Ranges"] as? String,
                  acceptRanges.lowercased() == "bytes"
            else {
                return
            }
            let headers = response.allHeaderFields
            if let validator = (headers["ETag"] ?? headers["Etag"] ?? headers["Last-Modified"]) as? String {
                onTaskFinished?(dataTask.url, Cache(data: dataTask.data, cacheType: .resumable(validator)))
            } else {
                onTaskFinished?(dataTask.url, Cache(data: dataTask.data, cacheType: .resumable(nil)))
            }
        }
    }
}
