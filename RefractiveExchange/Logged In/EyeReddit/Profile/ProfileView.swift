//
//  ProfileView.swift
//  RefractiveExchange
//
//  Reddit-style profile view
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @ObservedObject var data: GetData
    @EnvironmentObject var darkModeManager: DarkModeManager
    @State private var selectedTab = 0
    @State private var userPosts: [FetchedPost] = []
    @State private var userComments: [Comment] = []
    @State private var savedPosts: [FetchedPost] = []
    @State private var isLoading = true
    @State private var karma: Int = 0
    
    let tabTitles = ["Posts", "Comments", "Saved"]
    let service = PostService()
    let saveService = SaveService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Profile Header - Reddit Style
                profileHeader
                
                // Tab Bar
                tabBar
                
                // Content
                TabView(selection: $selectedTab) {
                    // Posts Tab
                    postsView
                        .tag(0)
                    
                    // Comments Tab  
                    commentsView
                        .tag(1)
                    
                    // Saved Tab
                    savedView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .onAppear {
                print("🎬 ProfileView appeared")
                print("👤 Current user data: \(data.user?.firstName ?? "nil") \(data.user?.lastName ?? "nil")")
                print("🔐 Auth UID: \(Auth.auth().currentUser?.uid ?? "nil")")
                
                // Check if user needs migration (missing user document)
                if data.user == nil && Auth.auth().currentUser != nil {
                    print("🚨 User authenticated but no user document found - attempting migration")
                    FirebaseManager.shared.createMissingUserDocument { success in
                        if success {
                            print("✅ Migration successful, reloading user data")
                            DispatchQueue.main.async {
                                self.data.fetchUser()
                                self.loadUserData()
                            }
                        }
                    }
                } else {
                    loadUserData()
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Avatar
                if let user = data.user, let avatarUrlString = user.avatarUrl, let url = URL(string: avatarUrlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                        )
                        .frame(width: 80, height: 80)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Username
                    if let user = data.user {
                        if let username = user.exchangeUsername, !username.isEmpty {
                            Text("u/\(username)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            Text("u/\(user.firstName.lowercased())\(user.lastName.lowercased())")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        // Real name
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        // Karma and join date
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("\(karma) karma")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("• Member since 2024")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        // Specialty badge
                        Text(user.specialty)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    // Dark Mode Toggle
                    Button(action: {
                        darkModeManager.toggleDarkMode()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: darkModeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 14))
                            Text(darkModeManager.isDarkMode ? "Light Mode" : "Dark Mode")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(darkModeManager.isDarkMode ? .yellow : .purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(darkModeManager.isDarkMode ? Color.purple.opacity(0.1) : Color.yellow.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    // Edit button
                    Button("Edit") {
                        // TODO: Navigate to edit profile
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    
                    // Sign Out button
                    Button("Sign Out") {
                        FirebaseManager.shared.signOut()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            
            // Stats Row
            HStack(spacing: 0) {
                statItem(title: "Posts", count: userPosts.count)
                statItem(title: "Comments", count: userComments.count)
                statItem(title: "Saved", count: savedPosts.count)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabTitles.count, id: \.self) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 8) {
                        Text(tabTitles[index])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == index ? .blue : .secondary)
                        
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == index ? .blue : .clear)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
            , alignment: .bottom
        )
    }
    
    // MARK: - Posts View
    private var postsView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if isLoading {
                    loadingView
                } else if userPosts.isEmpty {
                    emptyState(message: "No posts yet", icon: "doc.text")
                } else {
                    ForEach(userPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post, data: data)
                        } label: {
                            PostRow(post: post)
                                .background(Color(.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Comments View
    private var commentsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if isLoading {
                    loadingView
                } else if userComments.isEmpty {
                    emptyState(message: "No comments yet", icon: "bubble.left")
                } else {
                    ForEach(userComments, id: \.timestamp) { comment in
                        commentCard(comment)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Saved View
    private var savedView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if isLoading {
                    loadingView
                } else if savedPosts.isEmpty {
                    emptyState(message: "No saved posts", icon: "bookmark")
                } else {
                    ForEach(savedPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post, data: data)
                        } label: {
                            PostRow(post: post)
                                .background(Color(.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Views
    private func statItem(title: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func commentCard(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Comment")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(timeAgoString(from: comment.timestamp.dateValue()))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text(comment.text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Post context
            Text("on post: \(comment.postId)")
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .padding(.top, 4)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Data Loading
    private func loadUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ No authenticated user found")
            isLoading = false
            return 
        }
        
        print("🔄 Loading profile data for user: \(uid)")
        isLoading = true
        let group = DispatchGroup()
        
        // Load user posts
        group.enter()
        print("📥 Loading user posts...")
        service.fetchPosts(uid: uid) { posts in
            print("✅ Loaded \(posts.count) user posts")
            DispatchQueue.main.async {
                self.userPosts = posts
                self.calculateKarma()
                group.leave()
            }
        }
        
        // Load user comments
        group.enter()
        print("📥 Loading user comments...")
        loadUserComments(uid: uid) {
            group.leave()
        }
        
        // Load saved posts
        group.enter()
        print("📥 Loading saved posts...")
        saveService.getSavedPosts { posts in
            print("✅ Loaded \(posts.count) saved posts")
            DispatchQueue.main.async {
                self.savedPosts = posts
                group.leave()
            }
        }
        
        // Add timeout to prevent infinite loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isLoading {
                print("⚠️ Profile loading timeout - setting loading to false")
                self.isLoading = false
            }
        }
        
        group.notify(queue: .main) {
            print("✅ All profile data loaded successfully")
            self.isLoading = false
        }
    }
    
    private func loadUserComments(uid: String, completion: @escaping () -> Void) {
        guard let currentUser = data.user else {
            print("⚠️ No user data available for comments loading")
            DispatchQueue.main.async {
                completion()
            }
            return
        }
        
        let authorName = currentUser.exchangeUsername?.isEmpty == false ? currentUser.exchangeUsername! : "\(currentUser.firstName) \(currentUser.lastName)"
        print("🔍 Looking for comments by author: \(authorName)")
        
        Firestore.firestore().collection("comments")
            .whereField("author", isEqualTo: authorName)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading comments: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion()
                    }
                    return
                }
                
                if let documents = snapshot?.documents {
                    print("📥 Found \(documents.count) comments for user")
                    let comments = documents.compactMap { doc -> Comment? in
                        let data = doc.data()
                        guard let postId = data["postId"] as? String,
                              let text = data["text"] as? String,
                              let author = data["author"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            return nil
                        }
                        return Comment(postId: postId, text: text, author: author, timestamp: timestamp)
                    }
                    
                    DispatchQueue.main.async {
                        // Sort comments by timestamp on the client side
                        let sortedComments = comments.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                        self.userComments = sortedComments
                        print("✅ Loaded \(sortedComments.count) user comments")
                        completion()
                    }
                } else {
                    print("⚠️ No comments found")
                    DispatchQueue.main.async {
                        self.userComments = []
                        completion()
                    }
                }
            }
    }
    
    private func calculateKarma() {
        karma = userPosts.reduce(0) { total, post in
            total + post.upvotes.count - (post.downvotes?.count ?? 0)
        }
    }
    
    // Helper function for time formatting
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
} 