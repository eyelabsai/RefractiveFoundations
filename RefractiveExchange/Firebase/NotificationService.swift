//
//  NotificationService.swift
//  RefractiveExchange
//
//  Created for notification functionality
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

enum MentionContentType {
    case post
    case comment
}

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var notifications: [NotificationPreview] = []
    @Published var notificationCounts = NotificationCounts()
    @Published var unreadMessageCount: Int = 0
    @Published var isLoadingNotifications = false
    
    private var notificationListener: ListenerRegistration?
    private var messageCountListener: AnyCancellable?
    private var userDetailsCache: [String: User] = [:]
    
    private init() {}
    
    // MARK: - Start Listening
    
    func startListening(for userId: String) {
        startListeningToNotifications(for: userId)
        startListeningToMessageCount(for: userId)
    }
    
    private func startListeningToNotifications(for userId: String) {
        print("🔔 Starting to listen for notifications for user: \(userId)")
        isLoadingNotifications = true
        
        notificationListener?.remove()
        
        notificationListener = Firestore.firestore().collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to notifications: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.isLoadingNotifications = false
                    }
                    return
                }
                
                self?.processNotificationSnapshot(snapshot, currentUserId: userId)
            }
    }
    
    private func startListeningToMessageCount(for userId: String) {
        print("💬 Starting to listen for unread message count for user: \(userId)")
        
        messageCountListener?.cancel()
        
        // Combine both DM and group chat unread counts
        messageCountListener = Publishers.CombineLatest(
            DirectMessageService.shared.$conversations,
            GroupChatService.shared.$groupChats
        )
        .sink { [weak self] conversations, groupChats in
            // Calculate DM unread count
            let dmUnread = conversations.reduce(0) { total, conversation in
                total + conversation.unreadCount
            }
            
            // Calculate group chat unread count for current user
            let groupUnread = groupChats.reduce(0) { total, groupPreview in
                total + groupPreview.unreadCount
            }
            
            let totalUnread = dmUnread + groupUnread
            
            DispatchQueue.main.async {
                self?.unreadMessageCount = totalUnread
            }
        }
    }
    
    private func processNotificationSnapshot(_ snapshot: QuerySnapshot?, currentUserId: String) {
        guard let documents = snapshot?.documents else {
            DispatchQueue.main.async {
                self.notifications = []
                self.notificationCounts = NotificationCounts()
                self.isLoadingNotifications = false
            }
            return
        }
        
        print("📄 Processing \(documents.count) notifications")
        
        let allNotifications = documents.compactMap { document -> AppNotification? in
            do {
                return try document.data(as: AppNotification.self)
            } catch {
                print("❌ Error decoding notification: \(error)")
                return nil
            }
        }
        
        // Sort by timestamp
        let sortedNotifications = allNotifications.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
        
        // Calculate counts
        let unreadCount = sortedNotifications.filter { !$0.isRead }.count
        var unreadByType: [NotificationType: Int] = [:]
        
        for notification in sortedNotifications where !notification.isRead {
            unreadByType[notification.type, default: 0] += 1
        }
        
        let counts = NotificationCounts(totalUnread: unreadCount, unreadByType: unreadByType)
        
        // Fetch user details for notifications with senders
        fetchUserDetailsForNotifications(sortedNotifications, counts: counts)
    }
    
    private func fetchUserDetailsForNotifications(_ notifications: [AppNotification], counts: NotificationCounts) {
        let group = DispatchGroup()
        var notificationPreviews: [NotificationPreview] = []
        
        for notification in notifications {
            group.enter()
            
            if let senderId = notification.senderId {
                // Check cache first
                if let cachedUser = userDetailsCache[senderId] {
                    let preview = NotificationPreview(notification: notification, senderUser: cachedUser)
                    notificationPreviews.append(preview)
                    group.leave()
                } else {
                    // Fetch from Firestore
                    fetchUserDetails(userId: senderId) { [weak self] user in
                        if let user = user {
                            self?.userDetailsCache[senderId] = user
                        }
                        let preview = NotificationPreview(notification: notification, senderUser: user)
                        notificationPreviews.append(preview)
                        group.leave()
                    }
                }
            } else {
                // System notification without sender
                let preview = NotificationPreview(notification: notification)
                notificationPreviews.append(preview)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Maintain timestamp sorting
            self.notifications = notificationPreviews.sorted { $0.notification.timestamp.dateValue() > $1.notification.timestamp.dateValue() }
            self.notificationCounts = counts
            self.isLoadingNotifications = false
            print("✅ Loaded \(self.notifications.count) notification previews")
        }
    }
    
    // MARK: - Create Notifications
    
    func createPostLikeNotification(postId: String, postAuthorId: String, likerId: String, postTitle: String) {
        guard postAuthorId != likerId else { return } // Don't notify self
        
        // Check if this is a milestone (every 5th like)
        checkPostLikeMilestone(postId: postId, postAuthorId: postAuthorId, postTitle: postTitle)
        
        // Throttle individual like notifications (only send for 1st, then every 5th)
        getPostLikeCount(postId: postId) { likeCount in
            if likeCount == 1 || likeCount % 5 == 0 {
                self.fetchUserDetails(userId: likerId) { user in
                    let senderName = user != nil ? "\(user!.firstName) \(user!.lastName)" : "Someone"
                    
                    let metadata = NotificationMetadata(
                        postId: postId,
                        likeCount: likeCount,
                        senderDisplayName: senderName,
                        senderAvatarUrl: user?.avatarUrl,
                        postTitle: postTitle
                    )
                    
                    let notification = AppNotification(
                        recipientId: postAuthorId,
                        senderId: likerId,
                        type: .postLike,
                        title: likeCount == 1 ? "New Like" : "\(likeCount) Likes",
                        message: likeCount == 1 ? "\(senderName) liked your post" : "Your post has \(likeCount) likes",
                        isActionable: true,
                        metadata: metadata
                    )
                    
                    self.saveNotification(notification)
                }
            }
        }
    }
    
    func createPostCommentNotification(postId: String, postAuthorId: String, commenterId: String, postTitle: String, commentText: String) {
        guard postAuthorId != commenterId else { return } // Don't notify self
        
        fetchUserDetails(userId: commenterId) { user in
            let senderName = user != nil ? "\(user!.firstName) \(user!.lastName)" : "Someone"
            
            let metadata = NotificationMetadata(
                postId: postId,
                senderDisplayName: senderName,
                senderAvatarUrl: user?.avatarUrl,
                postTitle: postTitle,
                commentText: commentText
            )
            
            let notification = AppNotification(
                recipientId: postAuthorId,
                senderId: commenterId,
                type: .postComment,
                title: "New Comment",
                message: "\(senderName) commented on your post",
                isActionable: true,
                metadata: metadata
            )
            
            self.saveNotification(notification)
        }
    }
    
    func createCommentLikeNotification(commentId: String, commentAuthorId: String, likerId: String, postTitle: String) {
        guard commentAuthorId != likerId else { return } // Don't notify self
        
        fetchUserDetails(userId: likerId) { user in
            let senderName = user != nil ? "\(user!.firstName) \(user!.lastName)" : "Someone"
            
            let metadata = NotificationMetadata(
                commentId: commentId,
                senderDisplayName: senderName,
                senderAvatarUrl: user?.avatarUrl,
                postTitle: postTitle
            )
            
            let notification = AppNotification(
                recipientId: commentAuthorId,
                senderId: likerId,
                type: .commentLike,
                title: "Comment Liked",
                message: "\(senderName) liked your comment",
                isActionable: true,
                metadata: metadata
            )
            
            self.saveNotification(notification)
        }
    }
    
    func createDirectMessageNotification(senderId: String, recipientId: String, conversationId: String, messageText: String) {
        guard senderId != recipientId else { return } // Don't notify self
        
        // For DMs, we don't create in-app notifications (Instagram-style)
        // DM notifications are handled purely through:
        // 1. Push notifications (handled by Cloud Functions)
        // 2. Unread counts in conversations (handled by DirectMessageService)
        // 3. Badge count on DM icon (handled by unreadMessageCount in NotificationService)
        
        fetchUserDetails(userId: senderId) { user in
            let senderName = user != nil ? "\(user!.firstName) \(user!.lastName)" : "Someone"
            
            let metadata = NotificationMetadata(
                conversationId: conversationId,
                senderDisplayName: senderName,
                senderAvatarUrl: user?.avatarUrl
            )
            
            let notification = AppNotification(
                recipientId: recipientId,
                senderId: senderId,
                type: .directMessage,
                title: "New Message",
                message: "\(senderName) sent you a message",
                isActionable: true,
                metadata: metadata
            )
            
            // Only send push notification (handled by Cloud Functions when notification is saved)
            // But don't save to in-app notifications collection
            self.sendPushNotificationOnly(notification)
        }
    }
    
    func createGroupMessageNotification(senderId: String, recipientId: String, groupChatId: String, groupChatName: String, messageText: String) {
        guard senderId != recipientId else { return } // Don't notify self
        
        // For Group Messages, we don't create in-app notifications (Instagram-style)
        // Group message notifications are handled purely through:
        // 1. Push notifications (handled by Cloud Functions)
        // 2. Unread counts in group chats (handled by GroupChatService)
        // 3. Badge count on DM icon (handled by unreadMessageCount in NotificationService)
        
        fetchUserDetails(userId: senderId) { user in
            let senderName = user != nil ? "\(user!.firstName) \(user!.lastName)" : "Someone"
            
            let metadata = NotificationMetadata(
                groupChatId: groupChatId,
                senderDisplayName: senderName,
                senderAvatarUrl: user?.avatarUrl,
                groupChatName: groupChatName
            )
            
            let notification = AppNotification(
                recipientId: recipientId,
                senderId: senderId,
                type: .groupMessage,
                title: "New Group Message",
                message: "\(senderName) sent a message in \(groupChatName)",
                isActionable: true,
                metadata: metadata
            )
            
            // Only send push notification (handled by Cloud Functions when notification is saved)
            // But don't save to in-app notifications collection
            self.sendPushNotificationOnly(notification)
        }
    }
    
    func createNewPostNotification(postId: String, postAuthorId: String, postTitle: String, postSubreddit: String) {
        // Get all users except the post author to send notifications
        getAllUsersExcept(userId: postAuthorId) { userIds in
            guard !userIds.isEmpty else {
                print("📭 No users to notify about new post")
                return
            }
            
            self.fetchUserDetails(userId: postAuthorId) { authorUser in
                let authorName = authorUser != nil ? "\(authorUser!.firstName) \(authorUser!.lastName)" : "Someone"
                
                let metadata = NotificationMetadata(
                    postId: postId,
                    senderDisplayName: authorName,
                    senderAvatarUrl: authorUser?.avatarUrl,
                    postTitle: postTitle
                )
                
                // Create notifications for all users
                for userId in userIds {
                    let notification = AppNotification(
                        recipientId: userId,
                        senderId: postAuthorId,
                        type: .newPost,
                        title: "New Post",
                        message: "\(authorName) shared a new post: \(postTitle)",
                        isActionable: true,
                        metadata: metadata
                    )
                    
                    self.saveNotification(notification)
                }
                
                print("✅ Sent new post notifications to \(userIds.count) users")
            }
        }
    }
    
    func createMentionNotification(mentionerId: String, mentionedUserId: String, contentId: String, contentType: MentionContentType, contentText: String, postTitle: String? = nil, postId: String? = nil) {
        guard mentionerId != mentionedUserId else { return } // Don't notify self
        
        fetchUserDetails(userId: mentionerId) { user in
            let senderName = user != nil ? "\(user!.firstName) \(user!.lastName)" : "Someone"
            
            let (title, message) = self.generateMentionTitleAndMessage(
                senderName: senderName,
                contentType: contentType,
                postTitle: postTitle
            )
            
            let metadata = NotificationMetadata(
                postId: contentType == .post ? contentId : postId,
                commentId: contentType == .comment ? contentId : nil,
                senderDisplayName: senderName,
                senderAvatarUrl: user?.avatarUrl,
                postTitle: postTitle,
                commentText: contentType == .comment ? contentText : nil
            )
            
            let notification = AppNotification(
                recipientId: mentionedUserId,
                senderId: mentionerId,
                type: .mention,
                title: title,
                message: message,
                isActionable: true,
                metadata: metadata
            )
            
            self.saveNotification(notification)
        }
    }
    
    private func generateMentionTitleAndMessage(senderName: String, contentType: MentionContentType, postTitle: String?) -> (String, String) {
        switch contentType {
        case .post:
            return ("You were mentioned", "\(senderName) mentioned you in a post")
        case .comment:
            if let postTitle = postTitle {
                return ("You were mentioned", "\(senderName) mentioned you in a comment on \"\(postTitle)\"")
            } else {
                return ("You were mentioned", "\(senderName) mentioned you in a comment")
            }
        }
    }
    
    private func checkPostLikeMilestone(postId: String, postAuthorId: String, postTitle: String) {
        getPostLikeCount(postId: postId) { likeCount in
            let milestones = [5, 10, 25, 50, 100, 200, 500, 1000]
            if milestones.contains(likeCount) {
                let metadata = NotificationMetadata(
                    postId: postId,
                    likeCount: likeCount,
                    postTitle: postTitle
                )
                
                let notification = AppNotification(
                    recipientId: postAuthorId,
                    type: .milestone,
                    title: "Milestone Reached! 🎉",
                    message: "Your post '\(postTitle)' reached \(likeCount) likes!",
                    isActionable: true,
                    metadata: metadata
                )
                
                self.saveNotification(notification)
            }
        }
    }
    
    // MARK: - Mark as Read
    
    func markNotificationAsRead(_ notificationId: String) {
        Firestore.firestore().collection("notifications").document(notificationId)
            .updateData(["isRead": true]) { error in
                if let error = error {
                    print("❌ Error marking notification as read: \(error)")
                } else {
                    print("✅ Notification marked as read")
                }
            }
    }
    
    func markAllNotificationsAsRead(for userId: String) {
        let batch = Firestore.firestore().batch()
        
        Firestore.firestore().collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching unread notifications: \(error)")
                    return
                }
                
                for document in snapshot?.documents ?? [] {
                    batch.updateData(["isRead": true], forDocument: document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ Error marking all notifications as read: \(error)")
                    } else {
                        print("✅ All notifications marked as read")
                    }
                }
            }
    }
    
    func clearAllNotifications(for userId: String, completion: @escaping (Bool) -> Void) {
        let batch = Firestore.firestore().batch()
        
        Firestore.firestore().collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching notifications to clear: \(error)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No notifications found to clear")
                    completion(true)
                    return
                }
                
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ Error clearing all notifications: \(error)")
                        completion(false)
                    } else {
                        print("✅ All notifications cleared successfully")
                        completion(true)
                    }
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func saveNotification(_ notification: AppNotification) {
        // Check if in-app notifications are allowed for this type
        let shouldSaveInApp = NotificationPreferencesManager.shared.shouldSendNotification(
            type: notification.type,
            pushNotification: false,
            postId: notification.metadata?.postId,
            conversationId: notification.metadata?.conversationId,
            groupChatId: notification.metadata?.groupChatId,
            senderId: notification.senderId
        )
        
        // Check if push notifications are allowed for this type
        let shouldSendPush = NotificationPreferencesManager.shared.shouldSendNotification(
            type: notification.type,
            pushNotification: true,
            postId: notification.metadata?.postId,
            conversationId: notification.metadata?.conversationId,
            groupChatId: notification.metadata?.groupChatId,
            senderId: notification.senderId
        )
        
        // Only save to Firestore if either in-app OR push notifications are allowed
        // The Cloud Function will handle the actual push notification sending
        if shouldSaveInApp || shouldSendPush {
            do {
                _ = try Firestore.firestore().collection("notifications").addDocument(from: notification)
                print("✅ Notification saved successfully to Firestore - Cloud Function will handle push notification")
            } catch {
                print("❌ Error saving notification: \(error)")
            }
        } else {
            print("🔕 Both in-app and push notifications blocked by user preferences for type: \(notification.type)")
        }
    }
    
    // MARK: - Push Notification Only (for DMs/Group Messages)
    
    private func sendPushNotificationOnly(_ notification: AppNotification) {
        // For DMs and Group Messages, we want push notifications but not in-app notifications
        // We save to a temporary collection that Cloud Functions can process
        // but won't show up in the user's notification list
        
        do {
            _ = try Firestore.firestore().collection("pushOnlyNotifications").addDocument(from: notification)
            print("✅ Push-only notification sent for processing by Cloud Functions")
        } catch {
            print("❌ Error saving push-only notification: \(error)")
        }
    }
    
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
    
    private func getPostLikeCount(postId: String, completion: @escaping (Int) -> Void) {
        Firestore.firestore().collection("posts").document(postId).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching post like count: \(error)")
                completion(0)
                return
            }
            
            guard let document = document, document.exists else {
                completion(0)
                return
            }
            
            let upvotes = document.data()?["upvotes"] as? [String] ?? []
            completion(upvotes.count)
        }
    }
    
    private func getAllUsersExcept(userId: String, completion: @escaping ([String]) -> Void) {
        Firestore.firestore().collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching users for new post notification: \(error)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let userIds = documents.compactMap { document in
                let documentId = document.documentID
                return documentId != userId ? documentId : nil
            }
            
            completion(userIds)
        }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        notificationListener?.remove()
        messageCountListener?.cancel()
        notificationListener = nil
        messageCountListener = nil
        notifications = []
        notificationCounts = NotificationCounts()
        unreadMessageCount = 0
        userDetailsCache.removeAll()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let notificationReceived = Notification.Name("notificationReceived")
    static let notificationCountChanged = Notification.Name("notificationCountChanged")
}
