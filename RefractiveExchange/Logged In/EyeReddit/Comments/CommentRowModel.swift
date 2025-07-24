//
//  CommentRowModel.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/7/23.
//

import Foundation
import FirebaseAuth

class CommentRowModel: ObservableObject {
    
    @Published var comment: Comment
    @Published var liked: Bool = false
    @Published var disliked: Bool = false
    
    let commentService = CommentService()
    
    init(comment: Comment)  {
        self.comment = comment
        checkLiked()
    }
    
    func checkLiked() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        self.liked = self.comment.safeUpvotes.contains(uid)
        self.disliked = self.comment.safeDownvotes.contains(uid)
    }
    
    func upvote() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        commentService.upvoteComment(comment) { liked in
            DispatchQueue.main.async {
                self.liked = liked
                self.disliked = false
                if liked {
                    if self.comment.upvotes == nil { self.comment.upvotes = [] }
                    if self.comment.downvotes == nil { self.comment.downvotes = [] }
                    self.comment.upvotes?.append(uid)
                    self.comment.downvotes?.removeAll(where: { $0 == uid })
                } else {
                    self.comment.upvotes?.removeAll(where: { $0 == uid })
                }
            }
        }
    }
    
    func downvote() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        commentService.downvoteComment(comment) { disliked in
            DispatchQueue.main.async {
                self.disliked = disliked
                self.liked = false
                if disliked {
                    if self.comment.upvotes == nil { self.comment.upvotes = [] }
                    if self.comment.downvotes == nil { self.comment.downvotes = [] }
                    self.comment.downvotes?.append(uid)
                    self.comment.upvotes?.removeAll(where: { $0 == uid })
                } else {
                    self.comment.downvotes?.removeAll(where: { $0 == uid })
                }
            }
        }
    }
}
