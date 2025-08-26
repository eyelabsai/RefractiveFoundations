//
//  GroupChat.swift
//  RefractiveExchange
//
//  Group Chat data models for exclusive group messaging
//

import Foundation
import FirebaseFirestore

// MARK: - Group Chat
struct GroupChat: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var ownerId: String
    var memberIds: [String]
    var adminIds: [String] // Members who can manage the group (excluding owner)
    var createdAt: Timestamp
    var lastMessage: String
    var lastMessageTimestamp: Timestamp
    var lastMessageSenderId: String?
    var isActive: Bool
    var maxMembers: Int
    var isPrivate: Bool // If true, only owner can add members
    var groupImageUrl: String?
    var unreadCounts: [String: Int] // userId: unreadCount
    
    init(
        name: String,
        description: String? = nil,
        ownerId: String,
        memberIds: [String] = [],
        adminIds: [String] = [],
        createdAt: Timestamp = Timestamp(),
        lastMessage: String = "",
        lastMessageTimestamp: Timestamp = Timestamp(),
        lastMessageSenderId: String? = nil,
        isActive: Bool = true,
        maxMembers: Int = 50,
        isPrivate: Bool = true,
        groupImageUrl: String? = nil,
        unreadCounts: [String: Int] = [:]
    ) {
        self.name = name
        self.description = description
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.adminIds = adminIds
        self.createdAt = createdAt
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessageSenderId = lastMessageSenderId
        self.isActive = isActive
        self.maxMembers = maxMembers
        self.isPrivate = isPrivate
        self.groupImageUrl = groupImageUrl
        self.unreadCounts = unreadCounts
    }
    
    // MARK: - Helper Methods
    
    /// Returns all member IDs including the owner
    var allMemberIds: [String] {
        var members = memberIds
        if !members.contains(ownerId) {
            members.append(ownerId)
        }
        return members
    }
    
    /// Check if a user is the owner
    func isOwner(_ userId: String) -> Bool {
        return ownerId == userId
    }
    
    /// Check if a user is an admin (but not owner)
    func isAdmin(_ userId: String) -> Bool {
        return adminIds.contains(userId)
    }
    
    /// Check if a user can manage the group (owner or admin)
    func canManage(_ userId: String) -> Bool {
        return isOwner(userId) || isAdmin(userId)
    }
    
    /// Check if a user is a member of the group
    func isMember(_ userId: String) -> Bool {
        return allMemberIds.contains(userId)
    }
    
    /// Get unread count for a specific user
    func unreadCount(for userId: String) -> Int {
        return unreadCounts[userId] ?? 0
    }
    
    /// Check if group is at capacity
    var isAtCapacity: Bool {
        return allMemberIds.count >= maxMembers
    }
}

// MARK: - Group Message
struct GroupMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var groupChatId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Timestamp
    var messageType: MessageType
    var replyTo: String? // ID of message being replied to
    var readBy: [String] // Array of user IDs who have read this message
    var isSystemMessage: Bool // For join/leave notifications etc.
    var systemMessageType: SystemMessageType?
    
    init(
        groupChatId: String,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Timestamp = Timestamp(),
        messageType: MessageType = .text,
        replyTo: String? = nil,
        readBy: [String] = [],
        isSystemMessage: Bool = false,
        systemMessageType: SystemMessageType? = nil
    ) {
        self.groupChatId = groupChatId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.messageType = messageType
        self.replyTo = replyTo
        self.readBy = readBy
        self.isSystemMessage = isSystemMessage
        self.systemMessageType = systemMessageType
    }
    
    /// Check if message has been read by a specific user
    func isReadBy(_ userId: String) -> Bool {
        return readBy.contains(userId)
    }
}

// Note: MessageType is imported from DirectMessage.swift

// MARK: - System Message Type
enum SystemMessageType: String, Codable {
    case memberJoined = "member_joined"
    case memberLeft = "member_left"
    case memberRemoved = "member_removed"
    case memberPromoted = "member_promoted"
    case memberDemoted = "member_demoted"
    case groupCreated = "group_created"
    case groupNameChanged = "group_name_changed"
    case groupDescriptionChanged = "group_description_changed"
    case ownershipTransferred = "ownership_transferred"
}

// MARK: - Group Chat Preview (for UI)
struct GroupChatPreview: Identifiable {
    let id: String
    let groupChat: GroupChat
    let memberCount: Int
    let displayName: String
    let lastMessagePreview: String
    let timeAgo: String
    let unreadCount: Int
    let currentUserId: String
    
    init(groupChat: GroupChat, currentUserId: String) {
        self.id = groupChat.id ?? UUID().uuidString
        self.groupChat = groupChat
        self.memberCount = groupChat.allMemberIds.count
        self.displayName = groupChat.name
        self.currentUserId = currentUserId
        self.unreadCount = groupChat.unreadCount(for: currentUserId)
        
        // Format last message preview
        if groupChat.lastMessage.isEmpty {
            self.lastMessagePreview = "No messages yet"
        } else {
            self.lastMessagePreview = groupChat.lastMessage
        }
        
        // Format time ago
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        self.timeAgo = formatter.localizedString(for: groupChat.lastMessageTimestamp.dateValue(), relativeTo: Date())
    }
}

// MARK: - Group Invite
struct GroupInvite: Codable, Identifiable {
    @DocumentID var id: String?
    var groupChatId: String
    var groupName: String
    var inviterId: String
    var inviterName: String
    var inviteeId: String
    var createdAt: Timestamp
    var expiresAt: Timestamp?
    var status: InviteStatus
    var message: String?
    
    init(
        groupChatId: String,
        groupName: String,
        inviterId: String,
        inviterName: String,
        inviteeId: String,
        createdAt: Timestamp = Timestamp(),
        expiresAt: Timestamp? = nil,
        status: InviteStatus = .pending,
        message: String? = nil
    ) {
        self.groupChatId = groupChatId
        self.groupName = groupName
        self.inviterId = inviterId
        self.inviterName = inviterName
        self.inviteeId = inviteeId
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.status = status
        self.message = message
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt.dateValue() < Date()
    }
}

// MARK: - Invite Status
enum InviteStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
    case cancelled = "cancelled"
}
