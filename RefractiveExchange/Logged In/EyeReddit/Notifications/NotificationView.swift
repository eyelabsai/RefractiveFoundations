//
//  NotificationView.swift
//  RefractiveExchange
//
//  Created for notification functionality
//

import SwiftUI
import Firebase
// NotificationService is a Swift class, not a module - we'll use it directly

struct NotificationView: View {
    @ObservedObject var notificationService = NotificationService.shared
    @ObservedObject var firebaseManager = FirebaseManager.shared
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingFilterMenu = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedPost: FetchedPost?
    @State private var isLoadingPost = false
    @State private var showingClearAllAlert = false
    @State private var isOperationInProgress = false
    @ObservedObject var data = GetData()
    
    var filteredNotifications: [NotificationPreview] {
        switch selectedFilter {
        case .all:
            return notificationService.notifications
        case .unread:
            return notificationService.notifications.filter { !$0.notification.isRead }
        case .likes:
            return notificationService.notifications.filter { 
                $0.notification.type == .postLike || $0.notification.type == .commentLike 
            }
        case .comments:
            return notificationService.notifications.filter { $0.notification.type == .postComment }
        case .messages:
            return notificationService.notifications.filter { $0.notification.type == .directMessage }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter bar
                filterBar
                
                // Notifications list
                notificationsList
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All as Read") {
                            markAllNotificationsAsRead()
                        }
                        .disabled(notificationService.notificationCounts.totalUnread == 0 || isOperationInProgress)
                        
                        Divider()
                        
                        Button("Clear All Notifications", role: .destructive) {
                            showingClearAllAlert = true
                        }
                        .disabled(notificationService.notifications.isEmpty || isOperationInProgress)
                        
                        Divider()
                        
                        Button("Filter Options") {
                            showingFilterMenu = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isOperationInProgress {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                    }
                    .disabled(isOperationInProgress)
                }
            }
            .actionSheet(isPresented: $showingFilterMenu) {
                ActionSheet(
                    title: Text("Filter Notifications"),
                    buttons: NotificationFilter.allCases.map { filter in
                        .default(Text(filter.title)) {
                            selectedFilter = filter
                        }
                    } + [.cancel()]
                )
            }
            .alert("Clear All Notifications", isPresented: $showingClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllNotifications()
                }
            } message: {
                Text("This will permanently delete all your notifications. This action cannot be undone.")
            }
            .navigationDestination(for: FetchedPost.self) { post in
                PostDetailView(post: post, data: data)
            }
        }
        .onAppear {
            if let currentUserId = firebaseManager.currentUser?.uid {
                notificationService.startListening(for: currentUserId)
            }
        }
        .onDisappear {
            // Keep listening for real-time updates
        }
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    NotificationFilterChip(
                        title: filter.title,
                        count: getFilterCount(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Notifications List
    @ViewBuilder
    private var notificationsList: some View {
        if notificationService.isLoadingNotifications {
            loadingView
        } else if filteredNotifications.isEmpty {
            emptyStateView
        } else {
            List {
                ForEach(filteredNotifications) { notificationPreview in
                    NotificationRowView(
                        notificationPreview: notificationPreview,
                        onTap: {
                            handleNotificationTap(notificationPreview)
                        }
                    )
                    .onAppear {
                        if !notificationPreview.notification.isRead {
                            notificationService.markNotificationAsRead(notificationPreview.notification.id ?? "")
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .overlay(
                Group {
                    if isLoadingPost {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(1.2)
                                
                                Text("Loading post...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.2), radius: 8)
                            )
                        }
                    }
                }
            )
            .refreshable {
                if let currentUserId = firebaseManager.currentUser?.uid {
                    notificationService.startListening(for: currentUserId)
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading notifications...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "No notifications yet"
        case .unread:
            return "All caught up!"
        case .likes:
            return "No likes yet"
        case .comments:
            return "No comments yet"
        case .messages:
            return "No message notifications"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "When people interact with your posts, you'll see notifications here"
        case .unread:
            return "You're all up to date with your notifications"
        case .likes:
            return "When people like your posts or comments, you'll see them here"
        case .comments:
            return "When people comment on your posts, you'll see them here"
        case .messages:
            return "Message notifications appear here when you're not in the conversation"
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFilterCount(_ filter: NotificationFilter) -> Int {
        switch filter {
        case .all:
            return notificationService.notifications.count
        case .unread:
            return notificationService.notificationCounts.totalUnread
        case .likes:
            return (notificationService.notificationCounts.unreadByType[.postLike] ?? 0) + 
                   (notificationService.notificationCounts.unreadByType[.commentLike] ?? 0)
        case .comments:
            return notificationService.notificationCounts.unreadByType[.postComment] ?? 0
        case .messages:
            return notificationService.notificationCounts.unreadByType[.directMessage] ?? 0
        }
    }
    
    private func handleNotificationTap(_ notificationPreview: NotificationPreview) {
        let notification = notificationPreview.notification
        
        switch notification.type {
        case .postLike, .postComment, .milestone:
            if let postId = notification.metadata?.postId {
                navigateToPost(postId: postId)
            }
        case .commentLike, .commentReply:
            if let postId = notification.metadata?.postId {
                // Navigate to post detail with comment highlighted
                navigateToPost(postId: postId)
            }
        case .directMessage:
            if let conversationId = notification.metadata?.conversationId {
                // Navigate to conversation
                print("🔗 Navigate to conversation: \(conversationId)")
                // TODO: Implement conversation navigation
            }
        case .mention, .follow:
            // Handle other types as needed
            break
        }
    }
    
    private func navigateToPost(postId: String) {
        print("🔗 Fetching post for navigation: \(postId)")
        isLoadingPost = true
        
        PostService().fetchPostById(postId) { (fetchedPost: FetchedPost?) in
            DispatchQueue.main.async {
                self.isLoadingPost = false
                if let post = fetchedPost {
                    print("✅ Post fetched successfully, navigating to: \(post.title)")
                    self.navigationPath.append(post)
                } else {
                    print("❌ Failed to fetch post for navigation")
                }
            }
        }
    }
    
    // MARK: - Action Methods
    
    private func markAllNotificationsAsRead() {
        guard let currentUserId = firebaseManager.currentUser?.uid else { return }
        
        isOperationInProgress = true
        notificationService.markAllNotificationsAsRead(for: currentUserId)
        
        // Reset operation state after a delay since the notification service doesn't provide completion callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isOperationInProgress = false
        }
    }
    
    private func clearAllNotifications() {
        guard let currentUserId = firebaseManager.currentUser?.uid else { return }
        
        isOperationInProgress = true
        notificationService.clearAllNotifications(for: currentUserId) { success in
            DispatchQueue.main.async {
                isOperationInProgress = false
                if success {
                    // Optionally show a success message or haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
}

// MARK: - Notification Filter Chip
struct NotificationFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Row View
struct NotificationRowView: View {
    let notificationPreview: NotificationPreview
    let onTap: () -> Void
    
    private var notification: AppNotification {
        notificationPreview.notification
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .overlay(
                        Image(systemName: notification.type.iconName)
                            .foregroundColor(iconColor)
                            .font(.system(size: 16, weight: .medium))
                    )
                    .frame(width: 40, height: 40)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 16, weight: notification.isRead ? .medium : .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(notificationPreview.timeAgo)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Additional context for certain types
                    if let metadata = notification.metadata {
                        additionalContext(metadata)
                    }
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color(.systemBackground) : Color(.systemGray6).opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch notification.type.color {
        case "red": return .red
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        default: return .gray
        }
    }
    
    @ViewBuilder
    private func additionalContext(_ metadata: NotificationMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Post title context
            if let postTitle = metadata.postTitle, !postTitle.isEmpty {
                Text("in \"\(postTitle)\"")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(1)
            }
            
            // Comment preview for comment notifications
            if let commentText = metadata.commentText, !commentText.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                    
                    Text("\"\(commentText)\"")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.top, 2)
            }
            
            // Like count for milestone notifications
            if let likeCount = metadata.likeCount, likeCount > 0 {
                Text("\(likeCount) likes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
    }
}


// MARK: - Notification Filter
enum NotificationFilter: CaseIterable {
    case all
    case unread
    case likes
    case comments
    case messages
    
    var title: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        case .likes: return "Likes"
        case .comments: return "Comments"
        case .messages: return "Messages"
        }
    }
}

#Preview {
    NotificationView()
}
