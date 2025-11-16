import SwiftUI
import PhotosUI
import WebKit
import Combine


enum ProcessingMode: String, CaseIterable {
    case color = "color"
    case binary = "binary"
}

// Main Content View
struct ContentView: View {
    @StateObject private var viewModel = ImageProcessingViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Display Section
                    imageDisplaySection
                    
                    // Photo Picker Button
                    photoPickerButton
                    
                    // Mode Selection
                    if viewModel.selectedUIImage != nil && viewModel.svgContent == nil {
                        modeSelectionSection
                        processButton
                    }
                    
                    // SVG Result Display
                    if let svgContent = viewModel.svgContent {
                        svgDisplaySection(svgContent: svgContent)
                        HStack(spacing: 15) {
                            saveResult
                            resetAll
                        }
                    }
                    
                    // Error Message
                    if let errMessage = viewModel.errMessage {
                        Text(errMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("VecPic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // View Components
    
    private var imageDisplaySection: some View {
        Group {
            if let selectedUIImage = viewModel.selectedUIImage, viewModel.svgContent == nil {
                Image(uiImage: selectedUIImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5)
            } else if viewModel.svgContent == nil {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 300)
                    .overlay(
                        Text("No Image Selected")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $viewModel.selectedPhoto,
            matching: .images,
            label: {
                Text( "Select Image")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        )
    }
    
    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Mode")
                .font(.headline)
            
            Picker("Mode", selection: $viewModel.selectedMode) {
                ForEach(ProcessingMode.allCases, id: \.self) { mode in
                    Text("\(mode.rawValue)").tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var processButton: some View {
        Button(action: {
            Task {
                await viewModel.sendToBackend()
            }
        }) {
            Text(viewModel.isProcessing ? "Processing" : "Submit")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isProcessing ? Color.gray : Color.green)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(viewModel.isProcessing)
    }
    
    private func svgDisplaySection(svgContent: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result")
                .font(.headline)
            
            SVGWebView(svgContent: svgContent)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)
        }
    }

    
    private var saveResult: some View {
        Button(action: {
            viewModel.saveSVG()
        }) {
            Label("Save", systemImage: "square.and.arrow.down.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private var resetAll: some View {
        Group {
            Button(action: {
                viewModel.retry()
            }) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// View Model
@MainActor
class ImageProcessingViewModel: ObservableObject {
    @Published var selectedPhoto: PhotosPickerItem? = nil
    @Published var selectedUIImage: UIImage? = nil
    @Published var selectedMode: ProcessingMode = .color
    @Published var isProcessing = false
    @Published var svgContent: String? = nil
    @Published var errMessage: String? = nil
    @Published var originalFilename: String = ""
    
    init() {
        // Observe photo selection changes
        $selectedPhoto
            .sink { [weak self] newItem in
                Task { @MainActor in
                    await self?.loadImage(from: newItem)
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        selectedUIImage = nil
        svgContent = nil
        errMessage = nil
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                selectedUIImage = uiImage
                // Try to get original filename
                if let identifier = item.itemIdentifier {
                    originalFilename = identifier
                } else {
                    originalFilename = "image.jpg"
                }
            }
        } catch {
            errMessage = "Failed to load image"
        }
    }
    
    func sendToBackend() async {
        guard let uiImage = selectedUIImage else {
            errMessage = "No image to process"
            return
        }
        
        isProcessing = true
        errMessage = nil
        
        // Convert UIImage to JPEG
        guard let imageData = uiImage.jpegData(compressionQuality: 1) else {
            errMessage = "Failed to encode image"
            isProcessing = false
            return
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "http://127.0.0.1:5000/vecpic")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(originalFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add preset (color mode)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"colormode\"\r\n\r\n".data(using: .utf8)!)
        body.append(selectedMode.rawValue.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add filename
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filename\"\r\n\r\n".data(using: .utf8)!)
        body.append(originalFilename.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errMessage = "Invalid server response"
                isProcessing = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let svgString = String(data: data, encoding: .utf8) {
                    svgContent = svgString
                    errMessage = nil
                } else {
                    errMessage = "Failed to parse SVG response"
                }
            } else {
                errMessage = "Server error"
            }
        } catch {
            errMessage = "Network error"
        }
        
        isProcessing = false
    }
    
    func saveSVG() {
        guard let svgContent = svgContent else { return }
        
        // Save to Files app
        let tempURL = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("converted_\(Date().timeIntervalSince1970).svg")
        
        do {
            try svgContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Present share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            
            errMessage = "SVG ready to save"
        } catch {
            errMessage = "Failed to save"
        }
    }
    
    func retry() {
        selectedUIImage = nil
        selectedPhoto = nil
        svgContent = nil
        errMessage = nil
    }
}

// SVG Web View
struct SVGWebView: UIViewRepresentable {
    let svgContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(svgContent, baseURL: nil)
    }
}

#Preview {
    ContentView()
}
