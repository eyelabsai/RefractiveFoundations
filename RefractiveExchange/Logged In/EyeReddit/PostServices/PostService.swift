//
//  PostService.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/6/23.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// Note: AdminService and NotificationService imports will be added once the modules are properly integrated

struct PostService  {
    func upvote(_ post: FetchedPost, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, let postId = post.id else { return }
        
        if post.upvotes.contains(uid) {
            // Remove upvote
            Firestore.firestore().collection("posts").document(postId)
                .updateData(["upvotes": FieldValue.arrayRemove([uid])]) { error in
                    completion(false)
                }
        } else {
            // Add upvote and remove downvote if exists
            Firestore.firestore().collection("posts").document(postId)
                .updateData([
                    "upvotes": FieldValue.arrayUnion([uid]),
                    "downvotes": FieldValue.arrayRemove([uid])
                ]) { error in
                    if error == nil {
                        // Create notification for post like
                        NotificationService.shared.createPostLikeNotification(
                            postId: postId,
                            postAuthorId: post.uid,
                            likerId: uid,
                            postTitle: post.title
                        )
                        print("✅ Post upvoted and notification sent")
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
        }
    }
    
    func downvote(_ post: FetchedPost, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, let postId = post.id else { return }
        
        if post.downvotes?.contains(uid) == true {
            // Remove downvote
            Firestore.firestore().collection("posts").document(postId)
                .updateData(["downvotes": FieldValue.arrayRemove([uid])]) { error in
                    completion(false)
                }
        } else {
            // Add downvote and remove upvote if exists
            Firestore.firestore().collection("posts").document(postId)
                .updateData([
                    "downvotes": FieldValue.arrayUnion([uid]),
                    "upvotes": FieldValue.arrayRemove([uid])
                ]) { error in
                    completion(true)
                }
        }
    }

    
    func fetchPosts(uid: String? = nil, completion: @escaping([FetchedPost]) -> Void) {
        let query: Query
        if let uid = uid, !uid.isEmpty {
            print("🔍 Fetching posts for specific user: \(uid)")
            // Use simple filter without ordering to avoid index requirement
            query = Firestore.firestore().collection("posts").whereField("uid", isEqualTo: uid)
        } else {
            print("🔍 Fetching all posts")
            query = Firestore.firestore().collection("posts").order(by: "timestamp", descending: true)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching posts: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("❌ No documents found")
                completion([])
                return
            }
            
            print("📥 Found \(documents.count) post documents")
            let posts = documents.compactMap({ try? $0.data(as: StoredPost.self) })
            print("📊 Successfully parsed \(posts.count) posts")
            
            if let specificUID = uid {
                let matchingPosts = posts.filter { $0.uid == specificUID }
                print("🎯 Posts matching UID \(specificUID): \(matchingPosts.count)")
                for post in matchingPosts {
                    print("   📝 Post: '\(post.title)' by UID: \(post.uid)")
                }
            }
            
            var fetchedPosts: [FetchedPost] = []
            let group = DispatchGroup()
            
            for storedPost in posts {
                group.enter()
                self.fetchUserDetails(uid: storedPost.uid) { user in
                    let authorName: String
                    let avatarUrl: String?
                    
                    if let user = user {
                        // User found - use their details
                        let firstName = user.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lastName = user.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Always prioritize first and last name combination
                        if !firstName.isEmpty || !lastName.isEmpty {
                            authorName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            // Only use username if both names are completely empty
                            authorName = !user.exchangeUsername.isEmpty ? user.exchangeUsername : "Unknown User"
                        }
                        
                        avatarUrl = user.avatarUrl
                        print("✅ Set author name: '\(authorName)' for post: '\(storedPost.title)'")
                        print("🔍 User data: firstName='\(firstName)', lastName='\(lastName)', exchangeUsername='\(user.exchangeUsername)'")
                    } else {
                        // User not found - use fallback but also try to create the user document
                        authorName = "Unknown User"
                        avatarUrl = nil
                        print("⚠️ Warning: User document missing for UID: \(storedPost.uid)")
                        print("   Post: \(storedPost.title)")
                        print("   Consider checking if this user exists in Firebase Auth but not in users collection")
                    }
                    
                    // Debug: Check pinned status during conversion
                    if let isPinned = storedPost.isPinned {
                        print("📌 DEBUG: Converting post '\(storedPost.title)' - isPinned: \(isPinned)")
                        if isPinned {
                            print("📌 DEBUG: Pinned post found! pinnedAt: \(storedPost.pinnedAt?.dateValue() ?? Date()), pinnedBy: \(storedPost.pinnedBy ?? "unknown")")
                        }
                    } else {
                        print("📌 DEBUG: Converting post '\(storedPost.title)' - isPinned: nil")
                    }
                    
                    let fetchedPost = FetchedPost(
                        id: storedPost.id,
                        title: storedPost.title,
                        text: storedPost.text,
                        timestamp: storedPost.timestamp,
                        upvotes: storedPost.upvotes,
                        downvotes: storedPost.downvotes ?? [],
                        subreddit: storedPost.subreddit,
                        imageURLs: storedPost.imageURLs,
                        didLike: storedPost.didLike,
                        didDislike: storedPost.didDislike ?? false,
                        author: authorName,
                        uid: storedPost.uid,
                        avatarUrl: avatarUrl,
                        flair: nil, // Add missing flair field
                        editedAt: storedPost.editedAt,
                        isPinned: storedPost.isPinned,
                        pinnedAt: storedPost.pinnedAt,
                        pinnedBy: storedPost.pinnedBy
                    )
                    fetchedPosts.append(fetchedPost)
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                fetchedPosts.sort(by: { $0.timestamp.dateValue() > $1.timestamp.dateValue() })
                completion(fetchedPosts)
            }

        }
    }
    
    func fetchPostById(_ postId: String, completion: @escaping (FetchedPost?) -> Void) {
        print("🔍 Fetching post by ID: \(postId)")
        
        Firestore.firestore().collection("posts").document(postId).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching post: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Post document not found for ID: \(postId)")
                completion(nil)
                return
            }
            
            do {
                let storedPost = try document.data(as: StoredPost.self)
                print("✅ Successfully fetched post: \(storedPost.title)")
                
                // Fetch user details for the post author
                self.fetchUserDetails(uid: storedPost.uid) { user in
                    let authorName: String
                    let avatarUrl: String?
                    
                    if let user = user {
                        let firstName = user.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lastName = user.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                        authorName = (!firstName.isEmpty || !lastName.isEmpty) ? 
                            "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines) :
                            (!user.exchangeUsername.isEmpty ? user.exchangeUsername : "Unknown User")
                        avatarUrl = user.avatarUrl
                    } else {
                        authorName = "Unknown User"
                        avatarUrl = nil
                    }
                    
                    let fetchedPost = FetchedPost(
                        id: storedPost.id,
                        title: storedPost.title,
                        text: storedPost.text,
                        timestamp: storedPost.timestamp,
                        upvotes: storedPost.upvotes,
                        downvotes: storedPost.downvotes ?? [],
                        subreddit: storedPost.subreddit,
                        imageURLs: storedPost.imageURLs,
                        didLike: storedPost.didLike,
                        didDislike: storedPost.didDislike ?? false,
                        author: authorName,
                        uid: storedPost.uid,
                        avatarUrl: avatarUrl,
                        editedAt: storedPost.editedAt,
                        isPinned: storedPost.isPinned,
                        pinnedAt: storedPost.pinnedAt,
                        pinnedBy: storedPost.pinnedBy
                    )
                    
                    DispatchQueue.main.async {
                        completion(fetchedPost)
                    }
                }
            } catch {
                print("❌ Error parsing post document: \(error)")
                completion(nil)
            }
        }
    }
    
