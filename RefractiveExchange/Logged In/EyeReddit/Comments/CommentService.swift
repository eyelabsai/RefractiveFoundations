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
                    completion(true)
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
}
