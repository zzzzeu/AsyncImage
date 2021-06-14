# AsyncImage
Self Implemented [AsyncImage](https://developer.apple.com/documentation/swiftui/asyncimage) usable down to iOS 13 which is more efficiency due to the implemented features below:
- Loads the image only when it appears on the screen
- Automatically cancel download request when it disappears
- Resumable download will picks up where it left off when the view appears again
- Self-implemented `LRUCache` is used to handle memory cache
- Also save cached data to Disk in background queue

> WARNING. It's still in ealry beta.

## Getting start
You can clone this repository and run the `AsyncImageExample`.

Async image API is completly same with the great `AsyncImage` implemented by Apply team which has been fully documented [here](https://developer.apple.com/documentation/swiftui/asyncimage).
```swift
AsyncImage(url: URL(string: "https://example.com/icon.png"))
    .frame(width: 200, height: 200)
```
Until the image loads, the view displays a standard placeholder that fills the available space. After the load completes successfully, the view updates to display the image. In the example above, the icon is smaller than the frame, and so appears smaller than the placeholder.

<br>
<img src="https://docs-assets.developer.apple.com/published/7a8d82fa0ae80e1c40ba9a151d56c704/10200/AsyncImage-1@2x.png" width="300px">
<br>

You can specify a custom placeholder using `init(url:scale:content:placeholder:)`. With this initializer, you can also use the content parameter to manipulate the loaded image. For example, you can add a modifier to make the loaded image resizable:

```swift
AsyncImage(url: URL(string: "https://example.com/icon.png")) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
.frame(width: 50, height: 50)
```
For this example, SwiftUI shows a ProgressView first, and then the image scaled to fit in the specified frame:\
<br>
<img src="https://docs-assets.developer.apple.com/published/d288fdb7e0fd01131459d0fa071516aa/10200/AsyncImage-2@2x.png" width="300px">
<br>

> Important
>
> You can’t apply image-specific modifiers, like resizable(capInsets:resizingMode:), directly to an AsyncImage. Instead, apply them to the Image instance that your content closure gets when defining the view’s appearance.

To gain more control over the loading process, use the `init(url:scale:transaction:content:)` initializer, which takes a content closure that receives an AsyncImagePhase to indicate the state of the loading operation. Return a view that’s appropriate for the current phase:

```swift
AsyncImage(url: URL(string: "https://example.com/icon.png")) { phase in
    if let image = phase.image {
        image // Displays the loaded image.
    } else if phase.error != nil {
        Color.red // Indicates an error.
    } else {
        Color.blue // Acts as a placeholder.
    }
}
```

## Install
### Swift Package Manager for Apple platforms
Select Xcode menu `File > Swift Packages > Add Package Dependency` and enter repository URL with GUI.
```
Repository: https://github.com/zzzzeu/AsyncImage
```
### Swift Package Manager
Add the following to the dependencies of your `Package.swift`:
```swift
.package(url: "https://github.com/zzzzeu/AsyncImage.git", from: "0.0.1")
```