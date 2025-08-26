//
//  VideoPicker.swift
//  RefractiveExchange
//
//  Created for video upload functionality
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var inputVideoURL: URL?
    @Environment(\.presentationMode) var presentationMode
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.inputVideoURL = videoURL
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<VideoPicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.movie"] // Only allow video selection
        picker.videoQuality = .typeMedium // Balance between quality and file size
        picker.videoMaximumDuration = 300 // 5 minutes max
        
        // Enable camera if available and requested
        if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<VideoPicker>) {
    }
}

// MARK: - Multi Video Picker using PhotosPicker
struct MultiVideoPicker: View {
    @Binding var selectedVideoURLs: [URL]
    @State private var selectedVideos: [PhotosPickerItem] = []
    let maxVideoCount: Int
    
    init(selectedVideoURLs: Binding<[URL]>, maxVideoCount: Int = 3) {
        self._selectedVideoURLs = selectedVideoURLs
        self.maxVideoCount = maxVideoCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PhotosPicker(
                    selection: $selectedVideos,
                    maxSelectionCount: maxVideoCount,
                    matching: .videos
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "video.on.rectangle")
                            .font(.system(size: 18))
                        Text("Select Videos")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                if !selectedVideoURLs.isEmpty {
                    Text("\(selectedVideoURLs.count)/\(maxVideoCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Preview selected videos
            if !selectedVideoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedVideoURLs.enumerated()), id: \.offset) { index, videoURL in
                            ZStack(alignment: .topTrailing) {
                                VideoThumbnailView(videoURL: videoURL)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                // Remove button
                                Button(action: {
                                    removeVideo(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .offset(x: 8, y: -8)
                                
                                // Play icon overlay
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .onChange(of: selectedVideos) { newVideos in
            loadVideos(from: newVideos)
        }
    }
    
    private func loadVideos(from videoItems: [PhotosPickerItem]) {
        Task {
            var newVideoURLs: [URL] = []
            
            for videoItem in videoItems {
                if let data = try? await videoItem.loadTransferable(type: Data.self) {
                    // Save video data to temporary location
                    let tempURL = saveVideoToTempDirectory(data: data)
                    if let tempURL = tempURL {
                        newVideoURLs.append(tempURL)
                    }
                }
            }
            
            await MainActor.run {
                selectedVideoURLs = newVideoURLs
            }
        }
    }
    
    private func saveVideoToTempDirectory(data: Data) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "temp_video_\(UUID().uuidString).mp4"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving video to temp directory: \(error)")
            return nil
        }
    }
    
    private func removeVideo(at index: Int) {
        // Clean up temp file
        let videoURL = selectedVideoURLs[index]
        try? FileManager.default.removeItem(at: videoURL)
        
        selectedVideoURLs.remove(at: index)
        selectedVideos.remove(at: index)
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "video")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        Task {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    self.thumbnail = uiImage
                }
            } catch {
                print("Error generating video thumbnail: \(error)")
            }
        }
    }
}
