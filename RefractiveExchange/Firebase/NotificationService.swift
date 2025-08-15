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
        
        messageCountListener = DirectMessageService.shared.$conversations
            .sink { [weak self] conversations in
                let totalUnread = conversations.reduce(0) { total, conversation in
                    total + conversation.unreadCount
                }
                
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
            
            self.saveNotification(notification)
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
    
    // MARK: - Helper Methods
    
    private func saveNotification(_ notification: AppNotification) {
        // Check if in-app notifications are allowed for this type
        let shouldSaveInApp = NotificationPreferencesManager.shared.shouldSendNotification(
            type: notification.type,
            pushNotification: false,
            postId: notification.metadata?.postId,
            conversationId: notification.metadata?.conversationId,
            senderId: notification.senderId
        )
        
        if shouldSaveInApp {
            do {
                _ = try Firestore.firestore().collection("notifications").addDocument(from: notification)
                print("✅ Notification saved successfully")
            } catch {
                print("❌ Error saving notification: \(error)")
            }
        } else {
            print("🔕 In-app notification blocked by user preferences for type: \(notification.type)")
        }
        
        // Always check push notification preferences separately (user might want push but not in-app)
        sendPushNotificationForAppNotification(notification)
    }
    
    private func sendPushNotificationForAppNotification(_ notification: AppNotification) {
        // Check user preferences before sending push notification
        let shouldSendPush = NotificationPreferencesManager.shared.shouldSendNotification(
            type: notification.type,
            pushNotification: true,
            postId: notification.metadata?.postId,
            conversationId: notification.metadata?.conversationId,
            senderId: notification.senderId
        )
        
        if !shouldSendPush {
            print("🔕 Push notification blocked by user preferences for type: \(notification.type)")
            return
        }
        
        // Create data payload for navigation
        var data: [String: Any] = [
            "notificationId": notification.id ?? "",
            "type": notification.type.rawValue
        ]
        
        // Add specific data based on notification type
        if let metadata = notification.metadata {
            if let postId = metadata.postId {
                data["postId"] = postId
            }
            if let conversationId = metadata.conversationId {
                data["conversationId"] = conversationId
            }
            if let commentId = metadata.commentId {
                data["commentId"] = commentId
            }
        }
        
        // Send the push notification
        PushNotificationManager.shared.sendPushNotification(
            to: notification.recipientId,
            title: notification.title,
            body: notification.message,
            data: data
        )
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
