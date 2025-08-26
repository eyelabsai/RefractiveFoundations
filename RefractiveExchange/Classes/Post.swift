//
//  Post.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/6/23.
//

import Foundation
import FirebaseFirestore

struct StoredPost: Codable, Identifiable  {
    @DocumentID var id: String?
    let title: String
    let text: String
    let timestamp: Timestamp
    var upvotes: [String]
    var downvotes: [String]?
    let subreddit: String
    let imageURLs: [String]? // Changed from imageURL: String? to support multiple images
    let videoURLs: [String]? // Added support for multiple videos
    var didLike: Bool = false
    var didDislike: Bool = false
    var uid: String
    var editedAt: Timestamp? // Added edited timestamp
    var isPinned: Bool? // Added pinned status for admin announcements
    var pinnedAt: Timestamp? // When the post was pinned
    var pinnedBy: String? // Admin who pinned the post
    var linkPreview: LinkPreviewData? // Added link preview data
}

struct FetchedPost: Codable, Identifiable, Hashable  {
    @DocumentID var id: String?
    let title: String
    var text: String
    let timestamp: Timestamp
    var upvotes: [String]
    var downvotes: [String]?
    let subreddit: String
    let imageURLs: [String]? // Changed from imageURL: String? to support multiple images
    let videoURLs: [String]? // Added support for multiple videos
    var didLike: Bool = false
    var didDislike: Bool = false
    var author: String
    var uid: String
    var avatarUrl: String?
    var flair: String? // Added flair property
    var editedAt: Timestamp? // Added edited timestamp
    var isPinned: Bool? // Added pinned status for admin announcements
    var pinnedAt: Timestamp? // When the post was pinned
    var pinnedBy: String? // Admin who pinned the post
    var commentCount: Int = 0 // Added comment count for display in feed
    var linkPreview: LinkPreviewData? // Added link preview data
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FetchedPost, rhs: FetchedPost) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Link Preview Data
struct LinkPreviewData: Codable, Hashable {
    let url: String
    let title: String?
    let description: String?
    let imageUrl: String?
    let siteName: String?
    let domain: String
    
    init(url: String, title: String? = nil, description: String? = nil, imageUrl: String? = nil, siteName: String? = nil) {
        self.url = url
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.siteName = siteName
        
        // Extract domain from URL
        if let urlComponents = URLComponents(string: url) {
            self.domain = urlComponents.host ?? url
        } else {
            self.domain = url
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: LinkPreviewData, rhs: LinkPreviewData) -> Bool {
        return lhs.url == rhs.url
    }
}
