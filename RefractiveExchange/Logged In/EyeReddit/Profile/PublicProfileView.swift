//
//  PublicProfileView.swift
//  RefractiveFoundations
//
//  Reddit-style public profile view
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct PublicProfileView: View {
    let username: String
    let userId: String
    @ObservedObject var data: GetData
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PublicProfileViewModel()
    @State private var selectedTab = 0
    @State private var showingChatView = false
    @State private var otherUser: User?
    @State private var existingConversationId: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with dismiss button
                headerWithDismiss
                
                // Profile Header
                profileHeader
                
                // Tab Selector
                tabSelector
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Posts Tab
                    postsTab
                        .tag(0)
                    
                    // Comments Tab
                    commentsTab
                        .tag(1)
                    
                    // About Tab
                    aboutTab
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showingChatView) {
                if let otherUser = otherUser {
                    ChatView(
                        conversationId: existingConversationId, // Use existing conversation ID if found, empty string for new
                        otherUser: otherUser,
                        displayName: otherUser.exchangeUsername?.isEmpty == false ? otherUser.exchangeUsername! : "\(otherUser.firstName) \(otherUser.lastName)"
                    )
                }
            }
        }
        .onAppear {
            print("🔍 PublicProfileView appeared for user: \(username) with ID: \(userId)")
            viewModel.loadUserProfile(userId: userId)
            viewModel.loadUserPosts(userId: userId)
            viewModel.loadUserComments(userId: userId)
        }
    }
    
    // MARK: - Header with Dismiss
    private var headerWithDismiss: some View {
        HStack {
            Button("Done") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("Profile")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Invisible button for balance
            Button("Done") {
                // Empty action
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
            , alignment: .bottom
        )
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar and basic info
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 32))
                    )
                    .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("u/\(username)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if viewModel.isLoadingProfile {
                        Text("Loading...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Member since \(viewModel.memberSince)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Message button
                messageButton
            }
            .padding(.horizontal, 16)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Message Button
    private var messageButton: some View {
        Button(action: {
            startDirectMessage()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                    .font(.system(size: 14, weight: .medium))
                
                Text("Message")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(20)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(["Posts", "Comments", "About"], id: \.self) { tab in
                Button(action: {
                    withAnimation {
                        selectedTab = ["Posts", "Comments", "About"].firstIndex(of: tab) ?? 0
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTab == ["Posts", "Comments", "About"].firstIndex(of: tab) ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == ["Posts", "Comments", "About"].firstIndex(of: tab) ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
            , alignment: .bottom
        )
    }
    
    // MARK: - Posts Tab
    private var postsTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoadingPosts {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading posts...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if viewModel.posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No posts yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("This user hasn't made any posts yet.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(viewModel.posts) { post in
                        PostRow(
                            post: post,
                            onCommentTapped: {
                                // Navigate to post detail
                            },
                            onPostTapped: {
                                // Navigate to post detail
                            },
                            onUsernameTapped: { username, userId in
                                // Navigate to the tapped user's profile
                                // For now, we'll just dismiss and show the new profile
                                // In a more complex app, you might want to push to a new view
                            }
                        )
                        .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Comments Tab
    private var commentsTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoadingComments {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading comments...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if viewModel.comments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No comments yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("This user hasn't made any comments yet.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(
                            comment: comment,
                            onUsernameTapped: { username, userId in
                                // Navigate to the tapped user's profile
                                // For now, we'll just dismiss and show the new profile
                                // In a more complex app, you might want to push to a new view
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - About Tab
    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info
                VStack(alignment: .leading, spacing: 12) {
                    Text("User Information")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Username:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("u/\(username)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Member since:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            if viewModel.isLoadingProfile {
                                Text("Loading...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(viewModel.memberSince)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                        

                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Activity stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activity")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Posts:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            if viewModel.isLoadingPosts {
                                Text("Loading...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(viewModel.posts.count)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        HStack {
                            Text("Comments:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            if viewModel.isLoadingComments {
                                Text("Loading...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(viewModel.comments.count)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func startDirectMessage() {
        // First check for existing conversation with this user
        checkForExistingConversation { conversationId in
            DispatchQueue.main.async {
                self.existingConversationId = conversationId ?? ""
                
                // Get user data and show chat
                if let userData = self.getUserFromViewModelData() {
                    self.otherUser = userData
                    self.showingChatView = true
                } else {
                    self.fetchUserForDirectMessage()
                }
            }
        }
    }
    
    private func getUserFromViewModelData() -> User? {
        // If we have access to user data through other means, use it
        // For now, we'll fetch it fresh to ensure we have the latest data
        return nil
    }
    
    private func checkForExistingConversation(completion: @escaping (String?) -> Void) {
        guard let currentUserId = FirebaseManager.shared.currentUser?.uid else {
            print("❌ No current user found")
            completion(nil)
            return
        }
        
        print("🔍 Checking for existing conversation between \(currentUserId) and \(userId)")
        
        Firestore.firestore().collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error checking for existing conversation: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                // Check if any conversation contains both users (will restore if deleted)
                let existingConversation = snapshot?.documents.first { document in
                    let data = document.data()
                    guard let participants = data["participants"] as? [String] else { return false }
                    return participants.contains(self.userId) && participants.contains(currentUserId)
                }
                
                if let existing = existingConversation {
                    print("✅ Found existing active conversation: \(existing.documentID)")
                    completion(existing.documentID)
                } else {
                    print("💭 No existing active conversation found - will create new one")
                    completion(nil)
                }
            }
    }
    
    private func fetchUserForDirectMessage() {
        print("🔍 Fetching user data for DM: \(userId)")
        
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching user for DM: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("⚠️ User document not found for DM")
                    return
                }
                
                do {
                    let user = try document.data(as: User.self)
                    self.otherUser = user
                    self.showingChatView = true
                    print("✅ User data fetched for DM: \(user.firstName) \(user.lastName)")
                } catch {
                    print("❌ Error decoding user for DM: \(error)")
                }
            }
        }
    }
}

// MARK: - Public Profile View Model
class PublicProfileViewModel: ObservableObject {
    @Published var posts: [FetchedPost] = []
    @Published var comments: [Comment] = []
    @Published var memberSince = "Loading..."
    @Published var isLoadingProfile = true
    @Published var isLoadingPosts = true
    @Published var isLoadingComments = true
    
    func loadUserProfile(userId: String) {
        isLoadingProfile = true
        print("👤 Loading profile for user ID: \(userId)")
        
        Firestore.firestore().collection("users").document(userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoadingProfile = false
                
                if let error = error {
                    print("❌ Error loading user profile: \(error.localizedDescription)")
                    self?.memberSince = "Unknown"
                    return
                }
                
                if let document = document, document.exists {
                    print("📄 User document found, data: \(document.data() ?? [:])")
                    
                    do {
                        let user = try document.data(as: User.self)
                        print("✅ User decoded successfully: \(user.firstName) \(user.lastName)")
                        
                        if let dateJoined = user.dateJoined {
                            let date = dateJoined.dateValue()
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            self?.memberSince = formatter.string(from: date)
                            print("📅 Member since: \(self?.memberSince ?? "Unknown")")
                        } else {
                            // Fallback for users without dateJoined field - add it now
                            print("⚠️ No dateJoined field found, adding it...")
                            self?.addDateJoinedToUser(userId: userId)
                            self?.memberSince = "Member"
                        }
                    } catch {
                        print("❌ Error decoding user data: \(error)")
                        self?.memberSince = "Unknown"
                    }
                } else {
                    print("⚠️ User document not found for ID: \(userId)")
                    self?.memberSince = "Unknown"
                }
            }
        }
    }
    
    private func addDateJoinedToUser(userId: String) {
        // Add dateJoined field to existing user documents that don't have it
        Firestore.firestore().collection("users").document(userId).updateData([
            "dateJoined": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Error adding dateJoined field: \(error)")
            } else {
                print("✅ Added dateJoined field to user document")
                DispatchQueue.main.async {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    self.memberSince = formatter.string(from: Date())
                }
            }
        }
    }
    
    func loadUserPosts(userId: String) {
        isLoadingPosts = true
        print("📝 Loading posts for user: \(userId)")
        
        // Try the query with ordering first, but have a fallback
        self.loadUserPostsWithFallback(userId: userId)
    }
    
    private func loadUserPostsWithFallback(userId: String) {
        // First try with ordering (this might fail if index doesn't exist)
        Firestore.firestore().collection("posts")
            .whereField("uid", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                
                if let error = error {
                    print("⚠️ Query with ordering failed, trying fallback: \(error.localizedDescription)")
                    // Fallback: query without ordering
                    self?.loadUserPostsWithoutOrdering(userId: userId)
                    return
                }
                
                // Success with ordering
                DispatchQueue.main.async {
                    self?.processPostsResults(snapshot: snapshot, userId: userId, isFromFallback: false)
                }
            }
    }
    
    private func loadUserPostsWithoutOrdering(userId: String) {
        print("🔄 Loading posts without ordering (fallback)")
        Firestore.firestore().collection("posts")
            .whereField("uid", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Fallback query also failed: \(error.localizedDescription)")
                        self?.isLoadingPosts = false
                        self?.posts = []
                        return
                    }
                    
                    self?.processPostsResults(snapshot: snapshot, userId: userId, isFromFallback: true)
                }
            }
    }
    
    private func processPostsResults(snapshot: QuerySnapshot?, userId: String, isFromFallback: Bool) {
        self.isLoadingPosts = false
        
        if let documents = snapshot?.documents {
            print("📄 Found \(documents.count) posts for user \(userId) \(isFromFallback ? "(fallback)" : "")")
            
            let storedPosts = documents.compactMap { document in
                do {
                    let post = try document.data(as: StoredPost.self)
                    print("✅ Successfully decoded post: \(post.title)")
                    return post
                } catch {
                    print("❌ Failed to decode post \(document.documentID): \(error)")
                    return nil
                }
            }
            
            print("✅ Successfully decoded \(storedPosts.count) posts out of \(documents.count)")
            
            // Convert StoredPost to FetchedPost by fetching user details
            var fetchedPosts: [FetchedPost] = []
            let group = DispatchGroup()
            
            for storedPost in storedPosts {
                group.enter()
                self.fetchUserDetails(uid: storedPost.uid) { user in
                    let authorName: String
                    let avatarUrl: String?
                    
                    if let user = user {
                        if let username = user.exchangeUsername, !username.isEmpty {
                            authorName = username
                        } else {
                            authorName = "\(user.firstName) \(user.lastName)"
                        }
                        avatarUrl = user.avatarUrl
                    } else {
                        authorName = "Unknown User"
                        avatarUrl = nil
                    }
                    
                    let fetchedPost = FetchedPost(
                        id: storedPost.id,
                        title: storedPost.title,
                        text: storedPost.text,
                        timestamp: storedPost.timestamp,
                        upvotes: storedPost.upvotes,
                        downvotes: storedPost.downvotes ?? [],
                        subreddit: storedPost.subreddit,
                        imageURL: storedPost.imageURL,
                        didLike: storedPost.didLike,
                        didDislike: storedPost.didDislike ?? false,
                        author: authorName,
                        uid: storedPost.uid,
                        avatarUrl: avatarUrl
                    )
                    fetchedPosts.append(fetchedPost)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Sort by timestamp in memory (since we might not have been able to order in the query)
                self.posts = fetchedPosts.sorted(by: { $0.timestamp.dateValue() > $1.timestamp.dateValue() })
                print("🎯 Final posts count: \(self.posts.count)")
            }
        } else {
            print("📭 No posts found for user \(userId)")
            self.posts = []
        }
    }
    
    private func fetchUserDetails(uid: String, completion: @escaping(User?) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { documentSnapshot, error in
            if let error = error {
                print("❌ Error fetching user details: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = documentSnapshot else {
                print("❌ No document snapshot for UID: \(uid)")
                completion(nil)
                return
            }
            
            guard document.exists else {
                print("⚠️ User document doesn't exist for UID: \(uid)")
                completion(nil)
                return
            }
            
            do {
                let user = try document.data(as: User.self)
                completion(user)
            } catch {
                print("❌ Error decoding user data for UID \(uid): \(error)")
                completion(nil)
            }
        }
    }
    
    func loadUserComments(userId: String) {
        isLoadingComments = true
        print("💬 Loading comments for user: \(userId)")
        
        // Try the query with ordering first, but have a fallback
        self.loadUserCommentsWithFallback(userId: userId)
    }
    
    private func loadUserCommentsWithFallback(userId: String) {
        // First try with ordering (this might fail if index doesn't exist)
        Firestore.firestore().collection("comments")
            .whereField("uid", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                
                if let error = error {
                    print("⚠️ Comments query with ordering failed, trying fallback: \(error.localizedDescription)")
                    // Fallback: query without ordering
                    self?.loadUserCommentsWithoutOrdering(userId: userId)
                    return
                }
                
                // Success with ordering
                DispatchQueue.main.async {
                    self?.processCommentsResults(snapshot: snapshot, userId: userId, isFromFallback: false)
                }
            }
    }
    
    private func loadUserCommentsWithoutOrdering(userId: String) {
        print("🔄 Loading comments without ordering (fallback)")
        Firestore.firestore().collection("comments")
            .whereField("uid", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Fallback comments query also failed: \(error.localizedDescription)")
                        self?.isLoadingComments = false
                        self?.comments = []
                        return
                    }
                    
                    self?.processCommentsResults(snapshot: snapshot, userId: userId, isFromFallback: true)
                }
            }
    }
    
    private func processCommentsResults(snapshot: QuerySnapshot?, userId: String, isFromFallback: Bool) {
        self.isLoadingComments = false
        
        if let documents = snapshot?.documents {
            print("💭 Found \(documents.count) comments for user \(isFromFallback ? "(fallback)" : "")")
            
            let comments = documents.compactMap { document in
                try? document.data(as: Comment.self)
            }
            
            // Sort by timestamp in memory (since we might not have been able to order in the query)
            self.comments = comments.sorted(by: { $0.timestamp.dateValue() > $1.timestamp.dateValue() })
            
            print("✅ Successfully decoded \(self.comments.count) comments")
        } else {
            print("📭 No comments found for user")
            self.comments = []
        }
    }
}

#Preview {
    PublicProfileView(
        username: "SampleUser",
        userId: "sample_user_id",
        data: GetData()
    )
} 
