import SwiftUI
import PhotosUI


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
    @State var errMessage: String? = nil
    @State var resultImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if let resultImage {
                Image(uiImage: resultImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)

//                    resultOptions
            }
            else if let selectedImage {
                selectedImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                modeSelectionSection
                confirmButton
            }
            else {
                photoPickerSection
            }
            
        }
        .onChange(of: selectPhoto) { newItem in
            Task {
                await loadImage(from: newItem)
            }
        }
        
    }
    
    private var photoPickerSection: some View {
        Group{
            VStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 300)
                    .overlay(Text("No Image Selected"))
                    .padding(.bottom)
                PhotosPicker(selection: $selectPhoto, matching: .images) {
                    Text("Select Photo")
                        .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top)
                }
                .padding(.horizontal)
            }
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
                Text(isProcessing ? "Processing" : "Submit")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(isProcessing || selectedImage == nil)
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
        guard let inputImage = selectedUIImage else { return }
        isProcessing = true
        errMessage = nil
        guard let imgData = inputImage.jpegData(compressionQuality: 1.0) else {
            errMessage = "Failed to encode image"
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: URL(string: "http://localhost:9000/tracing")!)
        let boundary = UUID().uuidString
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"input.jpg\"\r\n".data(using: .utf8)!)
        body.append(selectedMode.rawValue.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                isProcessing = false
                if let error {
                    errMessage = "Network Error"
                    return
                }
                guard let data = data, let processedImage = UIImage(data: data) else {
                    errMessage = "Invalid server response"
                    return
                }
                resultImage = processedImage
            }
        }.resume()
        
    }
//    private func resultOptions() {
//        
//    }
    
    private func saveResult() {
        guard let resultImage else {return}
        UIImageWriteToSavedPhotosAlbum(resultImage, nil, nil, nil)
    }
    
    private func resetParams() {
        selectedImage = nil
        selectedUIImage = nil
        resultImage = nil
        errMessage = nil
    }
}

// Speckle filter options enum

