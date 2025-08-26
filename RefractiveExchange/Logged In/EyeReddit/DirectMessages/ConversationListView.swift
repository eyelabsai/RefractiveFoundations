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
    @ObservedObject var firebaseManager = FirebaseManager.shared
    @State private var showingNewMessageSheet = false
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
                Button(action: {
                    showingNewMessageSheet = true
                }) {
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
            startListening()
            // Preload user cache for faster search
            fetchAndCacheUsers { _ in }
        }
        .onDisappear {
            dmService.stopListeningToConversations()
            userSearchTimer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh conversations when app comes to foreground
            startListening()
        }
        .onReceive(NotificationCenter.default.publisher(for: .conversationUpdated)) { _ in
            // Refresh conversations when a new message is sent
            startListening()
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
            if dmService.isLoadingConversations || isSearchingUsers {
                loadingView
            } else if filteredConversations.isEmpty && userSearchResults.isEmpty {
                emptyStateView
            } else {
                List {
                    // Show existing conversations
                    if !filteredConversations.isEmpty {
                        Section("Conversations") {
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

#Preview {
    ConversationListView()
} 