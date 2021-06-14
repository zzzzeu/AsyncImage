import SwiftUI

public enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
    
    var image: Image? {
        guard case .success(let image) = self else { return nil }
        return image
    }
    
    var error: Error? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

public struct AsyncImage<Content: View>: View {
    @ObservedObject var loader: ImageLoader
    var content: ((AsyncImagePhase) -> Content)?
    
    @ViewBuilder
    var contentOrImage: some View {
        if let content = content {
            content(loader.asyncImagePhase)
        } else if let image = loader.asyncImagePhase.image {
            image
        } else {
            Color(.secondarySystemBackground)
        }
    }
    
    public var body: some View {
        contentOrImage
            .onAppear { loader.loadImage() }
            .onDisappear { loader.cancelDownload() }
    }
    
    public init(url: URL, scale: CGFloat = 1) where Content == Image {
        loader = ImageLoader(url: url, scale: scale)
    }
    
    public init<I: View, P: View>(
        url: URL?,
        scale: CGFloat = 1,
        content: @escaping (Image) -> I,
        placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(url: url, scale: scale) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }

    public init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.content = content
        loader = ImageLoader(url: url, scale: scale)
    }
}
