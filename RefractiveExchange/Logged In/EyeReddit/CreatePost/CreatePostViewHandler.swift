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
    
    static func createPost(data: GetData, title: String, text: String, subredditList: [String],selectedSubredditIndex: Int, postImageData: [Data], completion: @escaping (Bool) -> Void) {
        
        // Get current user UID safely
        guard let currentUID = Auth.auth().currentUser?.uid else {
            print("❌ Error: User not authenticated")
            completion(false)
            return
        }
        
        if !postImageData.isEmpty {
            print("🔄 Starting multiple image uploads...")
            print("📊 Number of images to upload: \(postImageData.count)")
            
            uploadMultipleImages(imageDataArray: postImageData, currentUID: currentUID) { imageURLs in
                if let imageURLs = imageURLs, !imageURLs.isEmpty {
                    print("✅ All images uploaded successfully")
                    let post = StoredPost(title: title, text: text, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], subreddit: subredditList[selectedSubredditIndex], imageURLs: imageURLs, didLike: false, didDislike: false, uid: currentUID)
                    uploadFirebase(post: post, completion: completion)
                } else {
                    print("❌ Failed to upload images")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        } else {
            // No images to upload
            let post = StoredPost(title: title, text: text, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], subreddit: subredditList[selectedSubredditIndex], imageURLs: nil, didLike: false, didDislike: false, uid: currentUID)
            uploadFirebase(post: post, completion: completion)
        }
    }
    
    // Helper function to upload multiple images
    private static func uploadMultipleImages(imageDataArray: [Data], currentUID: String, completion: @escaping ([String]?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var uploadedURLs: [String] = []
        var hasError = false
        
        for (index, imageData) in imageDataArray.enumerated() {
            dispatchGroup.enter()
            
            // Validate image data
            guard imageData.count > 0 else {
                print("❌ Error: Image data is empty for image \(index)")
                hasError = true
                dispatchGroup.leave()
                continue
            }
            
            print("📊 Image \(index) data size: \(imageData.count) bytes")
            
            // Create unique image reference ID with proper format
            let imageReferenceID = "post_\(currentUID)_\(Int(Date().timeIntervalSince1970))_\(index).jpg"
            let storageRef = Storage.storage().reference()
            let imageRef = storageRef.child("Post_Images/\(imageReferenceID)")
            
            print("📁 Upload path: Post_Images/\(imageReferenceID)")
            
            // Simple metadata setup
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            imageRef.putData(imageData, metadata: metadata) { (metadata, error) in
                if let error = error {
                    print("❌ Error uploading image \(index): \(error.localizedDescription)")
                    hasError = true
                    dispatchGroup.leave()
                    return
                }
                
                guard metadata != nil else {
                    print("❌ Upload failed for image \(index): No metadata received")
                    hasError = true
                    dispatchGroup.leave()
                    return
                }
                
                print("✅ Image \(index) uploaded successfully")
                
                // Get download URL
                imageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("❌ Error fetching download URL for image \(index): \(error.localizedDescription)")
                        hasError = true
                    } else if let url = url {
                        print("✅ Image \(index) URL obtained: \(url.absoluteString)")
                        uploadedURLs.append(url.absoluteString)
                    } else {
                        print("❌ Failed to get download URL for image \(index)")
                        hasError = true
                    }
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if hasError || uploadedURLs.count != imageDataArray.count {
                completion(nil)
            } else {
                completion(uploadedURLs)
            }
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


