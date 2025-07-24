//
//  CreatePostViewHandler.swift
//  IOL CON
//
//  Created by Haoran Song on 10/29/23.
//

// CreatePostViewHandler.swift

import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class CreatePostViewHandler {
    
    static func createPost(data: GetData, title: String, text: String, subredditList: [String],selectedSubredditIndex: Int, postImageData: Data?, completion: @escaping (Bool) -> Void) {
        
        // Get current user UID safely
        guard let currentUID = Auth.auth().currentUser?.uid else {
            print("❌ Error: User not authenticated")
            completion(false)
            return
        }
        
        // Create unique image reference ID
        let imageReferenceID = "post_\(currentUID)_\(Date().timeIntervalSince1970)".replacingOccurrences(of: ".", with: "_")
        let storageRef = Storage.storage().reference().child("Post_Images").child(imageReferenceID)
        if let postImageData = postImageData {
            
            storageRef.putData(postImageData, metadata: StorageMetadata()) { (metadata, error) in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                storageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error fetching download URL: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    if let url = url {
                        let post = StoredPost(title: title, text: text, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], subreddit: subredditList[selectedSubredditIndex], imageURL: url.absoluteString, didLike: false, didDislike: false, uid: currentUID)
                        uploadFirebase(post: post, completion: completion)
                    } else {
                        completion(false)
                    }
                }
            }
        } else {
            let post = StoredPost(title: title, text: text, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], subreddit: subredditList[selectedSubredditIndex], imageURL: nil, didLike: false, didDislike: false, uid: currentUID)
            uploadFirebase(post: post, completion: completion)
        }
    }
    
    static func uploadFirebase(post: StoredPost, completion: @escaping (Bool) -> Void) {
        do {
            let docRef = try Firestore.firestore().collection("posts").addDocument(from: post)
            print("✅ Post successfully uploaded to Firebase with ID: \(docRef.documentID)")
            print("📝 Post details: Title: '\(post.title)', Subreddit: '\(post.subreddit)', UID: '\(post.uid)'")
            completion(true)
        } catch let error {
            print("❌ Error uploading post to Firebase: \(error.localizedDescription)")
            completion(false)
        }
    }
}


