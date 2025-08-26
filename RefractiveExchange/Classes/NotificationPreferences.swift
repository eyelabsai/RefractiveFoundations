//
//  NotificationPreferences.swift
//  RefractiveExchange
//
//  Created for notification preference management
//

import Foundation
import FirebaseFirestore

// MARK: - Notification Preferences Model
struct NotificationPreferences: Codable {
    var userId: String
    var lastUpdated: Timestamp
    
    // Global toggle
    var allNotificationsEnabled: Bool
    
    // Push notification toggles
    var pushNotifications: PushNotificationSettings
    
    // In-app notification toggles  
    var inAppNotifications: InAppNotificationSettings
    
    // Email notification toggles (for future)
    var emailNotifications: EmailNotificationSettings
    
    // Specific post/conversation mutes
    var mutedPosts: [String] // Array of post IDs
    var mutedConversations: [String] // Array of conversation IDs
    var mutedGroupChats: [String] // Array of group chat IDs
    var mutedUsers: [String] // Array of user IDs to mute
    
    init(userId: String) {
        self.userId = userId
        self.lastUpdated = Timestamp()
        self.allNotificationsEnabled = true
        
        // Default to all enabled for good user experience
        self.pushNotifications = PushNotificationSettings()
        self.inAppNotifications = InAppNotificationSettings()
        self.emailNotifications = EmailNotificationSettings()
        
        self.mutedPosts = []
        self.mutedConversations = []
        self.mutedGroupChats = []
        self.mutedUsers = []
    }
}

// MARK: - Push Notification Settings
struct PushNotificationSettings: Codable {
    var enabled: Bool
    
    // Post-related notifications
    var postLikes: Bool
    var postComments: Bool
    var postMilestones: Bool
    
    // Comment-related notifications  
    var commentLikes: Bool
    var commentReplies: Bool
    
    // Direct messages
    var directMessages: Bool
    
    // Group messages
    var groupMessages: Bool
    
    // Social notifications
    var mentions: Bool // Future: @username mentions
    var follows: Bool  // Future: user following
    
    // Frequency settings
    var quietHours: QuietHoursSettings
    
    init() {
        self.enabled = true
        self.postLikes = true
        self.postComments = true
        self.postMilestones = true
        self.commentLikes = true
        self.commentReplies = true
        self.directMessages = true
        self.groupMessages = true
        self.mentions = true
        self.follows = true
        self.quietHours = QuietHoursSettings()
    }
}

// MARK: - In-App Notification Settings
struct InAppNotificationSettings: Codable {
    var enabled: Bool
    
    var postLikes: Bool
    var postComments: Bool
    var postMilestones: Bool
    var commentLikes: Bool
    var commentReplies: Bool
    var directMessages: Bool
    var groupMessages: Bool
    var mentions: Bool
    var follows: Bool
    
    init() {
        self.enabled = true
        self.postLikes = true
        self.postComments = true
        self.postMilestones = true
        self.commentLikes = true
        self.commentReplies = true
        self.directMessages = true
        self.groupMessages = true
        self.mentions = true
        self.follows = true
    }
}

// MARK: - Email Notification Settings
struct EmailNotificationSettings: Codable {
    var enabled: Bool
    
    var weeklyDigest: Bool
    var majorMilestones: Bool
    var directMessages: Bool
    var importantUpdates: Bool
    
    init() {
        self.enabled = false // Default off for email
        self.weeklyDigest = false
        self.majorMilestones = true
        self.directMessages = false
        self.importantUpdates = true
    }
}

// MARK: - Quiet Hours Settings
struct QuietHoursSettings: Codable {
    var enabled: Bool
    var startTime: String // Format: "22:00"
    var endTime: String   // Format: "08:00"
    var timezone: String
    
    init() {
        self.enabled = false
        self.startTime = "22:00"
        self.endTime = "08:00"
        self.timezone = TimeZone.current.identifier
    }
}

// MARK: - Notification Preferences Manager
class NotificationPreferencesManager: ObservableObject {
    static let shared = NotificationPreferencesManager()
    
    @Published var preferences: NotificationPreferences?
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Load Preferences
    
