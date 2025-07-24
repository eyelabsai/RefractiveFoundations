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
    
    let service = PostService()
    
    init(post: FetchedPost)    {
        self.post = post
        checkLiked()
        fetchComments(post)
    }
    
    func checkLiked()   {
        self.liked = self.post.upvotes.contains(uid!)
        self.disliked = self.post.downvotes?.contains(uid!) ?? false
    }
        
    func upvote() {
        guard let uid = Auth.auth().currentUser?.uid, let postId = post.id else { return }

        service.upvote(post) { liked in
            DispatchQueue.main.async {
                self.liked = liked
                self.disliked = false // Remove dislike when upvoting
                if liked {
                    self.post.upvotes.append(uid)
                    if self.post.downvotes == nil {
                        self.post.downvotes = []
                    }
                    self.post.downvotes?.removeAll(where: { $0 == uid })
                } else {
                    self.post.upvotes.removeAll(where: { $0 == uid })
                }
                self.updateFeedViewModel()
            }
        }
    }
    
    func downvote() {
        guard let uid = Auth.auth().currentUser?.uid, let postId = post.id else { return }

        service.downvote(post) { disliked in
            DispatchQueue.main.async {
                self.disliked = disliked
                self.liked = false // Remove like when downvoting
                if disliked {
                    if self.post.downvotes == nil {
                        self.post.downvotes = []
                    }
                    self.post.downvotes?.append(uid)
                    self.post.upvotes.removeAll(where: { $0 == uid })
                } else {
                    self.post.downvotes?.removeAll(where: { $0 == uid })
                }
                self.updateFeedViewModel()
            }
        }
    }

    
    
    func fetchComments(_ post: FetchedPost)    {
        Firestore.firestore().collection("comments").addSnapshotListener { (querySnapshot, error) in
            guard let docs = querySnapshot?.documents else { return }
            _ = docs.map { (QueryDocumentSnapshot) -> Comment in
                let data = QueryDocumentSnapshot.data()
                let postId = data["postId"] as? String ?? ""
                let author = data["author"] as? String ?? ""
                let text = data["text"] as? String ?? ""
                let timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
                let comment = Comment(postId: postId, text: text, author: author, timestamp: timestamp)
                if postId == self.post.id   {
                    self.comments.append(comment)
                }
                return comment
            }
            
        }
    }
    
    private func updateFeedViewModel() {
        FeedViewModel.shared.refreshPosts()
    }

    
}
