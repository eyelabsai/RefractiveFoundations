//
//  GroupChatService.swift
//  RefractiveExchange
//
//  Service for managing group chats and messages
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import SwiftUI

class GroupChatService: ObservableObject {
    static let shared = GroupChatService()
    
    private let db = Firestore.firestore()
    @Published var groupChats: [GroupChatPreview] = []
    @Published var isLoadingGroupChats = false
    
    private var groupChatsListener: ListenerRegistration?
    private var groupChatCache: [String: GroupChat] = [:]
    
    private init() {}
    
    // MARK: - Group Chat Creation
    
    /// Creates a new group chat
    func createGroupChat(
        name: String,
        description: String? = nil,
        memberIds: [String] = [],
        isPrivate: Bool = true,
        maxMembers: Int = 50,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(GroupChatError.notAuthenticated))
            return
        }
        
        // Validate group name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            completion(.failure(GroupChatError.invalidGroupName))
            return
        }
        
        // Ensure current user is included in members
        var allMemberIds = memberIds
        if !allMemberIds.contains(currentUserId) {
            allMemberIds.append(currentUserId)
        }
        
        // Create unread counts dictionary
        var unreadCounts: [String: Int] = [:]
        for memberId in allMemberIds {
            unreadCounts[memberId] = 0
        }
        
        let groupChat = GroupChat(
            name: trimmedName,
            description: description,
            ownerId: currentUserId,
            memberIds: allMemberIds.filter { $0 != currentUserId }, // Don't duplicate owner
            createdAt: Timestamp(),
            maxMembers: maxMembers,
            isPrivate: isPrivate,
            unreadCounts: unreadCounts
        )
        
        do {
            let docRef = try db.collection("groupChats").addDocument(from: groupChat)
            print("✅ Group chat created with ID: \(docRef.documentID)")
            
            // Send system message about group creation
            self.sendSystemMessage(
                groupChatId: docRef.documentID,
                senderId: currentUserId,
                systemType: .groupCreated,
                text: "Group '\(trimmedName)' was created"
            )
            
            completion(.success(docRef.documentID))
        } catch {
            print("❌ Error creating group chat: \(error)")
            completion(.failure(error))
        }
    }
    
    // MARK: - Group Chat Management
    
    /// Adds a member to the group
    func addMember(
        groupChatId: String,
        memberId: String,
        addedBy: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let groupRef = db.collection("groupChats").document(groupChatId)
        
        groupRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let groupChat = try? snapshot?.data(as: GroupChat.self) else {
                completion(.failure(GroupChatError.groupNotFound))
                return
            }
            
            // Check permissions
            guard groupChat.canManage(addedBy) else {
                completion(.failure(GroupChatError.insufficientPermissions))
                return
            }
            
            // Check if already a member
            guard !groupChat.isMember(memberId) else {
                completion(.failure(GroupChatError.alreadyMember))
                return
            }
            
            // Check capacity
            guard !groupChat.isAtCapacity else {
                completion(.failure(GroupChatError.groupFull))
                return
            }
            
            // Add member
            groupRef.updateData([
                "memberIds": FieldValue.arrayUnion([memberId]),
                "unreadCounts.\(memberId)": 0
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Get member name for system message
                    self.db.collection("users").document(memberId).getDocument { userSnapshot, _ in
                        var memberName = "A new member"
                        if let userData = userSnapshot?.data(),
                           let firstName = userData["firstName"] as? String,
                           let lastName = userData["lastName"] as? String {
                            memberName = "\(firstName) \(lastName)"
                        }
                        
                        // Send system message with member name
                        self.sendSystemMessage(
                            groupChatId: groupChatId,
                            senderId: addedBy,
                            systemType: .memberJoined,
                            text: "\(memberName) joined the group"
                        )
                    }
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Removes a member from the group
    func removeMember(
        groupChatId: String,
        memberId: String,
        removedBy: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let groupRef = db.collection("groupChats").document(groupChatId)
        
        groupRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let groupChat = try? snapshot?.data(as: GroupChat.self) else {
                completion(.failure(GroupChatError.groupNotFound))
                return
            }
            
            // Check permissions (owner can remove anyone, admins can remove non-admins)
            let canRemove = groupChat.isOwner(removedBy) || 
                           (groupChat.isAdmin(removedBy) && !groupChat.isAdmin(memberId) && !groupChat.isOwner(memberId))
            
            guard canRemove else {
                completion(.failure(GroupChatError.insufficientPermissions))
                return
            }
            
            // Can't remove the owner
            guard !groupChat.isOwner(memberId) else {
                completion(.failure(GroupChatError.cannotRemoveOwner))
                return
            }
            
            // Remove member
            var updateData: [String: Any] = [
                "memberIds": FieldValue.arrayRemove([memberId]),
                "adminIds": FieldValue.arrayRemove([memberId])
            ]
            updateData["unreadCounts.\(memberId)"] = FieldValue.delete()
            
            groupRef.updateData(updateData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Get member name for system message
                    self.db.collection("users").document(memberId).getDocument { userSnapshot, _ in
                        var memberName = "A member"
                        if let userData = userSnapshot?.data(),
                           let firstName = userData["firstName"] as? String,
                           let lastName = userData["lastName"] as? String {
                            memberName = "\(firstName) \(lastName)"
                        }
                        
                        // Send system message with member name
                        self.sendSystemMessage(
                            groupChatId: groupChatId,
                            senderId: removedBy,
                            systemType: .memberRemoved,
                            text: "\(memberName) was removed from the group"
                        )
                    }
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Leave a group (for non-owners)
    func leaveGroup(
        groupChatId: String,
        userId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let groupRef = db.collection("groupChats").document(groupChatId)
        
        groupRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let groupChat = try? snapshot?.data(as: GroupChat.self) else {
                completion(.failure(GroupChatError.groupNotFound))
                return
            }
            
            // Owner cannot leave, must transfer ownership first
            guard !groupChat.isOwner(userId) else {
                completion(.failure(GroupChatError.ownerCannotLeave))
                return
            }
            
            // Remove user
            var updateData: [String: Any] = [
                "memberIds": FieldValue.arrayRemove([userId]),
                "adminIds": FieldValue.arrayRemove([userId])
            ]
            updateData["unreadCounts.\(userId)"] = FieldValue.delete()
            
            groupRef.updateData(updateData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Get member name for system message
                    self.db.collection("users").document(userId).getDocument { userSnapshot, _ in
                        var memberName = "A member"
                        if let userData = userSnapshot?.data(),
                           let firstName = userData["firstName"] as? String,
                           let lastName = userData["lastName"] as? String {
                            memberName = "\(firstName) \(lastName)"
                        }
                        
                        // Send system message with member name
                        self.sendSystemMessage(
                            groupChatId: groupChatId,
                            senderId: userId,
                            systemType: .memberLeft,
                            text: "\(memberName) left the group"
                        )
                    }
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Delete a group chat (only owner can delete)
    func deleteGroupChat(
        groupChatId: String,
        deletedBy: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let groupRef = db.collection("groupChats").document(groupChatId)
        
        groupRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let groupChat = try? snapshot?.data(as: GroupChat.self) else {
                completion(.failure(GroupChatError.groupNotFound))
                return
            }
            
            // Only owner can delete the group
            guard groupChat.isOwner(deletedBy) else {
                completion(.failure(GroupChatError.insufficientPermissions))
                return
            }
            
            // Use batch to delete group and all its messages
            let batch = self.db.batch()
            
            // Set group as inactive instead of deleting (to preserve message history)
            batch.updateData([
                "isActive": false,
                "deletedAt": Timestamp(),
                "deletedBy": deletedBy
            ], forDocument: groupRef)
            
            // Optionally, also delete all group messages
            // Note: This is optional - you might want to keep messages for audit purposes
            self.db.collection("groupMessages")
                .whereField("groupChatId", isEqualTo: groupChatId)
                .getDocuments { messagesSnapshot, error in
                    
                    if let messagesSnapshot = messagesSnapshot {
                        for messageDoc in messagesSnapshot.documents {
                            batch.deleteDocument(messageDoc.reference)
                        }
                    }
                    
                    // Commit the batch
                    batch.commit { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            print("✅ Group chat deleted successfully")
                            completion(.success(()))
                        }
                    }
                }
        }
    }
    
    // MARK: - Group Chat Messaging
    
    /// Sends a message to a group chat
    func sendGroupMessage(
        groupChatId: String,
        text: String,
        senderId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(GroupChatError.emptyMessage))
            return
        }
        
        // Get sender details
        db.collection("users").document(senderId).getDocument { userSnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = try? userSnapshot?.data(as: User.self) else {
                completion(.failure(GroupChatError.userNotFound))
                return
            }
            
            let senderName = "\(user.firstName) \(user.lastName)"
            
            // Create the message
            let message = GroupMessage(
                groupChatId: groupChatId,
                senderId: senderId,
                senderName: senderName,
                text: text,
                timestamp: Timestamp(),
                readBy: [senderId] // Sender has read their own message
            )
            
            // Use batch to update both message and group chat
            let batch = self.db.batch()
            
            // Add message
            let messageRef = self.db.collection("groupMessages").document()
            do {
                try batch.setData(from: message, forDocument: messageRef)
            } catch {
                completion(.failure(error))
                return
            }
            
            // Update group chat last message and increment unread counts
            let groupRef = self.db.collection("groupChats").document(groupChatId)
            
            // First get current group to update unread counts
            groupRef.getDocument { groupSnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let groupChat = try? groupSnapshot?.data(as: GroupChat.self) else {
                    completion(.failure(GroupChatError.groupNotFound))
                    return
                }
                
                // Check if sender is a member
                guard groupChat.isMember(senderId) else {
                    completion(.failure(GroupChatError.notMember))
                    return
                }
                
                // Update unread counts for all members except sender
                var unreadUpdates: [String: Any] = [:]
                for memberId in groupChat.allMemberIds {
                    if memberId != senderId {
                        unreadUpdates["unreadCounts.\(memberId)"] = FieldValue.increment(Int64(1))
                    }
                }
                
                unreadUpdates["lastMessage"] = text
                unreadUpdates["lastMessageTimestamp"] = Timestamp()
                unreadUpdates["lastMessageSenderId"] = senderId
                
                batch.updateData(unreadUpdates, forDocument: groupRef)
                
                // Commit batch
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        print("✅ Group message sent successfully")
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    /// Sends a system message
    private func sendSystemMessage(
        groupChatId: String,
        senderId: String,
        systemType: SystemMessageType,
        text: String
    ) {
        let message = GroupMessage(
            groupChatId: groupChatId,
            senderId: senderId,
            senderName: "System",
            text: text,
            timestamp: Timestamp(),
            messageType: .system,
            readBy: [],
            isSystemMessage: true,
            systemMessageType: systemType
        )
        
        do {
            try db.collection("groupMessages").addDocument(from: message)
        } catch {
            print("❌ Error sending system message: \(error)")
        }
    }
    
    // MARK: - Group Chat Listening
    
    /// Start listening for group chats for a user
    func startListeningToGroupChats(for userId: String) {
        print("🎧 Starting to listen for group chats for user: \(userId)")
        isLoadingGroupChats = true
        
        groupChatsListener?.remove()
        
        // Query groups where user is owner or member
        groupChatsListener = db.collection("groupChats")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to group chats: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.isLoadingGroupChats = false
                    }
                    return
                }
                
                self?.processGroupChatsSnapshot(snapshot, currentUserId: userId)
            }
    }
    
    private func processGroupChatsSnapshot(_ snapshot: QuerySnapshot?, currentUserId: String) {
        guard let documents = snapshot?.documents else {
            DispatchQueue.main.async {
                self.groupChats = []
                self.isLoadingGroupChats = false
            }
            return
        }
        
        let allGroupChats = documents.compactMap { document -> GroupChat? in
            try? document.data(as: GroupChat.self)
        }
        
        // Filter to only groups where current user is a member
        let userGroupChats = allGroupChats.filter { groupChat in
            groupChat.isMember(currentUserId)
        }
        
        // Create previews
        let previews = userGroupChats.map { groupChat in
            GroupChatPreview(groupChat: groupChat, currentUserId: currentUserId)
        }.sorted { $0.groupChat.lastMessageTimestamp.dateValue() > $1.groupChat.lastMessageTimestamp.dateValue() }
        
        DispatchQueue.main.async {
            // Use animation to prevent UI crashes when updating data
            withAnimation(.easeInOut(duration: 0.2)) {
                self.groupChats = previews
            }
            self.isLoadingGroupChats = false
            print("✅ Loaded \(previews.count) group chats")
        }
    }
    
    /// Stop listening to group chats
    func stopListeningToGroupChats() {
        groupChatsListener?.remove()
        groupChatsListener = nil
    }
    
    /// Listen to messages for a specific group chat
    func listenToGroupMessages(
        groupChatId: String,
        completion: @escaping ([GroupMessage]) -> Void
    ) -> ListenerRegistration {
        return db.collection("groupMessages")
            .whereField("groupChatId", isEqualTo: groupChatId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to group messages: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let messages = snapshot?.documents.compactMap { document -> GroupMessage? in
                    try? document.data(as: GroupMessage.self)
                } ?? []
                
                // Sort by timestamp
                let sortedMessages = messages.sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
                completion(sortedMessages)
            }
    }
    
    /// Mark messages as read for a user
    func markGroupMessagesAsRead(
        groupChatId: String,
        userId: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Reset unread count for the user
        db.collection("groupChats").document(groupChatId).updateData([
            "unreadCounts.\(userId)": 0
        ]) { error in
            if let error = error {
                print("❌ Error marking group messages as read: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopListeningToGroupChats()
        groupChats = []
        groupChatCache.removeAll()
    }
}

// MARK: - Group Chat Errors
enum GroupChatError: LocalizedError {
    case notAuthenticated
    case invalidGroupName
    case groupNotFound
    case userNotFound
    case insufficientPermissions
    case alreadyMember
    case notMember
    case groupFull
    case cannotRemoveOwner
    case ownerCannotLeave
    case emptyMessage
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidGroupName:
            return "Invalid group name"
        case .groupNotFound:
            return "Group chat not found"
        case .userNotFound:
            return "User not found"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .alreadyMember:
            return "User is already a member"
        case .notMember:
            return "User is not a member of this group"
        case .groupFull:
            return "Group is at maximum capacity"
        case .cannotRemoveOwner:
            return "Cannot remove group owner"
        case .ownerCannotLeave:
            return "Owner cannot leave group. Transfer ownership first."
        case .emptyMessage:
            return "Message cannot be empty"
        }
    }
}