    func fetchUserDetails(uid: String, completion: @escaping(User?) -> Void) {
        print("🔍 Fetching user details for UID: \(uid)")
        
        Firestore.firestore().collection("users").document(uid).getDocument { documentSnapshot, error in
            if let error = error {
                print("❌ Error fetching user details: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = documentSnapshot else {
                print("❌ No document snapshot for UID: \(uid)")
                completion(nil)
                return
            }
            
            guard document.exists else {
                print("⚠️ User document doesn't exist for UID: \(uid)")
                completion(nil)
                return
            }
            
            do {
                let user = try document.data(as: User.self)
                print("✅ Successfully fetched user: \(user.firstName) \(user.lastName) (UID: \(uid))")
                completion(user)
            } catch {
                print("❌ Error decoding user data for UID \(uid): \(error)")
                completion(nil)
            }
        }
    }
    
    func fetchEyeExchangeProfileDetails(uid: String, completion: @escaping(User?) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching user details: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            let user = try? document.data(as: User.self)
            completion(user)
        }
    }

    
    func checkUpvoted(_ post: FetchedPost, completion: @escaping(Bool) -> Void)    {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        Firestore.firestore().collection("posts").document(postId).getDocument { snapshot, _ in
            guard let snapshot = snapshot else { return }
            let upvoters = snapshot["upvotes"] as! [String]
            completion(upvoters.contains(uid))
        }
    }
    
