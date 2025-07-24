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
    let imageURL: String?
    var didLike: Bool = false
    var didDislike: Bool = false
    var uid: String
}

struct FetchedPost: Codable, Identifiable, Hashable  {
    @DocumentID var id: String?
    let title: String
    let text: String
    let timestamp: Timestamp
    var upvotes: [String]
    var downvotes: [String]?
    let subreddit: String
    let imageURL: String?
    var didLike: Bool = false
    var didDislike: Bool = false
    var author: String
    var uid: String
    var avatarUrl: String?
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FetchedPost, rhs: FetchedPost) -> Bool {
        return lhs.id == rhs.id
    }
}
