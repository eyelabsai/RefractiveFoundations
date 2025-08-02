//
//  Comment.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/7/23.
//

import Foundation
import FirebaseFirestore

struct Comment: Codable, Identifiable  {
    
    @DocumentID var id: String?
    var postId: String
    var text: String
    var author: String
    let timestamp: Timestamp
    var upvotes: [String]?
    var downvotes: [String]?
    var uid: String?
    var flair: String? // Added flair property
    
    // Computed properties for safe access
    var safeUpvotes: [String] {
        return upvotes ?? []
    }
    
    var safeDownvotes: [String] {
        return downvotes ?? []
    }
    
    var safeUid: String {
        return uid ?? ""
    }
}