    func loadPreferences(for userId: String) {
        isLoading = true
        
        db.collection("notificationPreferences").document(userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Error loading notification preferences: \(error.localizedDescription)")
                    // Create default preferences if none exist
                    self?.createDefaultPreferences(for: userId)
                    return
                }
                
                if let document = document, document.exists {
                    do {
                        self?.preferences = try document.data(as: NotificationPreferences.self)
                        print("✅ Loaded notification preferences")
                    } catch {
                        print("❌ Error decoding preferences: \(error)")
                        self?.createDefaultPreferences(for: userId)
                    }
                } else {
                    // Create default preferences for new user
                    self?.createDefaultPreferences(for: userId)
                }
            }
        }
    }
    
    private func createDefaultPreferences(for userId: String) {
        let defaultPrefs = NotificationPreferences(userId: userId)
        preferences = defaultPrefs
        savePreferences(defaultPrefs)
    }
    
    // MARK: - Save Preferences
    
    func savePreferences(_ preferences: NotificationPreferences) {
        var updatedPrefs = preferences
        updatedPrefs.lastUpdated = Timestamp()
        
        do {
            try db.collection("notificationPreferences").document(preferences.userId).setData(from: updatedPrefs)
            self.preferences = updatedPrefs
            print("✅ Saved notification preferences")
        } catch {
            print("❌ Error saving notification preferences: \(error)")
        }
    }
    
    // MARK: - Quick Toggles
    
    func toggleAllNotifications(_ enabled: Bool) {
        guard var prefs = preferences else { return }
        prefs.allNotificationsEnabled = enabled
        savePreferences(prefs)
    }
    
    func togglePushNotifications(_ enabled: Bool) {
        guard var prefs = preferences else { return }
        prefs.pushNotifications.enabled = enabled
        savePreferences(prefs)
    }
    
    func toggleNotificationType(_ type: NotificationType, pushEnabled: Bool? = nil, inAppEnabled: Bool? = nil) {
        guard var prefs = preferences else { return }
        
        switch type {
        case .postLike:
            if let push = pushEnabled { prefs.pushNotifications.postLikes = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.postLikes = inApp }
        case .postComment:
            if let push = pushEnabled { prefs.pushNotifications.postComments = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.postComments = inApp }
        case .commentLike:
            if let push = pushEnabled { prefs.pushNotifications.commentLikes = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.commentLikes = inApp }
        case .commentReply:
            if let push = pushEnabled { prefs.pushNotifications.commentReplies = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.commentReplies = inApp }
        case .directMessage:
            if let push = pushEnabled { prefs.pushNotifications.directMessages = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.directMessages = inApp }
        case .groupMessage:
            if let push = pushEnabled { prefs.pushNotifications.groupMessages = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.groupMessages = inApp }
        case .milestone:
            if let push = pushEnabled { prefs.pushNotifications.postMilestones = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.postMilestones = inApp }
        case .mention:
            if let push = pushEnabled { prefs.pushNotifications.mentions = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.mentions = inApp }
        case .follow:
            if let push = pushEnabled { prefs.pushNotifications.follows = push }
            if let inApp = inAppEnabled { prefs.inAppNotifications.follows = inApp }
        }
        
        savePreferences(prefs)
    }
    
    // MARK: - Muting Functions
    
    func mutePost(_ postId: String) {
        guard var prefs = preferences else { return }
        if !prefs.mutedPosts.contains(postId) {
            prefs.mutedPosts.append(postId)
            savePreferences(prefs)
        }
    }
    
    func unmutePost(_ postId: String) {
        guard var prefs = preferences else { return }
        prefs.mutedPosts.removeAll { $0 == postId }
        savePreferences(prefs)
    }
    
    func muteConversation(_ conversationId: String) {
        guard var prefs = preferences else { return }
        if !prefs.mutedConversations.contains(conversationId) {
            prefs.mutedConversations.append(conversationId)
            savePreferences(prefs)
        }
    }
    
    func unmuteConversation(_ conversationId: String) {
        guard var prefs = preferences else { return }
        prefs.mutedConversations.removeAll { $0 == conversationId }
        savePreferences(prefs)
    }
    
    func muteUser(_ userId: String) {
        guard var prefs = preferences else { return }
        if !prefs.mutedUsers.contains(userId) {
            prefs.mutedUsers.append(userId)
            savePreferences(prefs)
        }
    }
    
    func unmuteUser(_ userId: String) {
        guard var prefs = preferences else { return }
        prefs.mutedUsers.removeAll { $0 == userId }
        savePreferences(prefs)
    }
    
    // MARK: - Check Functions
    
    func shouldSendNotification(type: NotificationType, pushNotification: Bool = true, postId: String? = nil, conversationId: String? = nil, groupChatId: String? = nil, senderId: String? = nil) -> Bool {
        guard let prefs = preferences else { return true } // Default to true if no preferences
        
        // Global toggle
        if !prefs.allNotificationsEnabled { return false }
        
        // Check if sender is muted
        if let senderId = senderId, prefs.mutedUsers.contains(senderId) { return false }
        
        // Check if post is muted
        if let postId = postId, prefs.mutedPosts.contains(postId) { return false }
        
        // Check if conversation is muted
        if let conversationId = conversationId, prefs.mutedConversations.contains(conversationId) { return false }
        
        // Check if group chat is muted
        if let groupChatId = groupChatId, prefs.mutedGroupChats.contains(groupChatId) { return false }
        
        // Check quiet hours for push notifications
        if pushNotification && prefs.pushNotifications.quietHours.enabled {
            if isWithinQuietHours(prefs.pushNotifications.quietHours) { return false }
        }
        
        // Check specific notification type settings based on type
        if pushNotification && !prefs.pushNotifications.enabled { return false }
        if !pushNotification && !prefs.inAppNotifications.enabled { return false }
        
        switch type {
        case .postLike:
            return pushNotification ? prefs.pushNotifications.postLikes : prefs.inAppNotifications.postLikes
        case .postComment:
            return pushNotification ? prefs.pushNotifications.postComments : prefs.inAppNotifications.postComments
        case .commentLike:
            return pushNotification ? prefs.pushNotifications.commentLikes : prefs.inAppNotifications.commentLikes
        case .commentReply:
            return pushNotification ? prefs.pushNotifications.commentReplies : prefs.inAppNotifications.commentReplies
        case .directMessage:
            return pushNotification ? prefs.pushNotifications.directMessages : prefs.inAppNotifications.directMessages
        case .groupMessage:
            return pushNotification ? prefs.pushNotifications.groupMessages : prefs.inAppNotifications.groupMessages
        case .milestone:
            return pushNotification ? prefs.pushNotifications.postMilestones : prefs.inAppNotifications.postMilestones
        case .mention:
            return pushNotification ? prefs.pushNotifications.mentions : prefs.inAppNotifications.mentions
        case .follow:
            return pushNotification ? prefs.pushNotifications.follows : prefs.inAppNotifications.follows
        }
    }
    
    private func isWithinQuietHours(_ quietHours: QuietHoursSettings) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: quietHours.timezone)
        
        let now = Date()
        let currentTime = formatter.string(from: now)
        
        // Simple time comparison (doesn't handle cross-midnight scenarios perfectly)
        return currentTime >= quietHours.startTime || currentTime <= quietHours.endTime
    }
}
