//
//  NotificationSettingsView.swift
//  RefractiveExchange
//
//  Created for notification preferences management
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var preferencesManager = NotificationPreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if preferencesManager.isLoading {
                    ProgressView("Loading preferences...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            globalSettingsSection
                            pushNotificationSection
                            inAppNotificationSection
                            quietHoursSection
                            mutedContentSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let userId = firebaseManager.currentUser?.uid {
                preferencesManager.loadPreferences(for: userId)
            }
        }
    }
    
    // MARK: - Global Settings Section
    
    private var globalSettingsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Global Settings")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            VStack(spacing: 0) {
                NotificationToggleRow(
                    title: "All Notifications",
                    subtitle: "Master toggle for all notifications",
                    isOn: Binding(
                        get: { preferencesManager.preferences?.allNotificationsEnabled ?? true },
                        set: { preferencesManager.toggleAllNotifications($0) }
                    ),
                    icon: "bell.fill",
                    iconColor: .blue
                )
                
                Divider()
                    .padding(.leading, 56)
                
                NotificationToggleRow(
                    title: "Push Notifications",
                    subtitle: "Notifications when app is closed",
                    isOn: Binding(
                        get: { preferencesManager.preferences?.pushNotifications.enabled ?? true },
                        set: { preferencesManager.togglePushNotifications($0) }
                    ),
                    icon: "iphone",
                    iconColor: .green
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Push Notification Section
    
    private var pushNotificationSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Push Notifications")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            VStack(spacing: 0) {
                NotificationTypeRow(
                    title: "Post Likes",
                    subtitle: "When someone likes your post",
                    icon: "heart.fill",
                    iconColor: .red,
                    type: .postLike,
                    isPush: true
                )
                
                Divider().padding(.leading, 56)
                
                NotificationTypeRow(
                    title: "Post Comments",
                    subtitle: "When someone comments on your post",
                    icon: "bubble.left.fill",
                    iconColor: .blue,
                    type: .postComment,
                    isPush: true
                )
                
                Divider().padding(.leading, 56)
                
                NotificationTypeRow(
                    title: "New Posts",
                    subtitle: "When someone creates a new post",
                    icon: "plus.circle.fill",
                    iconColor: .cyan,
                    type: .newPost,
                    isPush: true
                )
                
                Divider().padding(.leading, 56)
                
                NotificationTypeRow(
                    title: "Comment Likes",
                    subtitle: "When someone likes your comment",
                    icon: "heart.circle.fill",
                    iconColor: .pink,
                    type: .commentLike,
                    isPush: true
                )
                
                Divider().padding(.leading, 56)
                
                NotificationTypeRow(
                    title: "Direct Messages",
                    subtitle: "When you receive a message",
                    icon: "paperplane.fill",
                    iconColor: .purple,
                    type: .directMessage,
                    isPush: true
                )
                
                Divider().padding(.leading, 56)
                
                NotificationTypeRow(
                    title: "Milestones",
                    subtitle: "When your post reaches like milestones",
                    icon: "star.fill",
                    iconColor: .orange,
                    type: .milestone,
                    isPush: true
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - In-App Notification Section
    
    private var inAppNotificationSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("In-App Notifications")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            VStack(spacing: 0) {
                NotificationToggleRow(
                    title: "In-App Notifications",
                    subtitle: "Show notifications while using the app",
                    isOn: Binding(
                        get: { preferencesManager.preferences?.inAppNotifications.enabled ?? true },
                        set: { value in
                            guard var prefs = preferencesManager.preferences else { return }
                            prefs.inAppNotifications.enabled = value
                            preferencesManager.savePreferences(prefs)
                        }
                    ),
                    icon: "app.badge",
                    iconColor: .indigo
                )
                
                if preferencesManager.preferences?.inAppNotifications.enabled == true {
                    Divider().padding(.leading, 56)
                    
                    VStack(spacing: 0) {
                        NotificationTypeRow(
                            title: "Post Interactions",
                            subtitle: "Likes and comments on your posts",
                            icon: "heart.text.square.fill",
                            iconColor: .red,
                            type: .postLike,
                            isPush: false
                        )
                        
                        Divider().padding(.leading, 56)
                        
                        NotificationTypeRow(
                            title: "New Posts",
                            subtitle: "When someone creates a new post",
                            icon: "plus.circle.fill",
                            iconColor: .cyan,
                            type: .newPost,
                            isPush: false
                        )
                        
                        Divider().padding(.leading, 56)
                        
                        NotificationTypeRow(
                            title: "Messages",
                            subtitle: "Direct messages from other users",
                            icon: "message.fill",
                            iconColor: .purple,
                            type: .directMessage,
                            isPush: false
                        )
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Quiet Hours")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            VStack(spacing: 0) {
                NotificationToggleRow(
                    title: "Enable Quiet Hours",
                    subtitle: "Pause push notifications during set hours",
                    isOn: Binding(
                        get: { preferencesManager.preferences?.pushNotifications.quietHours.enabled ?? false },
                        set: { value in
                            guard var prefs = preferencesManager.preferences else { return }
                            prefs.pushNotifications.quietHours.enabled = value
                            preferencesManager.savePreferences(prefs)
                        }
                    ),
                    icon: "moon.fill",
                    iconColor: .indigo
                )
                
                if preferencesManager.preferences?.pushNotifications.quietHours.enabled == true {
                    Divider().padding(.leading, 56)
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                            .padding(.trailing, 8)
                        
                        Text("From")
                            .foregroundColor(.secondary)
                        
                        Text(preferencesManager.preferences?.pushNotifications.quietHours.startTime ?? "22:00")
                            .fontWeight(.medium)
                        
                        Text("to")
                            .foregroundColor(.secondary)
                        
                        Text(preferencesManager.preferences?.pushNotifications.quietHours.endTime ?? "08:00")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Edit") {
                            // TODO: Show time picker
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Muted Content Section
    
    private var mutedContentSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Muted Content")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            VStack(spacing: 0) {
                MutedContentRow(
                    title: "Muted Posts",
                    count: preferencesManager.preferences?.mutedPosts.count ?? 0,
                    icon: "doc.text.fill",
                    iconColor: .orange
                )
                
                Divider().padding(.leading, 56)
                
                MutedContentRow(
                    title: "Muted Conversations",
                    count: preferencesManager.preferences?.mutedConversations.count ?? 0,
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .purple
                )
                
                Divider().padding(.leading, 56)
                
                MutedContentRow(
                    title: "Muted Users",
                    count: preferencesManager.preferences?.mutedUsers.count ?? 0,
                    icon: "person.fill.xmark",
                    iconColor: .red
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct NotificationTypeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let type: NotificationType
    let isPush: Bool
    
    @StateObject private var preferencesManager = NotificationPreferencesManager.shared
    
    private var isEnabled: Bool {
        guard let prefs = preferencesManager.preferences else { return true }
        
        switch type {
        case .postLike:
            return isPush ? prefs.pushNotifications.postLikes : prefs.inAppNotifications.postLikes
        case .postComment:
            return isPush ? prefs.pushNotifications.postComments : prefs.inAppNotifications.postComments
        case .newPost:
            return isPush ? prefs.pushNotifications.newPosts : prefs.inAppNotifications.newPosts
        case .commentLike:
            return isPush ? prefs.pushNotifications.commentLikes : prefs.inAppNotifications.commentLikes
        case .commentReply:
            return isPush ? prefs.pushNotifications.commentReplies : prefs.inAppNotifications.commentReplies
        case .directMessage:
            return isPush ? prefs.pushNotifications.directMessages : prefs.inAppNotifications.directMessages
        case .groupMessage:
            return isPush ? prefs.pushNotifications.groupMessages : prefs.inAppNotifications.groupMessages
        case .milestone:
            return isPush ? prefs.pushNotifications.postMilestones : prefs.inAppNotifications.postMilestones
        case .mention:
            return isPush ? prefs.pushNotifications.mentions : prefs.inAppNotifications.mentions
        case .follow:
            return isPush ? prefs.pushNotifications.follows : prefs.inAppNotifications.follows
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { value in
                    if isPush {
                        preferencesManager.toggleNotificationType(type, pushEnabled: value)
                    } else {
                        preferencesManager.toggleNotificationType(type, inAppEnabled: value)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct MutedContentRow: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("\(count) items muted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Navigate to detailed muted content view
        }
    }
}

#Preview {
    NotificationSettingsView()
}
