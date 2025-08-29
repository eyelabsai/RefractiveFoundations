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
    
    static func createPost(data: GetData, title: String, text: String, subredditList: [String],selectedSubredditIndex: Int, postImageData: [Data], postVideoURLs: [URL] = [], linkPreview: LinkPreviewData? = nil, completion: @escaping (Bool) -> Void) {
        
        // Get current user UID safely
        guard let currentUID = Auth.auth().currentUser?.uid else {
            print("❌ Error: User not authenticated")
            completion(false)
            return
        }
        
        // Handle media uploads (images and videos)
        let hasImages = !postImageData.isEmpty
        let hasVideos = !postVideoURLs.isEmpty
        
        if hasImages || hasVideos {
            uploadMediaFiles(imageDataArray: postImageData, videoURLs: postVideoURLs, currentUID: currentUID) { imageURLs, videoURLs in
                let post = StoredPost(
                    title: title,
                    text: text,
                    timestamp: Timestamp(date: Date()),
                    upvotes: [],
                    downvotes: [],
                    subreddit: subredditList[selectedSubredditIndex],
                    imageURLs: imageURLs,
                    videoURLs: videoURLs,
                    didLike: false,
                    didDislike: false,
                    uid: currentUID,
                    linkPreview: linkPreview
                )
                uploadFirebase(post: post, completion: completion)
            }
        } else {
            // No media to upload
            let post = StoredPost(
                title: title,
                text: text,
                timestamp: Timestamp(date: Date()),
                upvotes: [],
                downvotes: [],
                subreddit: subredditList[selectedSubredditIndex],
                imageURLs: nil,
                videoURLs: nil,
                didLike: false,
                didDislike: false,
                uid: currentUID,
                linkPreview: linkPreview
            )
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
    
    // MARK: - Combined Media Upload Function
    private static func uploadMediaFiles(imageDataArray: [Data], videoURLs: [URL], currentUID: String, completion: @escaping ([String]?, [String]?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var uploadedImageURLs: [String] = []
        var uploadedVideoURLs: [String] = []
        var hasError = false
        
        // Upload images
        if !imageDataArray.isEmpty {
            dispatchGroup.enter()
            uploadMultipleImages(imageDataArray: imageDataArray, currentUID: currentUID) { imageURLs in
                if let imageURLs = imageURLs {
                    uploadedImageURLs = imageURLs
                } else {
                    hasError = true
                }
                dispatchGroup.leave()
            }
        }
        
        // Upload videos
        if !videoURLs.isEmpty {
            dispatchGroup.enter()
            uploadMultipleVideos(videoURLs: videoURLs, currentUID: currentUID) { videoURLs in
                if let videoURLs = videoURLs {
                    uploadedVideoURLs = videoURLs
                } else {
                    hasError = true
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if hasError {
                completion(nil, nil)
            } else {
                completion(uploadedImageURLs.isEmpty ? nil : uploadedImageURLs,
                          uploadedVideoURLs.isEmpty ? nil : uploadedVideoURLs)
            }
        }
    }
    
    // MARK: - Video Upload Functions
    private static func uploadMultipleVideos(videoURLs: [URL], currentUID: String, completion: @escaping ([String]?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var uploadedURLs: [String] = []
        var hasError = false
        
        print("🔄 Starting multiple video uploads...")
        print("📊 Number of videos to upload: \(videoURLs.count)")
        
        for (index, videoURL) in videoURLs.enumerated() {
            dispatchGroup.enter()
            
            // Read video data
            do {
                let videoData = try Data(contentsOf: videoURL)
                
                guard videoData.count > 0 else {
                    print("❌ Error: Video data is empty for video \(index)")
                    hasError = true
                    dispatchGroup.leave()
                    continue
                }
                
                print("📊 Video \(index) data size: \(videoData.count) bytes")
                
                // Create unique video reference ID
                let videoReferenceID = "post_\(currentUID)_\(Int(Date().timeIntervalSince1970))_\(index).mp4"
                let storageRef = Storage.storage().reference()
                let videoRef = storageRef.child("Post_Videos/\(videoReferenceID)")
                
                print("📁 Upload path: Post_Videos/\(videoReferenceID)")
                
                // Setup metadata for video
                let metadata = StorageMetadata()
                metadata.contentType = "video/mp4"
                
                videoRef.putData(videoData, metadata: metadata) { (metadata, error) in
                    if let error = error {
                        print("❌ Error uploading video \(index): \(error.localizedDescription)")
                        hasError = true
                        dispatchGroup.leave()
                        return
                    }
                    
                    guard metadata != nil else {
                        print("❌ Upload failed for video \(index): No metadata received")
                        hasError = true
                        dispatchGroup.leave()
                        return
                    }
                    
                    print("✅ Video \(index) uploaded successfully")
                    
                    // Get download URL
                    videoRef.downloadURL { (url, error) in
                        if let error = error {
                            print("❌ Error fetching download URL for video \(index): \(error.localizedDescription)")
                            hasError = true
                        } else if let url = url {
                            print("✅ Video \(index) URL obtained: \(url.absoluteString)")
                            uploadedURLs.append(url.absoluteString)
                        } else {
                            print("❌ Failed to get download URL for video \(index)")
                            hasError = true
                        }
                        
                        dispatchGroup.leave()
                    }
                }
            } catch {
                print("❌ Error reading video data for video \(index): \(error.localizedDescription)")
                hasError = true
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if hasError || uploadedURLs.count != videoURLs.count {
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
            
            // Parse mentions in the post text and create notifications
            let mentionParser = MentionParser()
            let fullPostText = "\(post.title) \(post.text)"
            
            mentionParser.parseMentions(in: fullPostText) { parsedMentions in
                // Create mention notifications for each mentioned user
                for userId in parsedMentions.userIds {
                    NotificationService.shared.createMentionNotification(
                        mentionerId: post.uid,
                        mentionedUserId: userId,
                        contentId: docRef.documentID,
                        contentType: .post,
                        contentText: fullPostText,
                        postTitle: post.title
                    )
                }
                
                if !parsedMentions.userIds.isEmpty {
                    print("✅ Created mention notifications for \(parsedMentions.userIds.count) users")
                }
            }
            
            // Create new post notification for all users
            NotificationService.shared.createNewPostNotification(
                postId: docRef.documentID,
                postAuthorId: post.uid,
                postTitle: post.title,
                postSubreddit: post.subreddit
            )
            
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


