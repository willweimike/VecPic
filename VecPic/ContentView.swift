import SwiftUI
import PhotosUI

//enum ColorMode: String, CaseIterable {
//    case bw = "bw"
//    case color = "color"
//}
//
//enum FittingMode: String, CaseIterable {
//    case pixel = "pixel"
//    case polygon = "polygon"
//    case spline = "spline"
//}

enum Presets: String, CaseIterable {
    case bw = "bw"
    case poster = "poster"
    case photo = "photo"
}



struct ContentView: View {
    @State var selectedImage: Image?
    @State var selectPhoto: PhotosPickerItem?
    @State var selectedUIImage: UIImage?
    @State var showAlert = false
    @State var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            if let selectedImage {
                selectedImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            }
            else {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 300)
                    .overlay(Text("No Image Selected"))
            }
            
            PhotosPicker(selection: $selectPhoto, matching: .images) {
                Text("Select Photo")
                    .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding(.top)
        .onChange(of: selectPhoto) { newItem in
            Task {
                await loadImage(from: newItem)
            }
        }
        .alert("Result", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        // for display
        if let image = try? await item.loadTransferable(type: Image.self) {
            selectedImage = image
        }
        // for processing
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
                selectedUIImage = uiImage
        }
    }
}

// Speckle filter options enum

