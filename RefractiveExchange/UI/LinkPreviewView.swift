//
//  LinkPreviewView.swift
//  RefractiveExchange
//
//  Created for link preview functionality
//

import SwiftUI

struct LinkPreviewView: View {
    let linkPreview: LinkPreviewData
    let onTap: (() -> Void)?
    
    init(linkPreview: LinkPreviewData, onTap: (() -> Void)? = nil) {
        self.linkPreview = linkPreview
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            VStack(spacing: 0) {
                // Image section
                if let imageUrl = linkPreview.imageUrl, !imageUrl.isEmpty {
                    linkPreviewImage(url: imageUrl)
                }
                
                // Content section
                linkPreviewContent
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Image Section
    
    private func linkPreviewImage(url: String) -> some View {
        Group {
            if let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure(_):
                        linkPreviewImagePlaceholder
                    case .empty:
                        linkPreviewImageLoading
                    @unknown default:
                        linkPreviewImagePlaceholder
                    }
                }
            } else {
                linkPreviewImagePlaceholder
            }
        }
    }
    
    private var linkPreviewImagePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 24))
                .foregroundColor(.gray)
            
            Text("Link Preview")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray5))
    }
    
    private var linkPreviewImageLoading: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
            
            Text("Loading preview...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray5))
    }
    
    // MARK: - Content Section
    
    private var linkPreviewContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            if let title = linkPreview.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Description
            if let description = linkPreview.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            // Site info and URL
            HStack(spacing: 4) {
                // Site name or domain
                if let siteName = linkPreview.siteName, !siteName.isEmpty {
                    Text(siteName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                } else {
                    Text(linkPreview.domain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                // External link icon
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Compact Link Preview (for smaller spaces)

struct CompactLinkPreviewView: View {
    let linkPreview: LinkPreviewData
    let onTap: (() -> Void)?
    
    init(linkPreview: LinkPreviewData, onTap: (() -> Void)? = nil) {
        self.linkPreview = linkPreview
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                if let imageUrl = linkPreview.imageUrl, !imageUrl.isEmpty {
                    compactThumbnail(url: imageUrl)
                } else {
                    compactPlaceholder
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    if let title = linkPreview.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Site name or domain
                    HStack(spacing: 4) {
                        if let siteName = linkPreview.siteName, !siteName.isEmpty {
                            Text(siteName)
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        } else {
                            Text(linkPreview.domain)
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                        
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func compactThumbnail(url: String) -> some View {
        Group {
            if let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(6)
                    case .failure(_):
                        compactPlaceholder
                    case .empty:
                        compactLoadingView
                    @unknown default:
                        compactPlaceholder
                    }
                }
            } else {
                compactPlaceholder
            }
        }
    }
    
    private var compactPlaceholder: some View {
        VStack(spacing: 2) {
            Image(systemName: "link")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(width: 60, height: 60)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
    
    private var compactLoadingView: some View {
        VStack(spacing: 2) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.6)
        }
        .frame(width: 60, height: 60)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

// MARK: - Link Preview Loading State

struct LinkPreviewLoadingView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Image placeholder
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
                
                Text("Loading preview...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))
            
            // Content placeholder
            VStack(alignment: .leading, spacing: 8) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                
                // Description placeholder
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 14)
                        .frame(maxWidth: 0.7 * UIScreen.main.bounds.width)
                }
                
                // URL placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(height: 12)
                    .frame(maxWidth: 100)
            }
            .padding(12)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - Previews

#Preview("Link Preview") {
    VStack(spacing: 16) {
        LinkPreviewView(
            linkPreview: LinkPreviewData(
                url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                title: "Rick Astley - Never Gonna Give You Up (Official Video)",
                description: "The official video for \"Never Gonna Give You Up\" by Rick Astley. The song was first released in 1987 and became a global hit.",
                imageUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
                siteName: "YouTube"
            )
        ) {
            print("Link tapped!")
        }
        
        CompactLinkPreviewView(
            linkPreview: LinkPreviewData(
                url: "https://developer.apple.com/documentation/swiftui",
                title: "SwiftUI Documentation",
                description: "Learn SwiftUI with Apple's official documentation.",
                imageUrl: nil,
                siteName: "Apple Developer"
            )
        ) {
            print("Compact link tapped!")
        }
        
        LinkPreviewLoadingView()
    }
    .padding()
}
