import SwiftUI
import AsyncImage

struct ContentView: View {
    var columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(1..<700) { i in
                    AsyncImage(url: url(at: i)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 150)
                }
            }
        }
    }
    
    func url(at index: Int) -> URL {
        URL(string: "https://github.com/onevcat/Flower-Data-Set/raw/master/rose/rose-\(index).jpg")!
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
