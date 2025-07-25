//
//  DirectMessageService.swift
//  RefractiveExchange
//
//  Created for DM functionality
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

class DirectMessageService: ObservableObject {
    static let shared = DirectMessageService()
    
    @Published var conversations: [ConversationPreview] = []
    @Published var isLoadingConversations = false
    
    private var conversationListener: ListenerRegistration?
    private var userDetailsCache: [String: User] = [:]
    
    private init() {}
    
    // MARK: - Conversation Management
    
    func startListeningToConversations(for userId: String) {
        print("🎧 Starting to listen for conversations for user: \(userId)")
        isLoadingConversations = true
        
        conversationListener?.remove()
        
        // Query without ordering to avoid index requirements - we'll sort in memory
        conversationListener = Firestore.firestore().collection("conversations")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to conversations: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.isLoadingConversations = false
                    }
                    return
                }
                
                self?.processConversationSnapshot(snapshot, currentUserId: userId)
            }
    }
    
    private func processConversationSnapshot(_ snapshot: QuerySnapshot?, currentUserId: String) {
        guard let documents = snapshot?.documents else {
            DispatchQueue.main.async {
                self.conversations = []
                self.isLoadingConversations = false
            }
            return
        }
        
        print("📄 Processing \(documents.count) conversations")
        
        let allConversations = documents.compactMap { document -> Conversation? in
            do {
                return try document.data(as: Conversation.self)
            } catch {
                print("❌ Error decoding conversation: \(error)")
                return nil
            }
        }
        
        // Filter out conversations that are deleted for the current user
        let activeConversations = allConversations.filter { conversation in
            !conversation.isDeletedFor(userId: currentUserId)
        }
        
        print("📄 Filtered to \(activeConversations.count) active conversations (excluded deleted ones)")
        
        // Fetch user details for each active conversation
        fetchUserDetailsForConversations(activeConversations, currentUserId: currentUserId)
    }
    
    private func fetchUserDetailsForConversations(_ conversations: [Conversation], currentUserId: String) {
        let group = DispatchGroup()
        var conversationPreviews: [ConversationPreview] = []
        
        for conversation in conversations {
            guard let otherUserId = conversation.getOtherParticipant(currentUserId: currentUserId) else {
                continue
            }
            
            group.enter()
            
            // Check cache first
            if let cachedUser = userDetailsCache[otherUserId] {
                let preview = ConversationPreview(conversation: conversation, otherUser: cachedUser, currentUserId: currentUserId)
                conversationPreviews.append(preview)
                group.leave()
            } else {
                // Fetch from Firestore
                fetchUserDetails(userId: otherUserId) { [weak self] user in
                    if let user = user {
                        self?.userDetailsCache[otherUserId] = user
                    }
                    let preview = ConversationPreview(conversation: conversation, otherUser: user, currentUserId: currentUserId)
                    conversationPreviews.append(preview)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // Sort by timestamp in memory (since we might not have been able to order in the query)
            self.conversations = conversationPreviews.sorted { $0.conversation.lastMessageTimestamp.dateValue() > $1.conversation.lastMessageTimestamp.dateValue() }
            self.isLoadingConversations = false
            print("✅ Loaded \(self.conversations.count) conversation previews")
        }
    }
    
    func stopListeningToConversations() {
        conversationListener?.remove()
        conversationListener = nil
    }
    
    // MARK: - Send Message
    
    func sendMessage(to recipientId: String, text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let senderId = Auth.auth().currentUser?.uid else {
            completion(.failure(DMError.notAuthenticated))
            return
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(DMError.emptyMessage))
            return
        }
        
        print("📤 Sending message from \(senderId) to \(recipientId)")
        
        // First, find or create conversation
        findOrCreateConversation(between: senderId, and: recipientId) { [weak self] result in
            switch result {
            case .success(let conversationId):
                self?.createAndSendMessage(conversationId: conversationId, senderId: senderId, recipientId: recipientId, text: text) { sendResult in
                    switch sendResult {
                    case .success:
                        completion(.success(conversationId))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func findOrCreateConversation(between user1: String, and user2: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Look for existing conversation
        Firestore.firestore().collection("conversations")
            .whereField("participants", arrayContains: user1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                            // Check if any conversation contains both users (even if deleted - we'll restore it)
            let existingConversation = snapshot?.documents.first { document in
                let data = document.data()
                guard let participants = data["participants"] as? [String] else { return false }
                return participants.contains(user2)
            }
                
                if let existing = existingConversation {
                    print("✅ Found existing conversation: \(existing.documentID)")
                    completion(.success(existing.documentID))
                } else {
                    // Create new conversation
                    self.createNewConversation(between: user1, and: user2, completion: completion)
                }
            }
    }
    
    private func createNewConversation(between user1: String, and user2: String, completion: @escaping (Result<String, Error>) -> Void) {
        let conversation = Conversation(
            participants: [user1, user2],
            lastMessage: "",
            lastMessageTimestamp: Timestamp(),
            unreadCount: [user1: 0, user2: 0],
            createdBy: user1,
            createdAt: Timestamp(),
            deletedFor: []
        )
        
        do {
            let docRef = try Firestore.firestore().collection("conversations").addDocument(from: conversation)
            print("✅ Created new conversation: \(docRef.documentID)")
            completion(.success(docRef.documentID))
        } catch {
            print("❌ Error creating conversation: \(error)")
            completion(.failure(error))
        }
    }
    
    private func createAndSendMessage(conversationId: String, senderId: String, recipientId: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let message = DirectMessage(
            conversationId: conversationId,
            senderId: senderId,
            recipientId: recipientId,
            text: text,
            timestamp: Timestamp(),
            isRead: false,
            messageType: .text
        )
        
        // Send message and update conversation in a batch
        let batch = Firestore.firestore().batch()
        
        // Add message
        let messageRef = Firestore.firestore().collection("directMessages").document()
        do {
            try batch.setData(from: message, forDocument: messageRef)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Update conversation and restore if it was deleted for sender
        let conversationRef = Firestore.firestore().collection("conversations").document(conversationId)
        
        batch.updateData([
            "lastMessage": text,
            "lastMessageTimestamp": Timestamp(),
            "unreadCount.\(recipientId)": FieldValue.increment(Int64(1)),
            "deletedFor": FieldValue.arrayRemove([senderId]) // Restore conversation for sender
        ], forDocument: conversationRef)
        
        // Commit batch
        batch.commit { error in
            if let error = error {
                print("❌ Error sending message: \(error)")
                completion(.failure(error))
            } else {
                print("✅ Message sent successfully")
                // Post notification to refresh conversation list
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .conversationUpdated, object: nil)
                }
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Message Listening
    
    func listenToMessages(conversationId: String, completion: @escaping ([DirectMessage]) -> Void) -> ListenerRegistration {
        print("🎧 Listening to messages for conversation: \(conversationId)")
        
        // Query without ordering to avoid index requirements - we'll sort in memory
        return Firestore.firestore().collection("directMessages")
            .whereField("conversationId", isEqualTo: conversationId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to messages: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let messages = snapshot?.documents.compactMap { document -> DirectMessage? in
                    try? document.data(as: DirectMessage.self)
                } ?? []
                
                // Sort by timestamp in memory to ensure proper order
                let sortedMessages = messages.sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
                
                print("📱 Received \(sortedMessages.count) messages")
                completion(sortedMessages)
            }
    }
    
    // MARK: - Mark Messages as Read
    
    func markMessagesAsRead(conversationId: String, userId: String, completion: @escaping (Bool) -> Void) {
        let batch = Firestore.firestore().batch()
        
        // Mark all unread messages as read
        Firestore.firestore().collection("directMessages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching unread messages: \(error)")
                    completion(false)
                    return
                }
                
                // Update each unread message
                for document in snapshot?.documents ?? [] {
                    batch.updateData(["isRead": true], forDocument: document.reference)
                }
                
                // Reset unread count in conversation
                let conversationRef = Firestore.firestore().collection("conversations").document(conversationId)
                batch.updateData(["unreadCount.\(userId)": 0], forDocument: conversationRef)
                
                // Commit batch
                batch.commit { error in
                    if let error = error {
                        print("❌ Error marking messages as read: \(error)")
                        completion(false)
                    } else {
                        print("✅ Messages marked as read")
                        completion(true)
                    }
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func fetchUserDetails(userId: String, completion: @escaping (User?) -> Void) {
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching user details: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists else {
                print("⚠️ User document not found for ID: \(userId)")
                completion(nil)
                return
            }
            
            do {
                let user = try document.data(as: User.self)
                completion(user)
            } catch {
                print("❌ Error decoding user: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Conversation Management
    
    func deleteConversationForUser(conversationId: String, userId: String, completion: @escaping (Bool) -> Void) {
        print("🗑️ Marking conversation \(conversationId) as deleted for user \(userId)")
        
        let conversationRef = Firestore.firestore().collection("conversations").document(conversationId)
        
        conversationRef.updateData([
            "deletedFor": FieldValue.arrayUnion([userId])
        ]) { error in
            if let error = error {
                print("❌ Error deleting conversation: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Conversation marked as deleted for user")
                completion(true)
            }
        }
    }
    
    func restoreConversationForUser(conversationId: String, userId: String, completion: @escaping (Bool) -> Void) {
        print("🔄 Restoring conversation \(conversationId) for user \(userId)")
        
        let conversationRef = Firestore.firestore().collection("conversations").document(conversationId)
        
        conversationRef.updateData([
            "deletedFor": FieldValue.arrayRemove([userId])
        ]) { error in
            if let error = error {
                print("❌ Error restoring conversation: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Conversation restored for user")
                completion(true)
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopListeningToConversations()
        conversations = []
        userDetailsCache.removeAll()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let conversationUpdated = Notification.Name("conversationUpdated")
}

// MARK: - DM Errors
enum DMError: LocalizedError {
    case notAuthenticated
    case emptyMessage
    case conversationNotFound
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .emptyMessage:
            return "Message cannot be empty"
        case .conversationNotFound:
            return "Conversation not found"
        case .userNotFound:
            return "User not found"
        }
    }
} 