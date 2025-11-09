//
//  ContentView.swift
//  VecPic
//
//  Created by 阿威 on 2025/11/9.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    
    @State private var selectedImage: Image?
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 20) {
            if let selectedImage {
                selectedImage
                    .resizable()
                    .scaledToFit()
                    .frame(height:300)
            }
            else {
                Text("No image Selected")
                    .foregroundColor(.gray)
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("Select A Photo")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .onChange(of: selectedPhoto) { newItem in
            Task {
                if let image = try? await newItem?.loadTransferable(type: Image.self) {
                    selectedImage = image
                }
            }
        }

        
    }
        
}

#Preview {
    ContentView()
}
