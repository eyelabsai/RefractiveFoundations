//
//  CommentService.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/8/23.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth




struct CommentService   {
    
    func upvoteComment(_ comment: Comment, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, let commentId = comment.id else { return }
        
        if comment.safeUpvotes.contains(uid) {
            // Remove upvote
            Firestore.firestore().collection("comments").document(commentId)
                .updateData(["upvotes": FieldValue.arrayRemove([uid])]) { error in
                    completion(false)
                }
        } else {
            // Add upvote and remove downvote if exists
            Firestore.firestore().collection("comments").document(commentId)
                .updateData([
                    "upvotes": FieldValue.arrayUnion([uid]),
                    "downvotes": FieldValue.arrayRemove([uid])
                ]) { error in
                    if error == nil {
                        // Create notification for comment like
                        NotificationService.shared.createCommentLikeNotification(
                            commentId: commentId,
                            commentAuthorId: comment.uid ?? "",
                            likerId: uid,
                            postTitle: "Comment" // We'll get the actual post title in the service
                        )
                        print("✅ Comment upvoted and notification sent")
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
        }
    }
    
    func downvoteComment(_ comment: Comment, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, let commentId = comment.id else { return }
        
        if comment.safeDownvotes.contains(uid) {
            // Remove downvote
            Firestore.firestore().collection("comments").document(commentId)
                .updateData(["downvotes": FieldValue.arrayRemove([uid])]) { error in
                    completion(false)
                }
        } else {
            // Add downvote and remove upvote if exists
            Firestore.firestore().collection("comments").document(commentId)
                .updateData([
                    "downvotes": FieldValue.arrayUnion([uid]),
                    "upvotes": FieldValue.arrayRemove([uid])
                ]) { error in
                    completion(true)
                }
        }
    }
    
    func deleteComment(_ comment: Comment, completion: @escaping (Bool) -> Void) {
        guard let commentId = comment.id else {
            completion(false)
            return
        }
        
        // Check if user has permission to delete this comment
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Allow deletion if user is the author (admin permissions will be added later)
        let isAuthor = comment.uid == currentUserId
        
        guard isAuthor else {
            print("❌ User does not have permission to delete this comment")
            completion(false)
            return
        }
        Firestore.firestore().collection("comments").document(commentId).delete { error in
            if let error = error {
                print("❌ Error deleting comment: \(error.localizedDescription)")
                completion(false)
            } else {
                print("🗑️ Comment deleted from Firestore")
                completion(true)
            }
        }
    }
    
    func editComment(_ comment: Comment, newText: String, completion: @escaping (Bool) -> Void) {
        guard let commentId = comment.id else {
            completion(false)
            return
        }
        
        Firestore.firestore().collection("comments").document(commentId).updateData([
            "text": newText,
            "editedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Error editing comment: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✏️ Comment edited successfully")
                completion(true)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPostTitleForComment(commentId: String, completion: @escaping (String?) -> Void) {
        Firestore.firestore().collection("comments").document(commentId).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching comment: \(error)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists,
                  let postId = document.data()?["postId"] as? String else {
                completion(nil)
                return
            }
            
            Firestore.firestore().collection("posts").document(postId).getDocument { postDoc, error in
                if let error = error {
                    print("❌ Error fetching post: \(error)")
                    completion(nil)
                    return
                }
                
                guard let postDoc = postDoc, postDoc.exists,
                      let title = postDoc.data()?["title"] as? String else {
                    completion(nil)
                    return
                }
                
                completion(title)
            }
        }
    }
}
