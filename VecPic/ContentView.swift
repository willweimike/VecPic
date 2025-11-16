import SwiftUI
import PhotosUI


enum Presets: String, CaseIterable {
    case color = "color"
    case binary = "binary"
}

struct ContentView: View {
    @State var selectPhoto: PhotosPickerItem?
    @State var selectedUIImage: UIImage?
    @State var selectedMode: Presets = .color
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
                HStack(spacing: 20) {
                    saveButton
                    resetAllButton
                }

            }
            else if let selectedUIImage {
                Image(uiImage: selectedUIImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                modeSelectionSection
                HStack(spacing: 20) {
                    confirmButton
                    resetAllButton
                }
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
                    ForEach(Presets.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }.pickerStyle(.wheel)
        }
    }
    private var processButton: some View {
        Group {
            Button(action: confirmAndProcess) {
                Text(isProcessing ? "Processing" : "Submit")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isProcessing || selectedUIImage == nil)
        }
        .padding()
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
            .disabled(isProcessing || selectedUIImage == nil)
        }
    }
    
    private var saveButton: some View {
        Group {
            Button(action: saveResult) {
                Label("Save", systemImage: "square.and.arrow.down")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding()
        }
    }
    
    private var resetAllButton: some View {
        Group {
            Button(action: resetAll) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding()
        }
    }
    
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        selectedUIImage = nil
        resultImage = nil
        errMessage = nil
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                    selectedUIImage = uiImage
            }
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
        
        var request = URLRequest(url: URL(string: "http://localhost:9000/vecpic/")!)
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
    
    private func saveResult() {
        guard let resultImage else {return}
        UIImageWriteToSavedPhotosAlbum(resultImage, nil, nil, nil)
    }
    
    private func resetAll() {
        selectedUIImage = nil
        selectPhoto = nil
        resultImage = nil
        errMessage = nil
    }
}

