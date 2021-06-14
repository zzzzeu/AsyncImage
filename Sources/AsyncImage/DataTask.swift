import Foundation
import UIKit

final class DataTask {
    let task: URLSessionDataTask
    let url: URL
    let lock = NSLock()
    var data: Data
    var started = false
    var completionHandlersStore = [Int: ImageService.Completion]()
    var currentToken = 0
    
    var onCancelled: ((URL, Int, ImageService.Completion) -> Void)?
    var containsCompletions: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        return !completionHandlersStore.isEmpty
    }
    
    init(task: URLSessionDataTask, url: URL) {
        self.task = task
        self.url = url
        data = Data()
    }
    
    func resume() {
        if started {
            return
        }
        self.started = true
        task.resume()
    }
    
    func addCompletion(_ completion: ImageService.Completion) -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }
        completionHandlersStore[currentToken] = completion
        defer {
            currentToken += 1
        }
        return currentToken
    }
    
    func removeCompletion(_ token: Int) -> ImageService.Completion? {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let completion = completionHandlersStore[token] {
            completionHandlersStore[token] = nil
            return completion
        }
        return nil
    }
    
    func cancel(token: Int) {
        guard let completion = removeCompletion(token) else {
            return
        }
        onCancelled?(url, token, completion)
    }
    
    func didReceiveData(_ data: Data) {
        self.data.append(data)
    }
    
    func complete(result: Result<Data, ImageService.ImageError>) {
        lock.lock()
        switch result {
        case .success(let data):
            for completion in completionHandlersStore.values {
                if let image = UIImage(data: data, scale: completion.scale) {
                    completion.handler(.success(image))
                } else {
                    completion.handler(.failure(.decodingError))
                }
            }
        case .failure(let error):
            for completion in completionHandlersStore.values {
                completion.handler(.failure(error))
            }
        }
        lock.unlock()
    }
    
}
