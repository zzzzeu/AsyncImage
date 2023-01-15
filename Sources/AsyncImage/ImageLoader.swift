import Foundation
import UIKit
import SwiftUI
import Combine

final class ImageLoader: ObservableObject {
    @Published var asyncImagePhase = AsyncImagePhase.empty
    let scale: CGFloat
    let url: URL?
    let processor: ImageProcessor?
    var downloadTask: DownloadTask?
    
    init(url: URL?, scale: CGFloat, processor: ImageProcessor?) {
        self.url = url
        self.scale = scale
        self.processor = processor
    }
    
    deinit {}
    
    func loadImage() {
        guard let url = url, asyncImagePhase.image == nil else { return }
        downloadTask = ImageService.shared.fetchImage(url: url, scale: scale) {
            [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let image):
                    var image = image
                    if let processor = self.processor {
                        // Processing the fetched image here to keep the cached image untouched.
                        image = processor.process(image: image)
                    }
                    self.asyncImagePhase = .success(Image(uiImage: image))
                case .failure(let error):
                    if error.isCanceled { return }
                    self.asyncImagePhase = .failure(error)
                }
                
                self.downloadTask = nil
            }
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
    }
}
