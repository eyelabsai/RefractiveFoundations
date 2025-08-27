//
//  ConversationListView.swift
//  RefractiveExchange
//
//  DM Conversations List View
//

import SwiftUI
import Firebase

struct ConversationListView: View {
    @ObservedObject var dmService = DirectMessageService.shared
    @ObservedObject var groupChatService = GroupChatService.shared
    @ObservedObject var firebaseManager = FirebaseManager.shared
    @State private var showingNewMessageSheet = false
    @State private var showingNewGroupSheet = false
    @State private var searchText = ""
    @State private var showingUserProfile = false
    @State private var selectedUser: User?
    @State private var isSearchingUsers = false
    @State private var userSearchResults: [User] = []
    @State private var userSearchTimer: Timer?
    @State private var allUsersCache: [User] = []
    @State private var lastUserCacheUpdate: Date?
    
    var filteredConversations: [ConversationPreview] {
        if searchText.isEmpty {
            return dmService.conversations
        } else {
            return dmService.conversations.filter { conversation in
                conversation.displayName.localizedCaseInsensitiveContains(searchText) ||
                conversation.conversation.lastMessage.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // Conversations list
            conversationsList
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingNewMessageSheet = true
                    }) {
                        Label("New Message", systemImage: "message")
                    }
                    
                    Button(action: {
                        showingNewGroupSheet = true
                    }) {
                        Label("New Group", systemImage: "person.3")
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $showingNewMessageSheet) {
            NewMessageView(dmService: dmService, preselectedUser: selectedUser)
                .onDisappear {
                    selectedUser = nil // Clear selected user when sheet disappears
                }
        }
        .sheet(isPresented: $showingNewGroupSheet) {
            CreateGroupChatView()
        }
        .sheet(isPresented: $showingUserProfile) {
            if let user = selectedUser {
                PublicProfileView(
                    username: user.exchangeUsername,
                    userId: user.uid,
                    data: GetData()
                )
            }
        }
        .onAppear {
            // Services are already started in Main.swift, no need to restart them here
            // Preload user cache for faster search
            fetchAndCacheUsers { _ in }
        }
        .onDisappear {
            // Don't stop DM/group chat listeners here - they should continue running 
            // in the background for unread count tracking and notifications
            userSearchTimer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Services are managed in Main.swift - no need to restart here
        }
        .onReceive(NotificationCenter.default.publisher(for: .conversationUpdated)) { _ in
            // Services are already listening - no need to restart
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search conversations and users", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _ in
                    scheduleUserSearch()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Conversations List
    private var conversationsList: some View {
        Group {
            if (dmService.isLoadingConversations || groupChatService.isLoadingGroupChats) || isSearchingUsers {
                loadingView
            } else if filteredConversations.isEmpty && groupChatService.groupChats.isEmpty && userSearchResults.isEmpty {
                emptyStateView
            } else {
                List {
                    // Show group chats and conversations in one simple list
                    ForEach(groupChatService.groupChats, id: \.id) { groupPreview in
                        NavigationLink(destination: GroupChatView(
                            groupChatId: groupPreview.id,
                            groupName: groupPreview.displayName
                        )) {
                            GroupChatRowView(groupPreview: groupPreview)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if groupPreview.groupChat.isOwner(firebaseManager.currentUser?.uid ?? "") {
                                Button(role: .destructive) {
                                    deleteGroupChat(groupPreview)
                                } label: {
                                    Label("Delete Group", systemImage: "trash")
                                }
                            } else {
                                Button("Leave") {
                                    leaveGroupChat(groupPreview)
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    
                    // Show existing conversations
                    ForEach(filteredConversations) { conversationPreview in
                        NavigationLink(destination: ChatView(
                            conversationId: conversationPreview.id,
                            otherUser: conversationPreview.otherUser,
                            displayName: conversationPreview.displayName
                        )) {
                            ConversationRowView(
                                conversationPreview: conversationPreview,
                                onUserAvatarTapped: { user in
                                    selectedUser = user
                                    showingUserProfile = true
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteConversation(conversationPreview)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    // Show user search results if we're searching and have results
                    if !searchText.isEmpty && !userSearchResults.isEmpty {
                        Section("Start New Conversation") {
                            ForEach(userSearchResults) { user in
                                Button(action: {
                                    // Start new conversation with this user
                                    startNewConversation(with: user)
                                }) {
                                    UserSearchRowView(user: user)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    // Manual refresh when user pulls down
                    startListening()
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading conversations...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No messages yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Start a conversation by tapping the compose button or visiting someone's profile")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                showingNewMessageSheet = true
            }) {
                Text("Start New Conversation")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func startListening() {
        guard let currentUserId = firebaseManager.currentUser?.uid else {
            print("❌ No current user found")
            return
        }
        
        dmService.startListeningToConversations(for: currentUserId)
        groupChatService.startListeningToGroupChats(for: currentUserId)
    }
    
    private func deleteConversation(_ conversationPreview: ConversationPreview) {
        guard let currentUserId = firebaseManager.currentUser?.uid else {
            print("❌ No current user found")
            return
        }
        
        print("🗑️ Deleting conversation \(conversationPreview.id) for user \(currentUserId)")
        
        dmService.deleteConversationForUser(conversationId: conversationPreview.id, userId: currentUserId) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Conversation deleted successfully")
                } else {
                    print("❌ Failed to delete conversation")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    private func deleteGroupChat(_ groupPreview: GroupChatPreview) {
        guard let currentUserId = firebaseManager.currentUser?.uid else {
            print("❌ No current user found")
            return
        }
        
        print("🗑️ Deleting group chat \(groupPreview.id)")
        
        groupChatService.deleteGroupChat(groupChatId: groupPreview.id, deletedBy: currentUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("✅ Group chat deleted successfully")
                case .failure(let error):
                    print("❌ Failed to delete group chat: \(error.localizedDescription)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    private func leaveGroupChat(_ groupPreview: GroupChatPreview) {
        guard let currentUserId = firebaseManager.currentUser?.uid else {
            print("❌ No current user found")
            return
        }
        
        print("🚪 Leaving group chat \(groupPreview.id)")
        
        groupChatService.leaveGroup(groupChatId: groupPreview.id, userId: currentUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("✅ Left group chat successfully")
                case .failure(let error):
                    print("❌ Failed to leave group chat: \(error.localizedDescription)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    // MARK: - User Search Functions
    
    /// Fetches and caches all users for efficient searching
    private func fetchAndCacheUsers(completion: @escaping ([User]) -> Void) {
        // Check if cache is still valid (refresh every 5 minutes)
        if let lastUpdate = lastUserCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < 300, // 5 minutes
           !allUsersCache.isEmpty {
            completion(allUsersCache)
            return
        }
        
        print("🔄 Refreshing user cache...")
        Firestore.firestore().collection("users")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error fetching users for cache: \(error.localizedDescription)")
                        completion(self.allUsersCache) // Return old cache if available
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No users found for cache")
                        completion([])
                        return
                    }
                    
                    let users = documents.compactMap { document -> User? in
                        try? document.data(as: User.self)
                    }
                    
                    self.allUsersCache = users
                    self.lastUserCacheUpdate = Date()
                    print("✅ User cache updated with \(users.count) users")
                    completion(users)
                }
            }
    }
    
    /// Schedules a user search with debouncing
    private func scheduleUserSearch() {
        userSearchTimer?.invalidate()
        
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userSearchResults = []
            isSearchingUsers = false
            return
        }
        
        userSearchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                self.searchForUsers()
            }
        }
    }
    
    /// Searches for users to start new conversations with
    private func searchForUsers() {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            userSearchResults = []
            isSearchingUsers = false
            return
        }
        
        // Don't search for users if we already have matching conversations
        guard filteredConversations.isEmpty else {
            userSearchResults = []
            isSearchingUsers = false
            return
        }
        
        isSearchingUsers = true
        let lowercaseSearch = trimmedSearch.lowercased()
        
        // Use cached users for faster search
        fetchAndCacheUsers { allUsers in
                    
                    // Filter users based on search criteria
                    let matchingUsers = allUsers.filter { user in
                        // Exclude current user
                        guard user.uid != self.firebaseManager.currentUser?.uid else { return false }
                        
                        let firstName = user.firstName.lowercased()
                        let lastName = user.lastName.lowercased()
                        let fullName = "\(user.firstName) \(user.lastName)".lowercased()
                        let username = user.exchangeUsername.lowercased()
                        let specialty = user.specialty.lowercased()
                        
                        // Check if search term matches any field
                        return firstName.contains(lowercaseSearch) ||
                               lastName.contains(lowercaseSearch) ||
                               fullName.contains(lowercaseSearch) ||
                               username.contains(lowercaseSearch) ||
                               specialty.contains(lowercaseSearch)
                    }
                    
                    // Sort by relevance and limit results for conversation list
                    let sortedUsers = matchingUsers.sorted { user1, user2 in
                        let fullName1 = "\(user1.firstName) \(user1.lastName)".lowercased()
                        let fullName2 = "\(user2.firstName) \(user2.lastName)".lowercased()
                        
                        // Exact matches first
                        if fullName1 == lowercaseSearch && fullName2 != lowercaseSearch { return true }
                        if fullName2 == lowercaseSearch && fullName1 != lowercaseSearch { return false }
                        
                        // Then prefix matches
                        if fullName1.hasPrefix(lowercaseSearch) && !fullName2.hasPrefix(lowercaseSearch) { return true }
                        if fullName2.hasPrefix(lowercaseSearch) && !fullName1.hasPrefix(lowercaseSearch) { return false }
                        
                        // Finally alphabetical
                        return fullName1 < fullName2
                    }
                    
            self.isSearchingUsers = false
            self.userSearchResults = Array(sortedUsers.prefix(5)) // Limit to 5 for conversation list
            print("✅ Conversation list search completed with \(self.userSearchResults.count) matching users")
        }
    }
    
    /// Starts a new conversation with the selected user
    private func startNewConversation(with user: User) {
        // Clear search to hide the user search results
        searchText = ""
        userSearchResults = []
        
        // Set the selected user and show the new message sheet
        selectedUser = user
        showingNewMessageSheet = true
    }
}

// MARK: - Group Chat Row View
struct GroupChatRowView: View {
    let groupPreview: GroupChatPreview
    
    var body: some View {
        HStack(spacing: 12) {
            // Group Avatar
            Circle()
                .fill(Color.green.opacity(0.2))
                .overlay(
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                )
                .frame(width: 50, height: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Group name and timestamp
                HStack {
                    Text(groupPreview.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(groupPreview.timeAgo)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                // Last message and member count
                HStack {
                    Text(groupPreview.lastMessagePreview)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Member count indicator
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("\(groupPreview.memberCount)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Unread count badge
            if groupPreview.unreadCount > 0 {
                VStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(groupPreview.unreadCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Conversation Row View
struct ConversationRowView: View {
    let conversationPreview: ConversationPreview
    let onUserAvatarTapped: (User) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar - Clickable
            Button(action: {
                if let otherUser = conversationPreview.otherUser {
                    onUserAvatarTapped(otherUser)
                }
            }) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Group {
                            if let avatarUrl = conversationPreview.displayAvatar,
                               !avatarUrl.isEmpty {
                                // Future: AsyncImage for avatar URLs
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            }
                        }
                    )
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Name and timestamp
                HStack {
                    Text(conversationPreview.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(conversationPreview.timeAgo)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                // Last message and unread indicator
                HStack {
                    Text(conversationPreview.conversation.lastMessage.isEmpty ? "No messages yet" : conversationPreview.conversation.lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(conversationPreview.conversation.lastMessage.isEmpty ? .secondary : .primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if conversationPreview.unreadCount > 0 {
                        Text("\(conversationPreview.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - User Search Row View
struct UserSearchRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.green.opacity(0.2))
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                )
                .frame(width: 50, height: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text("\(user.firstName) \(user.lastName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Username and specialty
                HStack {
                    Text("@\(user.exchangeUsername)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(user.specialty)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // New conversation indicator
            Image(systemName: "plus.bubble")
                .font(.system(size: 18))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - New Message View
struct NewMessageView: View {
    @ObservedObject var dmService: DirectMessageService
    let preselectedUser: User?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var messageText = ""
    @State private var isSearching = false
    @State private var searchResults: [User] = []
    @State private var isSending = false
    @State private var searchTimer: Timer?
    @State private var newMessageUsersCache: [User] = []
    @State private var lastNewMessageCacheUpdate: Date?
    
    init(dmService: DirectMessageService, preselectedUser: User? = nil) {
        self.dmService = dmService
        self.preselectedUser = preselectedUser
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search for users
                VStack(alignment: .leading, spacing: 8) {
                    Text("To:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search users...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { _ in
                                scheduleSearch()
                            }
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                
                // Selected user or search results
                if let selectedUser = selectedUser {
                    selectedUserView(selectedUser)
                } else if isSearching {
                    // Show loading view while searching
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.0)
                        
                        Text("Searching users...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !searchResults.isEmpty {
                    // Show search results when we have them
                    searchResultsView
                } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Show "no results" when search text exists but no results
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No users found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Try a different search term")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                }
                
                // Message input (only show if user is selected)
                if selectedUser != nil {
                    messageInputView
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if selectedUser != nil && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Send") {
                            sendMessage()
                        }
                        .disabled(isSending)
                    }
                }
            }
        }
        .onAppear {
            // Set preselected user if provided
            if let preselectedUser = preselectedUser {
                selectedUser = preselectedUser
                searchText = "\(preselectedUser.firstName) \(preselectedUser.lastName)"
            }
            // Preload user cache for faster search
            fetchNewMessageUsersCache { _ in }
        }
        .onDisappear {
            // Clean up the search timer when view disappears
            searchTimer?.invalidate()
        }
    }
    
    private func selectedUserView(_ user: User) -> some View {
        VStack {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    )
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(user.specialty)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Change") {
                    selectedUser = nil
                    // Don't clear search text - let user see their previous search results
                    // If they want to start fresh, they can clear the search field
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            Spacer()
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Debug header
                if !searchResults.isEmpty {
                    Text("Found \(searchResults.count) user(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                
                ForEach(searchResults) { user in
                    Button(action: {
                        selectedUser = user
                        searchText = "\(user.firstName) \(user.lastName)"
                        isSearching = false
                    }) {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16))
                                )
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(user.firstName) \(user.lastName)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(user.specialty)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
    }
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...6)
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Search Functions
    
    /// Schedules a search with debouncing to prevent excessive Firebase calls
    private func scheduleSearch() {
        // Cancel any existing timer
        searchTimer?.invalidate()
        
        // Clear results and stop searching if search text is empty
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            searchResults = []
            isSearching = false
            return
        }
        
        // Don't search if we already have a user selected
        if selectedUser != nil {
            return
        }
        
        // Set up new timer with 0.3 second delay (reduced for better responsiveness)
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                self.performSearch()
            }
        }
    }
    
    /// Performs immediate search (called when user presses enter)
    private func performSearch() {
        searchTimer?.invalidate()
        searchUsers()
    }
    
    /// Searches for users in Firebase with improved query logic
    private func searchUsers() {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        print("🔍 Searching for users with query: '\(trimmedSearch)'")
        
        // Search users with multiple strategies for better results
        searchUsersWithMultipleQueries(searchTerm: trimmedSearch)
    }
    
        /// Fetches and caches users for NewMessageView
    private func fetchNewMessageUsersCache(completion: @escaping ([User]) -> Void) {
        // Check if cache is still valid (refresh every 5 minutes)
        if let lastUpdate = lastNewMessageCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < 300, // 5 minutes
           !newMessageUsersCache.isEmpty {
            completion(newMessageUsersCache)
            return
        }
        
        print("🔄 Refreshing new message user cache...")
        Firestore.firestore().collection("users")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error fetching users for new message cache: \(error.localizedDescription)")
                        completion(self.newMessageUsersCache) // Return old cache if available
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No users found for new message cache")
                        completion([])
                        return
                    }
                    
                    let users = documents.compactMap { document -> User? in
                        try? document.data(as: User.self)
                    }
                    
                    self.newMessageUsersCache = users
                    self.lastNewMessageCacheUpdate = Date()
                    print("✅ New message user cache updated with \(users.count) users")
                    completion(users)
                }
            }
    }

    /// Performs comprehensive user search by fetching all users and filtering client-side
    private func searchUsersWithMultipleQueries(searchTerm: String) {
        let lowercaseSearch = searchTerm.lowercased()
        
        // Use cached users for faster search
        fetchNewMessageUsersCache { allUsers in
            DispatchQueue.main.async {
                self.isSearching = false
                
                print("🔍 Searching through \(allUsers.count) users for '\(searchTerm)'")
                    
                    // Filter users based on search criteria
                    let matchingUsers = allUsers.filter { user in
                        // Exclude current user from results
                        guard user.uid != FirebaseManager.shared.currentUser?.uid else { return false }
                        
                        let firstName = user.firstName.lowercased()
                        let lastName = user.lastName.lowercased()
                            let fullName = "\(user.firstName) \(user.lastName)".lowercased()
                        let exchangeUsername = user.exchangeUsername.lowercased()
                        let specialty = user.specialty.lowercased()
                        
                        // Check if search term matches any field
                        return firstName.contains(lowercaseSearch) ||
                               lastName.contains(lowercaseSearch) ||
                               fullName.contains(lowercaseSearch) ||
                               exchangeUsername.contains(lowercaseSearch) ||
                               specialty.contains(lowercaseSearch) ||
                               // Also check for exact word matches
                               firstName.components(separatedBy: .whitespacesAndNewlines).contains { $0 == lowercaseSearch } ||
                               lastName.components(separatedBy: .whitespacesAndNewlines).contains { $0 == lowercaseSearch } ||
                               specialty.components(separatedBy: .whitespacesAndNewlines).contains { $0 == lowercaseSearch }
                    }
                    
                    // Sort results by relevance
                    let sortedUsers = matchingUsers.sorted { user1, user2 in
                        let firstName1 = user1.firstName.lowercased()
                        let lastName1 = user1.lastName.lowercased()
                        let fullName1 = "\(user1.firstName) \(user1.lastName)".lowercased()
                        let username1 = user1.exchangeUsername.lowercased()
                        
                        let firstName2 = user2.firstName.lowercased()
                        let lastName2 = user2.lastName.lowercased()
                        let fullName2 = "\(user2.firstName) \(user2.lastName)".lowercased()
                        let username2 = user2.exchangeUsername.lowercased()
                        
                        // Priority 1: Exact full name match
                        if fullName1 == lowercaseSearch && fullName2 != lowercaseSearch { return true }
                        if fullName2 == lowercaseSearch && fullName1 != lowercaseSearch { return false }
                        
                        // Priority 2: Exact first name match
                        if firstName1 == lowercaseSearch && firstName2 != lowercaseSearch { return true }
                        if firstName2 == lowercaseSearch && firstName1 != lowercaseSearch { return false }
                        
                        // Priority 3: Exact last name match
                        if lastName1 == lowercaseSearch && lastName2 != lowercaseSearch { return true }
                        if lastName2 == lowercaseSearch && lastName1 != lowercaseSearch { return false }
                        
                        // Priority 4: Exact username match
                        if username1 == lowercaseSearch && username2 != lowercaseSearch { return true }
                        if username2 == lowercaseSearch && username1 != lowercaseSearch { return false }
                        
                        // Priority 5: First name starts with search
                        if firstName1.hasPrefix(lowercaseSearch) && !firstName2.hasPrefix(lowercaseSearch) { return true }
                        if firstName2.hasPrefix(lowercaseSearch) && !firstName1.hasPrefix(lowercaseSearch) { return false }
                        
                        // Priority 6: Last name starts with search
                        if lastName1.hasPrefix(lowercaseSearch) && !lastName2.hasPrefix(lowercaseSearch) { return true }
                        if lastName2.hasPrefix(lowercaseSearch) && !lastName1.hasPrefix(lowercaseSearch) { return false }
                        
                        // Priority 7: Full name starts with search
                        if fullName1.hasPrefix(lowercaseSearch) && !fullName2.hasPrefix(lowercaseSearch) { return true }
                        if fullName2.hasPrefix(lowercaseSearch) && !fullName1.hasPrefix(lowercaseSearch) { return false }
                        
                        // Priority 8: Username starts with search
                        if username1.hasPrefix(lowercaseSearch) && !username2.hasPrefix(lowercaseSearch) { return true }
                        if username2.hasPrefix(lowercaseSearch) && !username1.hasPrefix(lowercaseSearch) { return false }
                        
                        // Final sort: Alphabetically by full name
                        return fullName1 < fullName2
                    }
                    
                self.searchResults = Array(sortedUsers.prefix(50)) // Show up to 50 results
                print("✅ Search completed with \(self.searchResults.count) matching users")
                print("🔍 Search results: \(self.searchResults.map { "\($0.firstName) \($0.lastName)" }.joined(separator: ", "))")
                print("🔍 selectedUser is nil: \(self.selectedUser == nil)")
                print("🔍 isSearching: \(self.isSearching)")
                print("🔍 searchText: '\(self.searchText)'")
            }
        }
    }
    
    private func sendMessage() {
        guard let user = selectedUser,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let recipientId = user.uid
        isSending = true
        
        dmService.sendMessage(to: recipientId, text: messageText) { result in
            DispatchQueue.main.async {
                isSending = false
                
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    print("❌ Error sending message: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
}

// MARK: - Group Chat View
struct GroupChatView: View {
    let groupChatId: String
    let groupName: String
    
    @ObservedObject private var groupChatService = GroupChatService.shared
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var messages: [GroupMessage] = []
    @State private var messageText = ""
    @State private var messageListener: ListenerRegistration?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var showingGroupInfo = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesScrollView
            
            // Message input
            messageInputView
        }
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingGroupInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            GroupInfoView(groupChatId: groupChatId)
        }
        .onAppear {
            startListeningToMessages()
            markMessagesAsRead()
        }
        .onDisappear {
            stopListening()
        }
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isLoading {
                        loadingView
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            GroupMessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == firebaseManager.currentUser?.uid
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messages.count) { _ in
                // Auto-scroll to bottom when new messages arrive
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading messages...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.green.opacity(0.2))
                .overlay(
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 32))
                )
                .frame(width: 80, height: 80)
            
            VStack(spacing: 8) {
                Text("Welcome to \(groupName)!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Start the conversation with your group")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 50)
    }
    
    // MARK: - Message Input View
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(22)
                    .lineLimit(1...6)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green)
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Methods
    private func startListeningToMessages() {
        guard !groupChatId.isEmpty else {
            print("❌ No group chat ID provided")
            return
        }
        
        messageListener = groupChatService.listenToGroupMessages(groupChatId: groupChatId) { fetchedMessages in
            DispatchQueue.main.async {
                self.messages = fetchedMessages
                self.isLoading = false
                
                if !fetchedMessages.isEmpty {
                    self.markMessagesAsRead()
                }
            }
        }
    }
    
    private func stopListening() {
        messageListener?.remove()
        messageListener = nil
    }
    
    private func sendMessage() {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        
        groupChatService.sendGroupMessage(
            groupChatId: groupChatId,
            text: trimmedMessage,
            senderId: currentUserId
        ) { result in
            DispatchQueue.main.async {
                self.isSending = false
                
                switch result {
                case .success:
                    self.messageText = ""
                case .failure(let error):
                    print("❌ Error sending group message: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func markMessagesAsRead() {
        guard let currentUserId = firebaseManager.currentUser?.uid else { return }
        
        groupChatService.markGroupMessagesAsRead(
            groupChatId: groupChatId,
            userId: currentUserId
        ) { success in
            if success {
                print("✅ Group messages marked as read")
            }
        }
    }
}

// MARK: - Group Message Bubble View
struct GroupMessageBubbleView: View {
    let message: GroupMessage
    let isFromCurrentUser: Bool
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        let now = Date()
        let messageDate = message.timestamp.dateValue()
        
        if Calendar.current.isDate(messageDate, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: messageDate)
    }
    
    var body: some View {
        if message.isSystemMessage {
            // System message
            HStack {
                Spacer()
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            // Regular message
            HStack {
                if isFromCurrentUser {
                    Spacer(minLength: 50)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(message.text)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                        
                        Text(formattedTime)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.senderName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.leading, 4)
                            
                            Text(message.text)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                        }
                        
                        Text(formattedTime)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
}

// MARK: - Create Group Chat View
struct CreateGroupChatView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var groupChatService = GroupChatService.shared
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedMembers: [User] = []
    @State private var isCreating = false
    @State private var showingUserPicker = false
    @State private var isPrivate = true
    @State private var maxMembers = 50
    @State private var allUsersCache: [User] = []
    @State private var searchText = ""
    
    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return allUsersCache.filter { user in
                user.uid != firebaseManager.currentUser?.uid && 
                !selectedMembers.contains { $0.uid == user.uid }
            }
        } else {
            let searchLower = searchText.lowercased()
            return allUsersCache.filter { user in
                let fullName = "\(user.firstName) \(user.lastName)".lowercased()
                let username = user.exchangeUsername.lowercased()
                
                return (fullName.contains(searchLower) || username.contains(searchLower)) &&
                       user.uid != firebaseManager.currentUser?.uid && 
                       !selectedMembers.contains { $0.uid == user.uid }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Group name", text: $groupName)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    TextField("Description (optional)", text: $groupDescription, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section("Privacy & Settings") {
                    Toggle("Private Group", isOn: $isPrivate)
                    
                    HStack {
                        Text("Max Members")
                        Spacer()
                        Picker("Max Members", selection: $maxMembers) {
                            Text("10").tag(10)
                            Text("25").tag(25)
                            Text("50").tag(50)
                            Text("100").tag(100)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section("Members (\(selectedMembers.count))") {
                    if selectedMembers.isEmpty {
                        Text("No members selected")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(selectedMembers) { member in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 14))
                                    )
                                    .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(member.firstName) \(member.lastName)")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text(member.specialty)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Remove") {
                                    selectedMembers.removeAll { $0.uid == member.uid }
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button("Add Members") {
                        showingUserPicker = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingUserPicker) {
                userPickerView
            }
            .onAppear {
                fetchUsers()
            }
        }
    }
    
    private var userPickerView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Users list
                List {
                    ForEach(filteredUsers) { user in
                        Button(action: {
                            if !selectedMembers.contains(where: { $0.uid == user.uid }) {
                                selectedMembers.append(user)
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                    )
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(user.firstName) \(user.lastName)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(user.specialty)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedMembers.contains(where: { $0.uid == user.uid }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingUserPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func fetchUsers() {
        Firestore.firestore().collection("users")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let documents = snapshot?.documents {
                        self.allUsersCache = documents.compactMap { try? $0.data(as: User.self) }
                    }
                }
            }
    }
    
    private func createGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isCreating = true
        
        let memberIds = selectedMembers.map { $0.uid }
        
        groupChatService.createGroupChat(
            name: trimmedName,
            description: groupDescription.isEmpty ? nil : groupDescription,
            memberIds: memberIds,
            isPrivate: isPrivate,
            maxMembers: maxMembers
        ) { result in
            DispatchQueue.main.async {
                self.isCreating = false
                
                switch result {
                case .success(let groupId):
                    print("✅ Group created with ID: \(groupId)")
                    self.dismiss()
                case .failure(let error):
                    print("❌ Error creating group: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
}

// MARK: - Group Info View
struct GroupInfoView: View {
    let groupChatId: String
    
    @ObservedObject private var groupChatService = GroupChatService.shared
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var groupChat: GroupChat?
    @State private var memberDetails: [User] = []
    @State private var ownerDetails: User?
    @State private var isLoading = true
    @State private var showingAddMembers = false
    @State private var showingLeaveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var allUsersCache: [User] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading group info...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let groupChat = groupChat {
                    groupInfoContent(groupChat: groupChat)
                } else {
                    Text("Group not found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMembers) {
            AddMembersView(groupChatId: groupChatId, currentMembers: memberDetails)
        }
        .alert("Leave Group", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                leaveGroup()
            }
        } message: {
            Text("Are you sure you want to leave this group? You won't be able to see future messages.")
        }
        .alert("Delete Group", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGroup()
            }
        } message: {
            Text("Are you sure you want to delete this group? This action cannot be undone.")
        }
        .onAppear {
            loadGroupInfo()
        }
    }
    
    private func groupInfoContent(groupChat: GroupChat) -> some View {
        List {
            // Group Header Section
            Section {
                VStack(spacing: 16) {
                    // Group Avatar
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 32))
                        )
                        .frame(width: 80, height: 80)
                    
                    VStack(spacing: 4) {
                        Text(groupChat.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let description = groupChat.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("\(groupChat.allMemberIds.count) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Members Section - Always show all members
            Section("Members (\(groupChat.allMemberIds.count))") {
                ForEach(groupChat.allMemberIds, id: \.self) { memberId in
                    HStack(spacing: 12) {
                        Circle()
                            .fill((memberId == groupChat.ownerId ? Color.blue : Color.gray).opacity(0.2))
                            .overlay(
                                Image(systemName: memberId == groupChat.ownerId ? "crown.fill" : "person.fill")
                                    .foregroundColor(memberId == groupChat.ownerId ? .blue : .gray)
                                    .font(.system(size: 16))
                            )
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                // Try to get user details, fallback to member ID if not available
                                if let user = getUserDetails(for: memberId) {
                                    Text("\(user.firstName) \(user.lastName)")
                                        .font(.system(size: 16, weight: .medium))
                                } else {
                                    Text("Loading user...")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                if memberId == firebaseManager.currentUser?.uid {
                                    Text("(You)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Show role and specialty
                            if let user = getUserDetails(for: memberId) {
                                Text((memberId == groupChat.ownerId ? "Owner • " : "") + user.specialty)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(memberId == groupChat.ownerId ? "Owner" : "Member")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Show admin badge if applicable
                        if groupChat.adminIds.contains(memberId) {
                            Text("Admin")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        // Show remove option if current user can manage and this isn't the owner
                        if groupChat.canManage(firebaseManager.currentUser?.uid ?? "") && 
                           !groupChat.isOwner(memberId) &&
                           memberId != firebaseManager.currentUser?.uid {
                            Button(action: {
                                removeMemberById(memberId)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Add Members Button (if user can manage and group isn't full)
                if groupChat.canManage(firebaseManager.currentUser?.uid ?? "") && !groupChat.isAtCapacity {
                    Button(action: {
                        showingAddMembers = true
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .bold))
                                )
                                .frame(width: 40, height: 40)
                            
                            Text("Add Members")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Group Settings Section
            Section("Group Settings") {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    Text("Privacy")
                    
                    Spacer()
                    
                    Text(groupChat.isPrivate ? "Private" : "Public")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    Text("Max Members")
                    
                    Spacer()
                    
                    Text("\(groupChat.maxMembers)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    Text("Created")
                    
                    Spacer()
                    
                    Text(formatDate(groupChat.createdAt.dateValue()))
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions Section
            Section {
                if groupChat.isOwner(firebaseManager.currentUser?.uid ?? "") {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .frame(width: 20)
                            Text("Delete Group")
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Button(action: {
                        showingLeaveConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 20)
                            Text("Leave Group")
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
        }
    }
    
    private func loadGroupInfo() {
        guard let group = groupChatService.groupChats.first(where: { $0.id == groupChatId })?.groupChat else {
            isLoading = false
            return
        }
        
        self.groupChat = group
        
        // Fetch owner details
        fetchUserDetails(uid: group.ownerId) { user in
            DispatchQueue.main.async {
                self.ownerDetails = user
            }
        }
        
        // Fetch member details (excluding owner to avoid duplication)
        let memberUids = group.memberIds.filter { $0 != group.ownerId }
        fetchMultipleUserDetails(uids: memberUids) { users in
            DispatchQueue.main.async {
                self.memberDetails = users
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserDetails(uid: String, completion: @escaping (User?) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching user details: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = snapshot, document.exists, let data = document.data() else {
                print("❌ User document does not exist for UID: \(uid)")
                completion(nil)
                return
            }
            
            do {
                let user = try document.data(as: User.self)
                completion(user)
            } catch {
                print("❌ Error decoding user \(uid): \(error)")
                // Try manual decoding as fallback
                if let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String,
                   let specialty = data["specialty"] as? String,
                   let email = data["email"] as? String {
                    let fallbackUser = User(
                        credential: data["credential"] as? String ?? "",
                        email: email,
                        firstName: firstName,
                        lastName: lastName,
                        position: data["position"] as? String ?? "",
                        specialty: specialty,
                        state: data["state"] as? String ?? "",
                        suffix: data["suffix"] as? String ?? "",
                        uid: uid,
                        exchangeUsername: data["exchangeUsername"] as? String ?? ""
                    )
                    print("✅ Using fallback decoding for user \(firstName) \(lastName)")
                    completion(fallbackUser)
                } else {
                    print("❌ Fallback decoding failed for user \(uid)")
                    completion(nil)
                }
            }
        }
    }
    
    private func fetchMultipleUserDetails(uids: [String], completion: @escaping ([User]) -> Void) {
        guard !uids.isEmpty else {
            completion([])
            return
        }
        
        let db = Firestore.firestore()
        let group = DispatchGroup()
        var users: [User] = []
        
        for uid in uids {
            group.enter()
            
            db.collection("users").document(uid).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error fetching user details for \(uid): \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else { return }
                
                do {
                    let user = try snapshot?.data(as: User.self)
                    if let user = user {
                        users.append(user)
                    }
                } catch {
                    print("❌ Error decoding user \(uid): \(error)")
                    // Try manual decoding as fallback
                    if let firstName = data["firstName"] as? String,
                       let lastName = data["lastName"] as? String,
                       let specialty = data["specialty"] as? String,
                       let email = data["email"] as? String {
                        let fallbackUser = User(
                            credential: data["credential"] as? String ?? "",
                            email: email,
                            firstName: firstName,
                            lastName: lastName,
                            position: data["position"] as? String ?? "",
                            specialty: specialty,
                            state: data["state"] as? String ?? "",
                            suffix: data["suffix"] as? String ?? "",
                            uid: uid,
                            exchangeUsername: data["exchangeUsername"] as? String ?? ""
                        )
                        print("✅ Using fallback decoding for user \(firstName) \(lastName)")
                        users.append(fallbackUser)
                    } else {
                        print("❌ Fallback decoding failed for user \(uid)")
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(users.sorted { $0.firstName < $1.firstName })
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func getUserDetails(for uid: String) -> User? {
        // First check if it's the owner
        if uid == groupChat?.ownerId {
            return ownerDetails
        }
        // Then check in member details
        return memberDetails.first { $0.uid == uid }
    }
    
    private func removeMemberById(_ memberId: String) {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let groupId = groupChat?.id else { return }
        
        groupChatService.removeMember(
            groupChatId: groupId,
            memberId: memberId,
            removedBy: currentUserId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Update local group chat data immediately for UI responsiveness
                    if var updatedGroupChat = self.groupChat {
                        updatedGroupChat.memberIds.removeAll { $0 == memberId }
                        updatedGroupChat.adminIds.removeAll { $0 == memberId }
                        self.groupChat = updatedGroupChat
                    }
                    // Also remove from member details
                    self.memberDetails.removeAll { $0.uid == memberId }
                    print("✅ Member removed successfully")
                case .failure(let error):
                    print("❌ Error removing member: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func removeMember(_ member: User) {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let groupId = groupChat?.id else { return }
        
        groupChatService.removeMember(
            groupChatId: groupId,
            memberId: member.uid,
            removedBy: currentUserId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local list immediately for UI responsiveness
                    self.memberDetails.removeAll { $0.uid == member.uid }
                    print("✅ Member removed successfully")
                case .failure(let error):
                    print("❌ Error removing member: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func leaveGroup() {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let groupId = groupChat?.id else { return }
        
        groupChatService.leaveGroup(
            groupChatId: groupId,
            userId: currentUserId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Left group successfully")
                    self.dismiss()
                case .failure(let error):
                    print("❌ Error leaving group: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func deleteGroup() {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let groupId = groupChat?.id else { return }
        
        groupChatService.deleteGroupChat(
            groupChatId: groupId,
            deletedBy: currentUserId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Group deleted successfully")
                    self.dismiss()
                case .failure(let error):
                    print("❌ Error deleting group: \(error)")
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func deleteGroupFromInfo(_ groupChat: GroupChat) {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let groupId = groupChat.id else {
            print("❌ No current user or group ID found")
            return
        }
        
        print("🗑️ Deleting group chat \(groupId) from info view")
        
        groupChatService.deleteGroupChat(groupChatId: groupId, deletedBy: currentUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("✅ Group chat deleted successfully")
                    self.dismiss()
                case .failure(let error):
                    print("❌ Failed to delete group chat: \(error.localizedDescription)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    private func leaveGroupFromInfo(_ groupChat: GroupChat) {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let groupId = groupChat.id else {
            print("❌ No current user or group ID found")
            return
        }
        
        print("🚪 Leaving group chat \(groupId) from info view")
        
        groupChatService.leaveGroup(groupChatId: groupId, userId: currentUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("✅ Left group chat successfully")
                    self.dismiss()
                case .failure(let error):
                    print("❌ Failed to leave group chat: \(error.localizedDescription)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
}

// MARK: - Add Members View
struct AddMembersView: View {
    let groupChatId: String
    let currentMembers: [User]
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var groupChatService = GroupChatService.shared
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    
    @State private var allUsers: [User] = []
    @State private var selectedUsers: Set<String> = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isAddingMembers = false
    
    private var availableUsers: [User] {
        let currentMemberIds = Set(currentMembers.map { $0.uid })
        let currentUserId = firebaseManager.currentUser?.uid ?? ""
        
        let filteredUsers = allUsers.filter { user in
            !currentMemberIds.contains(user.uid) && user.uid != currentUserId
        }
        
        if searchText.isEmpty {
            return filteredUsers
        } else {
            let searchLower = searchText.lowercased()
            return filteredUsers.filter { user in
                let fullName = "\(user.firstName) \(user.lastName)".lowercased()
                let username = user.exchangeUsername.lowercased()
                return fullName.contains(searchLower) || username.contains(searchLower)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Search bar
                    UserSearchBar(text: $searchText, placeholder: "Search users...")
                        .padding(.horizontal)
                    
                    // Selected users preview
                    if !selectedUsers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedUsers), id: \.self) { userId in
                                    if let user = allUsers.first(where: { $0.uid == userId }) {
                                        SelectedUserChip(user: user) {
                                            selectedUsers.remove(userId)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Available users list
                    List(availableUsers, id: \.uid) { user in
                        UserSelectionRow(
                            user: user,
                            isSelected: selectedUsers.contains(user.uid)
                        ) {
                            if selectedUsers.contains(user.uid) {
                                selectedUsers.remove(user.uid)
                            } else {
                                selectedUsers.insert(user.uid)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSelectedMembers()
                    }
                    .disabled(selectedUsers.isEmpty || isAddingMembers)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadUsers()
        }
    }
    
    private func loadUsers() {
        Firestore.firestore().collection("users")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("❌ Error loading users: \(error)")
                        return
                    }
                    
                    if let documents = snapshot?.documents {
                        self.allUsers = documents.compactMap { document in
                            try? document.data(as: User.self)
                        }
                    }
                }
            }
    }
    
    private func addSelectedMembers() {
        guard !selectedUsers.isEmpty,
              let currentUserId = firebaseManager.currentUser?.uid else { return }
        
        isAddingMembers = true
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for userId in selectedUsers {
            group.enter()
            
            groupChatService.addMember(
                groupChatId: groupChatId,
                memberId: userId,
                addedBy: currentUserId
            ) { result in
                if case .failure(let error) = result {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isAddingMembers = false
            
            if errors.isEmpty {
                print("✅ All members added successfully")
                self.dismiss()
            } else {
                print("❌ Some errors occurred while adding members: \(errors)")
                // TODO: Show partial success/error alert
                if errors.count < selectedUsers.count {
                    // Some succeeded, still dismiss but maybe show warning
                    self.dismiss()
                }
            }
        }
    }
}

// MARK: - Supporting Views for Add Members
struct SelectedUserChip: View {
    let user: User
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(user.firstName) \(user.lastName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue)
        .clipShape(Capsule())
    }
}

struct UserSelectionRow: View {
    let user: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    )
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(user.specialty)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UserSearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ConversationListView()
} 