    func deletePost(_ post: FetchedPost, completion: @escaping (Bool) -> Void) {
        guard let postId = post.id else {
            completion(false)
            return
        }
        
        // Check if user has permission to delete this post
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Allow deletion if user is the author (admin permissions will be added later)
        let isAuthor = post.uid == currentUserId
        
        guard isAuthor else {
            print("❌ User does not have permission to delete this post")
            completion(false)
            return
        }
        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(postId)
        
        // First, delete all comments associated with this post
        db.collection("comments").whereField("postId", isEqualTo: postId).getDocuments { commentSnapshot, commentError in
            if let commentError = commentError {
                print("❌ Error fetching comments for deletion: \(commentError.localizedDescription)")
            } else if let commentDocs = commentSnapshot?.documents {
                let commentGroup = DispatchGroup()
                
                for commentDoc in commentDocs {
                    commentGroup.enter()
                    commentDoc.reference.delete { error in
                        if let error = error {
                            print("❌ Error deleting comment \(commentDoc.documentID): \(error.localizedDescription)")
                        } else {
                            print("🗑️ Comment \(commentDoc.documentID) deleted")
                        }
                        commentGroup.leave()
                    }
                }
                
                commentGroup.notify(queue: .main) {
                    // Now delete the post
                    self.deletePostDocument(postRef: postRef, post: post, completion: completion)
                }
            } else {
                // No comments to delete, proceed with post deletion
                self.deletePostDocument(postRef: postRef, post: post, completion: completion)
            }
        }
    }
    
    private func deletePostDocument(postRef: DocumentReference, post: FetchedPost, completion: @escaping (Bool) -> Void) {
        // If post has images, delete them from Storage
        if let imageURLs = post.imageURLs, !imageURLs.isEmpty {
            let storage = Storage.storage()
            let dispatchGroup = DispatchGroup()
            
            for imageURL in imageURLs {
                dispatchGroup.enter()
                let storageRef = storage.reference(forURL: imageURL)
                storageRef.delete { error in
                    if let error = error {
                        print("❌ Error deleting image from Storage: \(error.localizedDescription)")
                    } else {
                        print("🗑️ Image deleted from Storage")
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // Continue to delete post regardless of image deletion results
                postRef.delete { error in
                    if let error = error {
                        print("❌ Error deleting post: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("🗑️ Post deleted from Firestore")
                        completion(true)
                    }
                }
            }
        } else {
            // No images, just delete post
            postRef.delete { error in
                if let error = error {
                    print("❌ Error deleting post: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("🗑️ Post deleted from Firestore")
                    completion(true)
                }
            }
        }
    }
    
    func editPost(_ post: FetchedPost, newText: String, completion: @escaping (Bool) -> Void) {
        guard let postId = post.id else {
            completion(false)
            return
        }
        
        Firestore.firestore().collection("posts").document(postId).updateData([
            "text": newText,
            "editedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Error editing post: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✏️ Post edited successfully")
                completion(true)
            }
        }
    }
    
}
