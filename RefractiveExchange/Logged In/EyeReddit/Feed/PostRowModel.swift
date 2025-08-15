//
//  PostRowModel.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/6/23.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class PostRowModel: ObservableObject    {
    @Published var post: FetchedPost
    @Published var uid = Auth.auth().currentUser?.uid
    @Published var comments: [Comment] = []
    @Published var liked: Bool = false
    @Published var disliked: Bool = false
    
    private var commentsListener: ListenerRegistration?
    
    let service = PostService()
    
    init(post: FetchedPost)    {
        self.post = post
        checkLiked()
        fetchComments(post)
    }
    
    func checkLiked()   {
        self.liked = self.post.upvotes.contains(uid!)
        self.disliked = self.post.downvotes?.contains(uid!) ?? false
        self.post.didLike = self.liked
        self.post.didDislike = self.disliked
    }
        
    func upvote() {
        guard let uid = Auth.auth().currentUser?.uid, let postId = post.id else { return }

        service.upvote(post) { liked in
            DispatchQueue.main.async {
                self.liked = liked
                self.disliked = false // Remove dislike when upvoting
                self.post.didLike = liked
                self.post.didDislike = false
                if liked {
                    self.post.upvotes.append(uid)
                    if self.post.downvotes == nil {
                        self.post.downvotes = []
                    }
                    self.post.downvotes?.removeAll(where: { $0 == uid })
                } else {
                    self.post.upvotes.removeAll(where: { $0 == uid })
                }
                // Remove the feed refresh call to prevent posts from jumping to top
            }
        }
    }
    
    func downvote() {
        guard let uid = Auth.auth().currentUser?.uid, let postId = post.id else { return }

        service.downvote(post) { disliked in
            DispatchQueue.main.async {
                self.disliked = disliked
                self.liked = false // Remove like when downvoting
                self.post.didLike = false
                self.post.didDislike = disliked
                if disliked {
                    if self.post.downvotes == nil {
                        self.post.downvotes = []
                    }
                    self.post.downvotes?.append(uid)
                    self.post.upvotes.removeAll(where: { $0 == uid })
                } else {
                    self.post.downvotes?.removeAll(where: { $0 == uid })
                }
                // Remove the feed refresh call to prevent posts from jumping to top
            }
        }
    }

    
    
    func fetchComments(_ post: FetchedPost)    {
        // Remove existing listener if any
        commentsListener?.remove()
        
        // Only listen to comments for this specific post
        commentsListener = Firestore.firestore().collection("comments")
            .whereField("postId", isEqualTo: self.post.id)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching comments: \(error)")
                    return
                }
                
                guard let docs = querySnapshot?.documents else { return }
                
                // Clear existing comments for this post
                self.comments.removeAll()
                
                // Count comments for this specific post
                var commentCount = 0
                
                for doc in docs {
                    let data = doc.data()
                    let postId = data["postId"] as? String ?? ""
                    
                    if postId == self.post.id {
                        commentCount += 1
                        
                        let author = data["author"] as? String ?? ""
                        let text = data["text"] as? String ?? ""
                        let timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
                        let upvotes = data["upvotes"] as? [String] ?? []
                        let downvotes = data["downvotes"] as? [String] ?? []
                        let uid = data["uid"] as? String ?? ""
                        let editedAt = data["editedAt"] as? Timestamp
                        
                        let comment = Comment(postId: postId, text: text, author: author, timestamp: timestamp, upvotes: upvotes, downvotes: downvotes, uid: uid, editedAt: editedAt)
                        self.comments.append(comment)
                    }
                }
                
                // Update the post's comment count
                DispatchQueue.main.async {
                    self.post.commentCount = commentCount
                    print("📝 Updated comment count for post '\(self.post.title)': \(commentCount)")
                    
                    // Remove the problematic refresh call that was causing the infinite loop
                }
            }
    }
    
    // Method to manually update comment count (useful for real-time updates)
    func updateCommentCount() {
        let count = comments.count
        DispatchQueue.main.async {
            self.post.commentCount = count
        }
    }
    
    private func updateFeedViewModel() {
        FeedViewModel.shared.refreshPosts()
    }
    
    func updatePostText(_ newText: String) {
        // Create updated post
        var updatedPost = self.post
        updatedPost.text = newText
        updatedPost.editedAt = Timestamp(date: Date())
        
        // Update local post (this will automatically trigger UI refresh due to @Published)
        self.post = updatedPost
        
        // Update the post in FeedViewModel elegantly without full refresh
        FeedViewModel.shared.updatePost(updatedPost)
    }
    
    deinit {
        // Clean up the Firestore listener to prevent memory leaks
        commentsListener?.remove()
    }
}
