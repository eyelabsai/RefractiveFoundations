//
//  MultiImagePicker.swift
//  RefractiveExchange
//
//  Created by Assistant
//

import SwiftUI
import PhotosUI

struct MultiImagePicker: View {
    @Binding var selectedImages: [UIImage]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    let maxImageCount: Int
    
    init(selectedImages: Binding<[UIImage]>, maxImageCount: Int = 5) {
        self._selectedImages = selectedImages
        self.maxImageCount = maxImageCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: maxImageCount,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                        Text("Select Images")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count)/\(maxImageCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Preview selected images
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                // Remove button
                                Button(action: {
                                    removeImage(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .onChange(of: selectedPhotos) { newPhotos in
            loadImages(from: newPhotos)
        }
    }
    
    private func loadImages(from photoItems: [PhotosPickerItem]) {
        Task {
            var newImages: [UIImage] = []
            
            for photoItem in photoItems {
                if let data = try? await photoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newImages.append(image)
                }
            }
            
            await MainActor.run {
                selectedImages = newImages
            }
        }
    }
    
    private func removeImage(at index: Int) {
        selectedImages.remove(at: index)
        selectedPhotos.remove(at: index)
    }
} 