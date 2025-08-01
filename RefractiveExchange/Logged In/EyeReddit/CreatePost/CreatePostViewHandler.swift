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
        
        if let postImageData = postImageData {
            print("🔄 Starting image upload...")
            
            // Validate image data
            guard postImageData.count > 0 else {
                print("❌ Error: Image data is empty")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            print("📊 Image data size: \(postImageData.count) bytes")
            
            // Create unique image reference ID with proper format
            let imageReferenceID = "post_\(currentUID)_\(Int(Date().timeIntervalSince1970)).jpg"
            let storageRef = Storage.storage().reference()
            let imageRef = storageRef.child("Post_Images/\(imageReferenceID)")
            
            print("📁 Upload path: Post_Images/\(imageReferenceID)")
            
            // Simple metadata setup
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            imageRef.putData(postImageData, metadata: metadata) { (metadata, error) in
                if let error = error {
                    print("❌ Error uploading image: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                guard metadata != nil else {
                    print("❌ Upload failed: No metadata received")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                print("✅ Image uploaded successfully")
                
                // Get download URL
                imageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("❌ Error fetching download URL: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(false)
                        }
                        return
                    }
                    
                    guard let url = url else {
                        print("❌ Failed to get download URL")
                        DispatchQueue.main.async {
                            completion(false)
                        }
                        return
                    }
                    
                    print("✅ Image URL obtained: \(url.absoluteString)")
                    let post = StoredPost(title: title, text: text, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], subreddit: subredditList[selectedSubredditIndex], imageURL: url.absoluteString, didLike: false, didDislike: false, uid: currentUID)
                    uploadFirebase(post: post, completion: completion)
                }
            }
        } else {
            // No image, create post directly
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
    
    // MARK: - Debug Helper
    static func testFirebaseStorageConnection(completion: @escaping (Bool, String) -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion(false, "❌ User not authenticated")
            return
        }
        
        print("🧪 Testing Firebase Storage connection...")
        
        // Create a small test file
        let testData = "test".data(using: .utf8)!
        let testRef = Storage.storage().reference().child("test_uploads/test_\(currentUID).txt")
        
        testRef.putData(testData, metadata: nil) { (metadata, error) in
            if let error = error {
                let message = "❌ Storage upload test failed: \(error.localizedDescription)"
                print(message)
                completion(false, message)
                return
            }
            
            print("✅ Test upload successful")
            
            // Test download URL
            testRef.downloadURL { (url, error) in
                if let error = error {
                    let message = "❌ Download URL test failed: \(error.localizedDescription)"
                    print(message)
                    completion(false, message)
                    return
                }
                
                if let url = url {
                    let message = "✅ Firebase Storage is working correctly! Test URL: \(url.absoluteString)"
                    print(message)
                    
                    // Clean up test file
                    testRef.delete { error in
                        if let error = error {
                            print("⚠️ Could not delete test file: \(error.localizedDescription)")
                        } else {
                            print("🧹 Test file cleaned up")
                        }
                    }
                    
                    completion(true, message)
                } else {
                    let message = "❌ Could not get download URL"
                    print(message)
                    completion(false, message)
                }
            }
        }
    }
}


