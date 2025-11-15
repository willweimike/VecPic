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
    @State var selectedMode: Presets = .photo
    @State var isProcessing = false
    
    var body: some View {
        
        imageDisplaySection
//
    }
    
    private var imageDisplaySection: some View {
        Group {
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
                if selectedImage == nil {
                    photoPickerSection
                }
                
                if selectedImage != nil {
                    modeSelectionSection
                    
                    confirmButton
                }
            }
            .onChange(of: selectPhoto) { newItem in
                Task {
                    await loadImage(from: newItem)
                }
            }

        }
    }
    
    
    private var photoPickerSection: some View {
        Group{
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
    }
    
    private var modeSelectionSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
            Picker("Select Mode", selection: $selectedMode) {
                Text("Normal Image (RGB)").tag("photo")
                Text("Large Image (RGB)").tag("poster")
                Text("Black and White").tag("bw")
                }
            }.pickerStyle(.wheel)
        }
    }
//    
    private var confirmButton: some View {
        Group {
            Button(action: {
                confirmAndProcess()
            }) {
                Text("Confirm")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(isProcessing)
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
    
    private func confirmAndProcess() {
        guard let image = selectedImage else { return }
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessing = false
            print("Process Complete")
        }
    }
    
}

// Speckle filter options enum

