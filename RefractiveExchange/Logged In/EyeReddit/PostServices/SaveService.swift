//
//  SaveService.swift
//  RefractiveExchange
//
//  Service for handling post saving functionality like Reddit
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class SaveService: ObservableObject {
    
    static let shared = SaveService()
    
    // Save or unsave a post
    func toggleSavePost(_ postId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let userRef = Firestore.firestore().collection("users").document(uid)
        
        // First check if post is already saved
        userRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                var savedPosts = data?["savedPosts"] as? [String] ?? []
                
                if savedPosts.contains(postId) {
                    // Remove from saved posts
                    savedPosts.removeAll { $0 == postId }
                    userRef.updateData(["savedPosts": savedPosts]) { error in
                        completion(error == nil ? false : false) // false means unsaved
                    }
                } else {
                    // Add to saved posts
                    savedPosts.append(postId)
                    userRef.updateData(["savedPosts": savedPosts]) { error in
                        completion(error == nil ? true : false) // true means saved
                    }
                }
            } else {
                // Create new savedPosts array
                userRef.updateData(["savedPosts": [postId]]) { error in
                    completion(error == nil ? true : false)
                }
            }
        }
    }
    
    // Save a specific post
    func savePost(postId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let userRef = Firestore.firestore().collection("users").document(uid)
        
        userRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                var savedPosts = data?["savedPosts"] as? [String] ?? []
                
                if !savedPosts.contains(postId) {
                    savedPosts.append(postId)
                    userRef.updateData(["savedPosts": savedPosts]) { error in
                        completion(error == nil)
                    }
                } else {
                    completion(true) // Already saved
                }
            } else {
                // Create new savedPosts array
                userRef.updateData(["savedPosts": [postId]]) { error in
                    completion(error == nil)
                }
            }
        }
    }
    
    // Unsave a specific post
    func unsavePost(postId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let userRef = Firestore.firestore().collection("users").document(uid)
        
        userRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                var savedPosts = data?["savedPosts"] as? [String] ?? []
                
                savedPosts.removeAll { $0 == postId }
                userRef.updateData(["savedPosts": savedPosts]) { error in
                    completion(error == nil)
                }
            } else {
                completion(true) // Nothing to unsave
            }
        }
    }
    
    // Check if a post is saved
    func isPostSaved(_ postId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let userRef = Firestore.firestore().collection("users").document(uid)
        
        userRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                let savedPosts = data?["savedPosts"] as? [String] ?? []
                completion(savedPosts.contains(postId))
            } else {
                completion(false)
            }
        }
    }
    
    // Get all saved posts for current user
    func getSavedPosts(completion: @escaping ([FetchedPost]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for saved posts")
            completion([])
            return
        }
        
        print("🔍 Loading saved posts for user: \(uid)")
        let userRef = Firestore.firestore().collection("users").document(uid)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ Error fetching user document for saved posts: \(error.localizedDescription)")
                completion([])
                return
            }
            
            if let document = document, document.exists {
                let data = document.data()
                let savedPostIds = data?["savedPosts"] as? [String] ?? []
                
                print("📋 Found \(savedPostIds.count) saved post IDs")
                
                if savedPostIds.isEmpty {
                    completion([])
                    return
                }
                
                // Fetch the actual posts
                let postsRef = Firestore.firestore().collection("posts")
                let group = DispatchGroup()
                var fetchedPosts: [FetchedPost] = []
                
                for postId in savedPostIds {
                    group.enter()
                    postsRef.document(postId).getDocument { postDoc, error in
                        
                        if let error = error {
                            print("❌ Error fetching saved post \(postId): \(error.localizedDescription)")
                            group.leave()
                            return
                        }
                        
                        if let postDoc = postDoc, postDoc.exists,
                           let storedPost = try? postDoc.data(as: StoredPost.self) {
                            
                            // Fetch user details for author
                            let userRef = Firestore.firestore().collection("users").document(storedPost.uid)
                            userRef.getDocument { userDoc, error in
                                defer { group.leave() } // Move group.leave to the inner completion
                                
                                let authorName: String
                                let avatarUrl: String?
                                
                                if let userDoc = userDoc, userDoc.exists {
                                    do {
                                        let user = try userDoc.data(as: User.self)
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
                                    } catch {
                                        print("❌ Error decoding user data: \(error)")
                                        authorName = "Unknown User"
                                        avatarUrl = nil
                                    }
                                } else {
                                    print("⚠️ User document not found for UID: \(storedPost.uid)")
                                    authorName = "Unknown User"
                                    avatarUrl = nil
                                }
                                
                                let fetchedPost = FetchedPost(
                                    id: storedPost.id,
                                    title: storedPost.title,
                                    text: storedPost.text,
                                    timestamp: storedPost.timestamp,
                                    upvotes: storedPost.upvotes,
                                    downvotes: storedPost.downvotes,
                                    subreddit: storedPost.subreddit,
                                    imageURLs: storedPost.imageURLs,
                                    didLike: storedPost.didLike,
                                    didDislike: storedPost.didDislike,
                                    author: authorName,
                                    uid: storedPost.uid,
                                    avatarUrl: avatarUrl,
                                    editedAt: storedPost.editedAt
                                )
                                fetchedPosts.append(fetchedPost)
                            }
                        } else {
                            print("⚠️ Saved post \(postId) not found or invalid")
                            group.leave()
                        }
                    }
                }
                
                // Add timeout for saved posts loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    print("⚠️ Saved posts loading timeout")
                }
                
                group.notify(queue: .main) {
                    print("✅ Completed loading saved posts: \(fetchedPosts.count)")
                    completion(fetchedPosts.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() })
                }
            } else {
                print("⚠️ User document doesn't exist for saved posts")
                completion([])
            }
        }
    }
} 