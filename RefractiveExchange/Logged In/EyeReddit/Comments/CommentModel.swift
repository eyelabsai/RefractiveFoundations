//
//  CommentModel.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/7/23.
//

import Foundation
import Firebase
import FirebaseFirestore

class CommentModel: ObservableObject {
    var post: FetchedPost
    @Published var comments: [Comment] = []
    @Published var allComments: [Comment] = []
    
    
    init(post: FetchedPost)    {
        self.post = post
        self.comments = []
        fetchComments()
    }
    
    
    func fetchComments() {
        // First try with ordering (this might fail if index doesn't exist)
        print("🔍 Fetching comments for post: \(post.id)")
        Firestore.firestore().collection("comments")
            .whereField("postId", isEqualTo: post.id)
            .order(by: "timestamp", descending: true) 
            .addSnapshotListener { (querySnapshot, error) in
                if let error = error {
                    print("⚠️ Comments query with ordering failed, trying fallback: \(error.localizedDescription)")
                    // Check if it's an index error
                    if error.localizedDescription.contains("index") || error.localizedDescription.contains("requires an index") {
                        print("📋 Missing Firebase index detected, using fallback query")
                        self.fetchCommentsWithoutOrdering()
                        return
                    }
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No comments found for post")
                    return
                }

                DispatchQueue.main.async {
                    self.comments = documents.compactMap { document in
                        try? document.data(as: Comment.self)
                    }
                    print("✅ Loaded \(self.comments.count) comments with ordering")
                }
            }
    }
    
    private func fetchCommentsWithoutOrdering() {
        print("🔄 Loading comments without ordering (fallback)")
        Firestore.firestore().collection("comments")
            .whereField("postId", isEqualTo: post.id)
            .addSnapshotListener { (querySnapshot, error) in
                guard let documents = querySnapshot?.documents else {
                    print("No comments found for post")
                    return
                }

                DispatchQueue.main.async {
                    // Sort comments by timestamp on the client side
                    let comments = documents.compactMap { document in
                        try? document.data(as: Comment.self)
                    }
                    self.comments = comments.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                    print("✅ Loaded \(self.comments.count) comments with client-side sorting")
                }
            }
    }
}
