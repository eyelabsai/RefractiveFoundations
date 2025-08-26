//
//  VideoPlayerView.swift
//  RefractiveExchange
//
//  Created for video playback functionality
//

import SwiftUI
import AVFoundation
import AVKit

// MARK: - Video Player View
struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = false
    @State private var thumbnail: UIImage?
    @State private var hasStartedPlaying = false
    
    var body: some View {
        ZStack {
            // Video player or thumbnail
            if let player = player, hasStartedPlaying {
                VideoPlayer(player: player)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls.toggle()
                        }
                    }
            } else {
                // Show thumbnail before first play
                thumbnailView
                    .onTapGesture {
                        startVideoPlayback()
                    }
            }
            
            // Custom controls overlay
            if showControls && hasStartedPlaying {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showControls = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                    
                    // Play/Pause button
                    Button(action: {
                        togglePlayback()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                    }
                    
                    Spacer()
                }
                .transition(.opacity)
            }
            
            // Play button overlay for thumbnail
            if !hasStartedPlaying {
                Button(action: {
                    startVideoPlayback()
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }
            }
        }
        .onAppear {
            setupPlayer()
            generateThumbnail()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private var thumbnailView: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
        
        // Add observer for when video finishes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            self.isPlaying = false
            self.player?.seek(to: .zero)
        }
    }
    
    private func startVideoPlayback() {
        hasStartedPlaying = true
        player?.play()
        isPlaying = true
        
        // Auto-hide controls after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
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
    
    private func cleanupPlayer() {
        player?.pause()
        NotificationCenter.default.removeObserver(self)
        player = nil
    }
}

// MARK: - Compact Video Player for Feed
struct CompactVideoPlayerView: View {
    let videoURL: URL
    @State private var thumbnail: UIImage?
    @State private var showFullscreenPlayer = false
    
    var body: some View {
        Button(action: {
            showFullscreenPlayer = true
        }) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                
                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .shadow(radius: 5)
            }
        }
        .sheet(isPresented: $showFullscreenPlayer) {
            NavigationView {
                VideoPlayerView(videoURL: videoURL)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showFullscreenPlayer = false
                    })
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

// MARK: - Video Carousel for Multiple Videos
struct VideoCarouselView: View {
    let videoURLs: [URL]
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 12) {
            if !videoURLs.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(videoURLs.enumerated()), id: \.offset) { index, videoURL in
                        CompactVideoPlayerView(videoURL: videoURL)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 200)
                
                if videoURLs.count > 1 {
                    Text("\(currentIndex + 1) of \(videoURLs.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
