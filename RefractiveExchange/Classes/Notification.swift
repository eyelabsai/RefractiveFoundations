//
//  Notification.swift
//  RefractiveExchange
//
//  Created for notification functionality
//

import Foundation
import FirebaseFirestore

// MARK: - App Notification Model
struct AppNotification: Codable, Identifiable {
    @DocumentID var id: String?
    var recipientId: String
    var senderId: String?
    var type: NotificationType
    var title: String
    var message: String
    var timestamp: Timestamp
    var isRead: Bool
    var isActionable: Bool
    var metadata: NotificationMetadata?
    
    init(recipientId: String, senderId: String? = nil, type: NotificationType, title: String, message: String, timestamp: Timestamp = Timestamp(), isRead: Bool = false, isActionable: Bool = false, metadata: NotificationMetadata? = nil) {
        self.recipientId = recipientId
        self.senderId = senderId
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.isActionable = isActionable
        self.metadata = metadata
    }
}

// MARK: - Notification Types
enum NotificationType: String, Codable, CaseIterable {
    case postLike = "post_like"
    case postComment = "post_comment"
    case commentLike = "comment_like"
    case commentReply = "comment_reply"
    case directMessage = "direct_message"
    case groupMessage = "group_message"
    case milestone = "milestone" // e.g., "Your post reached 10 likes!"
    case mention = "mention" // Future: @username mentions
    case follow = "follow" // Future: user following
    
    var iconName: String {
        switch self {
        case .postLike, .commentLike:
            return "heart.fill"
        case .postComment, .commentReply:
            return "bubble.left.fill"
        case .directMessage:
            return "paperplane.fill"
        case .groupMessage:
            return "person.3.fill"
        case .milestone:
            return "star.fill"
        case .mention:
            return "at"
        case .follow:
            return "person.badge.plus"
        }
    }
    
    var color: String {
        switch self {
        case .postLike, .commentLike:
            return "red"
        case .postComment, .commentReply:
            return "blue"
        case .directMessage:
            return "purple"
        case .groupMessage:
            return "teal"
        case .milestone:
            return "orange"
        case .mention:
            return "green"
        case .follow:
            return "indigo"
        }
    }
}

// MARK: - Notification Metadata
struct NotificationMetadata: Codable {
    var postId: String?
    var commentId: String?
    var conversationId: String?
    var groupChatId: String?
    var likeCount: Int?
    var commentCount: Int?
    var senderDisplayName: String?
    var senderAvatarUrl: String?
    var postTitle: String?
    var commentText: String?
    var groupChatName: String?
    
    init(postId: String? = nil, commentId: String? = nil, conversationId: String? = nil, groupChatId: String? = nil, likeCount: Int? = nil, commentCount: Int? = nil, senderDisplayName: String? = nil, senderAvatarUrl: String? = nil, postTitle: String? = nil, commentText: String? = nil, groupChatName: String? = nil) {
        self.postId = postId
        self.commentId = commentId
        self.conversationId = conversationId
        self.groupChatId = groupChatId
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.senderDisplayName = senderDisplayName
        self.senderAvatarUrl = senderAvatarUrl
        self.postTitle = postTitle
        self.commentText = commentText
        self.groupChatName = groupChatName
    }
}

// MARK: - Notification Preview (for list display)
struct NotificationPreview: Identifiable {
    let id: String
    let notification: AppNotification
    let timeAgo: String
    let displayName: String
    let avatarUrl: String?
    
    init(notification: AppNotification, senderUser: User? = nil) {
        self.id = notification.id ?? ""
        self.notification = notification
        
        // Display name logic
        if let senderUser = senderUser {
            self.displayName = "\(senderUser.firstName) \(senderUser.lastName)".trimmingCharacters(in: .whitespaces)
            self.avatarUrl = senderUser.avatarUrl
        } else if let metadataName = notification.metadata?.senderDisplayName {
            self.displayName = metadataName
            self.avatarUrl = notification.metadata?.senderAvatarUrl
        } else {
            self.displayName = "Someone"
            self.avatarUrl = nil
        }
        
        // Time formatting
        let now = Date()
        let notificationDate = notification.timestamp.dateValue()
        let timeInterval = now.timeIntervalSince(notificationDate)
        
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
                self.timeAgo = formatter.string(from: notificationDate)
            }
        }
    }
}

// MARK: - Notification Counts
struct NotificationCounts: Codable {
    var totalUnread: Int
    var unreadByType: [NotificationType: Int]
    
    init() {
        self.totalUnread = 0
        self.unreadByType = [:]
    }
    
    init(totalUnread: Int, unreadByType: [NotificationType: Int]) {
        self.totalUnread = totalUnread
        self.unreadByType = unreadByType
    }
}
