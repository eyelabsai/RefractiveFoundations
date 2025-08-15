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
    var didLike: Bool = false
    var didDislike: Bool = false
    var uid: String
    var editedAt: Timestamp? // Added edited timestamp
    var isPinned: Bool? // Added pinned status for admin announcements
    var pinnedAt: Timestamp? // When the post was pinned
    var pinnedBy: String? // Admin who pinned the post
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
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FetchedPost, rhs: FetchedPost) -> Bool {
        return lhs.id == rhs.id
    }
}
