//
//  DirectMessage.swift
//  RefractiveExchange
//
//  Created for DM functionality
//

import Foundation
import FirebaseFirestore

// MARK: - Direct Message Model
struct DirectMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var conversationId: String
    var senderId: String
    var recipientId: String
    var text: String
    var timestamp: Timestamp
    var isRead: Bool
    var messageType: MessageType
    
    init(conversationId: String = "", senderId: String = "", recipientId: String = "", text: String = "", timestamp: Timestamp = Timestamp(), isRead: Bool = false, messageType: MessageType = .text) {
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.messageType = messageType
    }
}

// MARK: - Message Type Enum
enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    // Future: video, file, etc.
}

// MARK: - Conversation Model
struct Conversation: Codable, Identifiable {
    @DocumentID var id: String?
    var participants: [String] // Array of user IDs
    var lastMessage: String
    var lastMessageTimestamp: Timestamp
    var unreadCount: [String: Int] // userId: unreadCount mapping
    var createdBy: String
    var createdAt: Timestamp
    var deletedFor: [String]? // Array of user IDs who deleted this conversation from their view
    
    init(participants: [String] = [], lastMessage: String = "", lastMessageTimestamp: Timestamp = Timestamp(), unreadCount: [String: Int] = [:], createdBy: String = "", createdAt: Timestamp = Timestamp(), deletedFor: [String]? = []) {
        self.participants = participants
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.deletedFor = deletedFor
    }
    
    // Helper methods
    func getOtherParticipant(currentUserId: String) -> String? {
        return participants.first { $0 != currentUserId }
    }
    
    func getUnreadCount(for userId: String) -> Int {
        return unreadCount[userId] ?? 0
    }
    
    func isDeletedFor(userId: String) -> Bool {
        return deletedFor?.contains(userId) ?? false
    }
}

// MARK: - Conversation Preview (for list display)
struct ConversationPreview: Identifiable {
    let id: String
    let conversation: Conversation
    let otherUser: User?
    let displayName: String
    let displayAvatar: String?
    let timeAgo: String
    let unreadCount: Int
    
    init(conversation: Conversation, otherUser: User?, currentUserId: String) {
        self.id = conversation.id ?? ""
        self.conversation = conversation
        self.otherUser = otherUser
        
        // Display name logic
        if let otherUser = otherUser {
            self.displayName = "\(otherUser.firstName) \(otherUser.lastName)".trimmingCharacters(in: .whitespaces)
            self.displayAvatar = otherUser.avatarUrl
        } else {
            self.displayName = "Unknown User"
            self.displayAvatar = nil
        }
        
        // Time formatting
        let now = Date()
        let messageDate = conversation.lastMessageTimestamp.dateValue()
        let timeInterval = now.timeIntervalSince(messageDate)
        
        if timeInterval < 60 {
            self.timeAgo = "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            self.timeAgo = "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            self.timeAgo = "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            if days < 7 {
                self.timeAgo = "\(days)d"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                self.timeAgo = formatter.string(from: messageDate)
            }
        }
        
        self.unreadCount = conversation.getUnreadCount(for: currentUserId)
    }
} 