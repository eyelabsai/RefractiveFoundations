import SwiftUI

// NotificationService is a Swift class, not a module - we'll use it directly

struct Main: View {
    
    @StateObject var data = GetData()
    @ObservedObject var firebaseManager = FirebaseManager.shared
    @ObservedObject var notificationService = NotificationService.shared
    
    @State var searchActivated = false
    @State var currentTab: Tab = .eyeReddit
    @State var searchBar = ""
    @State var resetEyeRedditToHome = false
    @State var navigationPath = NavigationPath()
    @Namespace var animation
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        ZStack {
            
            VStack(spacing: 0) {
                top
                
                switch currentTab {
                case .eyeReddit:
                    EyeReddit(data: data, resetToHome: $resetEyeRedditToHome, navigationPath: $navigationPath)
                case .notifications:
                    NotificationView()
                case .messages:
                    NavigationStack {
                        ConversationListView()
                    }
                case .newPost:
                    CreatePostView(data: data, tabBarIndex: Binding(
                        get: { currentTab == .eyeReddit ? 0 : 1 },
                        set: { newValue in
                            if newValue == 0 {
                                withAnimation {
                                    currentTab = .eyeReddit
                                    resetEyeRedditToHome = true
                                }
                            }
                        }
                    ))
                case .account:
                    ProfileView(data: data)
                }
                
                // Hide tab bar when creating a post for better UX
                if currentTab != .newPost {
                    bottomTabBar
                }
            }
        }
        .zIndex(0)
        .onAppear {
            startNotificationListening()
            setupPushNotifications()
        }
        .onChange(of: firebaseManager.currentUser?.uid) { newUID in
            // When user changes, cleanup old services and start new ones
            if let newUserID = newUID {
                print("🔄 User changed to \(newUserID)")
                notificationService.stopListening()
                DirectMessageService.shared.stopListeningToConversations()
                GroupChatService.shared.stopListeningToGroupChats()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startNotificationListening()
                }
            }
        }
        
        CustomLoading(handle: $data.handle)
            .zIndex(2)
        
        CustomAlert(handle: $data.handle)
            .zIndex(3)
    }
    
    var top: some View {
        HStack {
            // Home button always visible - takes you to main feed
            Button {
                withAnimation { 
                    // Clear any navigation stacks first
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast(navigationPath.count)
                    }
                    currentTab = .eyeReddit
                    resetEyeRedditToHome = true
                }
            } label: {
                Image(systemName: "homekit")
                    .imageScale(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 5)
            
            Spacer()
            
            Spacer()
            
                        // Notification button with badge (post notifications only)
            Button {
                withAnimation {
currentTab = .notifications
                }
            } label: {
                ZStack {
                    Image(systemName: "bell")
                        .imageScale(.medium)
                        .foregroundColor(.primary)
                    
                    if notificationService.notificationCounts.postNotificationsUnread > 0 {
                        Text("\(notificationService.notificationCounts.postNotificationsUnread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .padding(.trailing, 5)
            
            // DM button (Instagram-style message) with badge (DMs + group messages)
            Button {
                withAnimation {
                    currentTab = .messages
                }
            } label: {
                ZStack {
                    Image(systemName: "paperplane")
                        .imageScale(.medium)
                        .foregroundColor(.primary)
                    
                    if notificationService.unreadMessageCount > 0 {
                        Text("\(notificationService.unreadMessageCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .padding(.trailing, 5)
        }
        .padding(.horizontal)
        .frame(height: 44) // Fixed height to prevent layout shifts
        .overlay(
            // App Logo - overlaid in center without affecting layout, clickable link
            Link(destination: URL(string: "https://refractivefoundations.com/")!) {
                Image("RF Icon")
                    .renderingMode(colorScheme == .dark ? Image.TemplateRenderingMode.template : Image.TemplateRenderingMode.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 95, height: 95)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        )
    }
    
    var bottomTabBar: some View {
        HStack {
            Spacer()
            
            // Home/Feed Tab
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: currentTab == .eyeReddit,
                action: {
                    withAnimation {
                        if !navigationPath.isEmpty {
                            navigationPath.removeLast(navigationPath.count)
                        }
                        currentTab = .eyeReddit
                        resetEyeRedditToHome = true
                    }
                }
            )
            
            Spacer()
            
            // Notifications Tab - COMMENTED OUT
            /*
            TabBarButton(
                icon: "bell.fill",
                title: "Notifications",
                isSelected: currentTab == .notifications,
                action: {
                    withAnimation {
                        currentTab = .notifications
                    }
                }
            )
            */
            
            // New Post Tab (now centered)
            TabBarButton(
                icon: "plus",
                title: "New Post",
                isSelected: currentTab == .newPost,
                action: {
                    withAnimation {
                        currentTab = .newPost
                    }
                }
            )
            
            Spacer()
            
            // Profile Tab
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: currentTab == .account,
                action: {
                    withAnimation {
                        currentTab = .account
                    }
                }
            )
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
            , alignment: .top
        )
    }
    
    private func startNotificationListening() {
        guard let currentUserId = firebaseManager.currentUser?.uid else { return }
        
        // Start notification service
        notificationService.startListening(for: currentUserId)
        
        // Start message services for unread count tracking
        DirectMessageService.shared.startListeningToConversations(for: currentUserId)
        GroupChatService.shared.startListeningToGroupChats(for: currentUserId)
    }
    
    private func setupPushNotifications() {
        print("🔔 Setting up push notifications...")
        
        // Check if permission is already granted
        PushNotificationManager.shared.checkNotificationPermissionStatus()
        
        // Request permission if not already authorized
        if !PushNotificationManager.shared.isAuthorized {
            // Small delay to let the user see the main interface first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                PushNotificationManager.shared.requestNotificationPermission()
            }
        }
        
        // Get FCM token for this user
        PushNotificationManager.shared.getFCMToken()
        
        // Load notification preferences for current user
        if let userId = firebaseManager.currentUser?.uid {
            NotificationPreferencesManager.shared.loadPreferences(for: userId)
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
        .frame(minWidth: 60)
    }
}

// Simplified Tab Enum for Reddit-focused app
enum Tab {
    case eyeReddit
    case notifications
    case messages
    case newPost
    case account
}

// Note: AccountView replaced with ProfileView for Reddit-style experience