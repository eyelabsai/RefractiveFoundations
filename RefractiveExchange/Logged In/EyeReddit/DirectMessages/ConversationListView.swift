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
        NavigationView {
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
                NewMessageView(dmService: dmService)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force single column layout
        .onAppear {
            startListening()
        }
        .onDisappear {
            dmService.stopListeningToConversations()
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
            
            TextField("Search conversations", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
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
            if dmService.isLoadingConversations {
                loadingView
            } else if filteredConversations.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredConversations) { conversationPreview in
                        NavigationLink(destination: ChatView(
                            conversationId: conversationPreview.id,
                            otherUser: conversationPreview.otherUser,
                            displayName: conversationPreview.displayName
                        )) {
                            ConversationRowView(conversationPreview: conversationPreview)
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
}

// MARK: - Conversation Row View
struct ConversationRowView: View {
    let conversationPreview: ConversationPreview
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
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

// MARK: - New Message View
struct NewMessageView: View {
    @ObservedObject var dmService: DirectMessageService
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var messageText = ""
    @State private var isSearching = false
    @State private var searchResults: [User] = []
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
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
                            .onSubmit {
                                searchUsers()
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
                    searchResultsView
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
        .navigationViewStyle(StackNavigationViewStyle()) // Force single column layout
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
                    searchText = ""
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
    
    private func searchUsers() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        
        // Search users by username or name
        // This is a simple implementation - in production you might want more sophisticated search
        Firestore.firestore().collection("users")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let documents = snapshot?.documents {
                        let users = documents.compactMap { document -> User? in
                            try? document.data(as: User.self)
                        }.filter { user in
                            let searchLower = searchText.lowercased()
                            let fullName = "\(user.firstName) \(user.lastName)".lowercased()
                            
                            return fullName.contains(searchLower)
                        }
                        
                        searchResults = users
                    }
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