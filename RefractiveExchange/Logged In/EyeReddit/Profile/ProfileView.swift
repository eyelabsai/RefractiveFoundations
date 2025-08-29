//
//  ProfileView.swift
//  RefractiveFoundations
//
//  Reddit-style profile view
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @ObservedObject var data: GetData
    @EnvironmentObject var darkModeManager: DarkModeManager
    @ObservedObject var adminService = AdminService.shared
    @State private var selectedTab = 0
    @State private var userPosts: [FetchedPost] = []
    @State private var userComments: [Comment] = []
    @State private var savedPosts: [FetchedPost] = []
    @State private var isLoading = true
    @State private var memberSince = ""
    @State private var yearsActive = 0 // Keep for backend anniversary tracking - will show as badges next to username when milestones are reached
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingChangePassword = false
    @State private var selectedUserProfile: UserProfile?
    
    // Change Password fields
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    let tabTitles = ["Posts", "Comments", "Saved", "About"]
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
                    postsTab
                        .tag(0)
                    
                    // Comments Tab
                    commentsTab
                        .tag(1)
                    
                    // Saved Tab
                    savedTab
                        .tag(2)
                    
                    // About Tab
                    aboutTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .onAppear {
                print("🎬 ProfileView appeared")
                print("👤 Current user data: \(data.user?.firstName ?? "nil") \(data.user?.lastName ?? "nil")")
                print("🔐 Auth UID: \(Auth.auth().currentUser?.uid ?? "nil")")
                
                // Check admin role
                adminService.checkCurrentUserRole()
                
                // Check if user needs migration (missing user document)
                if data.user == nil && Auth.auth().currentUser != nil {
                    print("🚨 User authenticated but no user document found - attempting migration")
                    FirebaseManager.shared.createMissingUserDocument { success in
                        if success {
                            print("✅ Migration successful, reloading user data")
                            DispatchQueue.main.async {
                                self.data.fetchUser()
                                self.loadUserData()
                                // Check admin role again after user data loads
                                self.adminService.checkCurrentUserRole()
                            }
                        }
                    }
                } else {
                    loadUserData()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(data: data)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(data: data)
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete My Account", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure? Deleting your account will permanently erase all saved data and cannot be undone.")
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView(
                    currentPassword: $currentPassword,
                    newPassword: $newPassword,
                    confirmPassword: $confirmPassword,
                    onPasswordChanged: {
                        // Clear password fields after successful change
                        currentPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                    }
                )
            }
            .fullScreenCover(item: $selectedUserProfile) { userProfile in
                PublicProfileView(
                    username: userProfile.username,
                    userId: userProfile.userId,
                    data: data
                )
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Top row with discreet buttons
            HStack {
                Spacer()
                
                HStack(spacing: 16) {
                    // Dark mode toggle
                    Button(action: {
                        darkModeManager.toggleDarkMode()
                    }) {
                        Image(systemName: darkModeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 16))
                            .foregroundColor(darkModeManager.isDarkMode ? .orange : .purple)
                    }
                    
                    // Settings button
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    
                    // Sign out button
                    Button(action: {
                        FirebaseManager.shared.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
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
                    // Name
                    if let user = data.user {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Member since
                        Text("• Member since \(memberSince)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        // Specialty badge
                        FlairView(flair: user.specialty)
                    }
                }
                
                Spacer()
                
                // Edit button
                Button("Edit") {
                    showingEditProfile = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            
            // Stats Row
            HStack(spacing: 0) {
                Spacer()
                statItem(title: "Posts", count: userPosts.count)
                statItem(title: "Comments", count: userComments.count)
                statItem(title: "Saved", count: savedPosts.count)
                Spacer()
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
    
    // MARK: - Tab Views
    private var postsTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading posts...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if userPosts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No posts yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Your posts will appear here once you start sharing.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(userPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post, data: data)
                        } label: {
                            PostRow(
                                post: post,
                                onCommentTapped: {
                                    // Navigate to post detail
                                },
                                onPostTapped: {
                                    // Navigate to post detail
                                },
                                onUsernameTapped: { username, userId in
                                    selectedUserProfile = UserProfile(username: username, userId: userId)
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var commentsTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading comments...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if userComments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No comments yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Your comments will appear here once you start engaging.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(userComments, id: \.timestamp) { comment in
                        CommentRow(
                            comment: comment,
                            onUsernameTapped: { username, userId in
                                selectedUserProfile = UserProfile(username: username, userId: userId)
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
    
    private var savedTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading saved posts...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if savedPosts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No saved posts")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Save posts to view them here later.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(savedPosts) { post in
                        NavigationLink {
                            PostDetailView(post: post, data: data)
                        } label: {
                            PostRow(
                                post: post,
                                onCommentTapped: {
                                    // Navigate to post detail
                                },
                                onPostTapped: {
                                    // Navigate to post detail
                                },
                                onUsernameTapped: { username, userId in
                                    selectedUserProfile = UserProfile(username: username, userId: userId)
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Information")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Full Name:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(data.user?.firstName ?? "") \(data.user?.lastName ?? "")")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Specialty:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(data.user?.specialty ?? "Not specified")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Practice Location:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(data.user?.practiceLocation ?? "Not specified")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Practice Name:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(data.user?.practiceName ?? "Not specified")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Email:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(data.user?.email ?? "Not available")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Member Since:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(memberSince)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Years Active:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(yearsActive) year\(yearsActive != 1 ? "s" : "")")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Activity Stats
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
                            Text("\(userPosts.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Comments:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(userComments.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Saved Posts:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(savedPosts.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Account Management
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        Button(action: {
                            showingEditProfile = true
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("Edit Profile")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        Button(action: {
                            showingChangePassword = true
                        }) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("Change Password")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("Settings")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Admin Panel Button - Show only for admin/moderator users
                        if adminService.canAccessAdminPanel() {
                            Divider()
                            
                            NavigationLink(destination: AdminPanelView()) {
                                HStack {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    
                                    Text("Admin Panel")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Admin Panel access added
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Views
    private func statItem(title: String, count: Int?) -> some View {
        VStack(spacing: 4) {
            if let count = count {
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            } else {
                Text("ℹ︎")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
            }
            
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
        
        // Set current year as default
        let currentYear = Calendar.current.component(.year, from: Date())
        memberSince = "\(currentYear)"
        
        let group = DispatchGroup()
        
        // Load user creation date
        group.enter()
        Firestore.firestore().collection("users").document(uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    do {
                        let user = try document.data(as: User.self)
                        
                        if let dateJoined = user.dateJoined {
                            let date = dateJoined.dateValue()
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            self.memberSince = formatter.string(from: date)
                            
                            // Calculate years active
                            let currentYear = Calendar.current.component(.year, from: Date())
                            let joinYear = Calendar.current.component(.year, from: date)
                            self.yearsActive = max(0, currentYear - joinYear)
                        }
                    } catch {
                        print("❌ Error decoding user data: \(error)")
                        self.memberSince = "Unknown"
                    }
                }
                group.leave()
            }
        }
        
        // Load user posts
        group.enter()
        print("📥 Loading user posts...")
        service.fetchPosts(uid: uid) { posts in
            print("✅ Loaded \(posts.count) user posts")
            DispatchQueue.main.async {
                self.userPosts = posts
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
        Firestore.firestore().collection("comments")
            .whereField("uid", isEqualTo: uid)
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
                        try? doc.data(as: Comment.self)
                    }
                    
                    // Filter out comments from deleted posts
                    self.filterCommentsFromExistingPosts(comments: comments) { validComments in
                        DispatchQueue.main.async {
                            // Sort comments by timestamp on the client side
                            let sortedComments = validComments.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                            self.userComments = sortedComments
                            print("✅ Loaded \(sortedComments.count) valid user comments (filtered from \(comments.count) total)")
                            completion()
                        }
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
    
    private func filterCommentsFromExistingPosts(comments: [Comment], completion: @escaping ([Comment]) -> Void) {
        let group = DispatchGroup()
        var validComments: [Comment] = []
        
        for comment in comments {
            group.enter()
            
            // Check if the post this comment references still exists
            Firestore.firestore().collection("posts").document(comment.postId).getDocument { document, error in
                if let document = document, document.exists {
                    // Post exists, keep the comment
                    validComments.append(comment)
                } else {
                    // Post doesn't exist (was deleted), skip this comment
                    print("🗑️ Skipping comment \(comment.id ?? "unknown") - post \(comment.postId) no longer exists")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(validComments)
        }
    }
    

    
    // Helper function for time formatting
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Show loading state
        isLoading = true
        
        // First, delete user data from Firestore
        let uid = user.uid
        let db = Firestore.firestore()
        
        // Delete user's posts
        db.collection("posts").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                for document in documents {
                    document.reference.delete()
                }
            }
            
            // Delete user's comments
            db.collection("comments").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for document in documents {
                        document.reference.delete()
                    }
                }
                
                // Delete user's saved posts
                db.collection("savedPosts").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        for document in documents {
                            document.reference.delete()
                        }
                    }
                    
                    // Delete user's conversations
                    db.collection("conversations").whereField("participants", arrayContains: uid).getDocuments { snapshot, error in
                        if let documents = snapshot?.documents {
                            for document in documents {
                                document.reference.delete()
                            }
                        }
                        
                        // Delete user's direct messages
                        db.collection("directMessages").whereField("senderId", isEqualTo: uid).getDocuments { snapshot, error in
                            if let documents = snapshot?.documents {
                                for document in documents {
                                    document.reference.delete()
                                }
                            }
                            
                            // Finally, delete the user document itself
                            db.collection("users").document(uid).delete { error in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        print("❌ Error deleting user document: \(error)")
                                        self.isLoading = false
                                        return
                                    }
                                    
                                    // Now delete the Firebase Auth account
                                    user.delete { error in
                                        DispatchQueue.main.async {
                                            self.isLoading = false
                                            if let error = error {
                                                print("❌ Error deleting Firebase Auth account: \(error)")
                                                // Show error alert
                                                return
                                            }
                                            
                                            // Account deletion successful
                                            print("✅ Account deleted successfully")
                                            // The app will automatically redirect to login since user is no longer authenticated
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var data: GetData
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var darkModeManager: DarkModeManager
    @State private var memberSince = ""
    @State private var yearsActive = 0
    @State private var showingDeleteAccountAlert = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Personal Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Personal Information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            InfoRow(title: "Full Name", value: "\(data.user?.firstName ?? "") \(data.user?.lastName ?? "")")
                            InfoRow(title: "Display Name", value: "\(data.user?.firstName ?? "") \(data.user?.lastName ?? "")")
                            InfoRow(title: "Specialty", value: data.user?.specialty ?? "Not specified")
                            InfoRow(title: "Email", value: data.user?.email ?? "Not available")
                            InfoRow(title: "Member Since", value: memberSince)
                            InfoRow(title: "Years Active", value: "\(yearsActive) year\(yearsActive != 1 ? "s" : "")")
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // App Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("App Settings")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            // Dark Mode Toggle
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: darkModeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(darkModeManager.isDarkMode ? .purple : .orange)
                                        .frame(width: 24)
                                    
                                    Text("Dark Mode")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { darkModeManager.isDarkMode },
                                    set: { _ in darkModeManager.toggleDarkMode() }
                                ))
                                .toggleStyle(SwitchToggleStyle())
                            }
                            
                            // Notification Settings Button
                            NotificationSettingsButton()
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Account Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Account")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            // Edit Profile Button
                            Button(action: {
                                showingEditProfile = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text("Edit Profile")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Divider()
                            
                            // Sign Out Button
                            Button(action: {
                                FirebaseManager.shared.signOut()
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Sign Out")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Divider()
                            
                            // Delete Account Button
                            Button(action: {
                                showingDeleteAccountAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Delete My Account")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadSettingsData()
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete My Account", role: .destructive) {
                    deleteAccountFromSettings()
                }
            } message: {
                Text("Are you sure? Deleting your account will permanently erase all saved data and cannot be undone.")
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(data: data)
            }
        }
    }
    
    private func loadSettingsData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Set current year as default
        let currentYear = Calendar.current.component(.year, from: Date())
        memberSince = "\(currentYear)"
        
        // Load user creation date
        Firestore.firestore().collection("users").document(uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    do {
                        let user = try document.data(as: User.self)
                        
                        if let dateJoined = user.dateJoined {
                            let date = dateJoined.dateValue()
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            self.memberSince = formatter.string(from: date)
                            
                            // Calculate years active
                            let currentYear = Calendar.current.component(.year, from: Date())
                            let joinYear = Calendar.current.component(.year, from: date)
                            self.yearsActive = max(0, currentYear - joinYear)
                        }
                    } catch {
                        print("❌ Error decoding user data: \(error)")
                        self.memberSince = "Unknown"
                    }
                }
            }
        }
    }
    
    private func deleteAccountFromSettings() {
        guard let user = Auth.auth().currentUser else { return }
        
        // First, delete user data from Firestore
        let uid = user.uid
        let db = Firestore.firestore()
        
        // Delete user's posts
        db.collection("posts").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                for document in documents {
                    document.reference.delete()
                }
            }
            
            // Delete user's comments
            db.collection("comments").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for document in documents {
                        document.reference.delete()
                    }
                }
                
                // Delete user's saved posts
                db.collection("savedPosts").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        for document in documents {
                            document.reference.delete()
                        }
                    }
                    
                    // Delete user's conversations
                    db.collection("conversations").whereField("participants", arrayContains: uid).getDocuments { snapshot, error in
                        if let documents = snapshot?.documents {
                            for document in documents {
                                document.reference.delete()
                            }
                        }
                        
                        // Delete user's direct messages
                        db.collection("directMessages").whereField("senderId", isEqualTo: uid).getDocuments { snapshot, error in
                            if let documents = snapshot?.documents {
                                for document in documents {
                                    document.reference.delete()
                                }
                            }
                            
                            // Finally, delete the user document itself
                            db.collection("users").document(uid).delete { error in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        print("❌ Error deleting user document: \(error)")
                                        return
                                    }
                                    
                                    // Now delete the Firebase Auth account
                                    user.delete { error in
                                        DispatchQueue.main.async {
                                            if let error = error {
                                                print("❌ Error deleting Firebase Auth account: \(error)")
                                                return
                                            }
                                            
                                            // Account deletion successful
                                            print("✅ Account deleted successfully")
                                            // Dismiss settings and the app will redirect to login
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var data: GetData
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedSpecialty = "Resident"
    @State private var practiceLocation = ""
    @State private var practiceName = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingChangePassword = false
    
    // Change Password fields
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    let specialties = [
        "Resident",
        "Fellow",
        "Refractive Surgeon",
        "Optometrist/APP",
        "Industry"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Profile Photo Section
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 32))
                            )
                            .frame(width: 100, height: 100)
                        
                        Button("Change Photo") {
                            // TODO: Implement photo picker
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Personal Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Personal Information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter first name", text: $firstName)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter last name", text: $lastName)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }
                            
                            // Display Name (Read-only)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if let user = data.user {
                                        Text("\(user.firstName) \(user.lastName)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("Based on your name")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                            }
                            
                            // Specialty
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Specialty")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(specialties, id: \.self) { specialty in
                                        Button(specialty) {
                                            selectedSpecialty = specialty
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedSpecialty)
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                                }
                            }
                            
                            // Practice Location
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Practice Location")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your practice location (city)", text: $practiceLocation)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }
                            
                            // Practice Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Practice Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your practice name", text: $practiceName)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Change Password Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Change Password")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                showingChangePassword = true
                            }) {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text("Change Password")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundColor(.blue)
                    .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)
                }
            }
            .onAppear {
                loadCurrentData()
            }
            .alert("Profile Update", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView(
                    currentPassword: $currentPassword,
                    newPassword: $newPassword,
                    confirmPassword: $confirmPassword,
                    onPasswordChanged: {
                        alertMessage = "Password changed successfully!"
                        showAlert = true
                        // Clear password fields
                        currentPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                    }
                )
            }
        }
    }
    
    private func loadCurrentData() {
        if let user = data.user {
            firstName = user.firstName
            lastName = user.lastName
            selectedSpecialty = user.specialty
            practiceLocation = user.practiceLocation ?? ""
            practiceName = user.practiceName ?? ""
        }
    }
    
    private func saveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard !firstName.isEmpty && !lastName.isEmpty else { return }
        
        isLoading = true
        
        let updatedData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "specialty": selectedSpecialty,
            "practiceLocation": practiceLocation,
            "practiceName": practiceName
        ]
        
        Firestore.firestore().collection("users").document(uid).updateData(updatedData) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    // Update local data
                    self.data.fetchUser()
                    self.alertMessage = "Profile updated successfully!"
                    self.showAlert = true
                    
                    // Dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    private func deleteAccountFromSettings() {
        guard let user = Auth.auth().currentUser else { return }
        
        // First, delete user data from Firestore
        let uid = user.uid
        let db = Firestore.firestore()
        
        // Delete user's posts
        db.collection("posts").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                for document in documents {
                    document.reference.delete()
                }
            }
            
            // Delete user's comments
            db.collection("comments").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for document in documents {
                        document.reference.delete()
                    }
                }
                
                // Delete user's saved posts
                db.collection("savedPosts").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        for document in documents {
                            document.reference.delete()
                        }
                    }
                    
                    // Delete user's conversations
                    db.collection("conversations").whereField("participants", arrayContains: uid).getDocuments { snapshot, error in
                        if let documents = snapshot?.documents {
                            for document in documents {
                                document.reference.delete()
                            }
                        }
                        
                        // Delete user's direct messages
                        db.collection("directMessages").whereField("senderId", isEqualTo: uid).getDocuments { snapshot, error in
                            if let documents = snapshot?.documents {
                                for document in documents {
                                    document.reference.delete()
                                }
                            }
                            
                            // Finally, delete the user document itself
                            db.collection("users").document(uid).delete { error in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        print("❌ Error deleting user document: \(error)")
                                        return
                                    }
                                    
                                    // Now delete the Firebase Auth account
                                    user.delete { error in
                                        DispatchQueue.main.async {
                                            if let error = error {
                                                print("❌ Error deleting Firebase Auth account: \(error)")
                                                return
                                            }
                                            
                                            // Account deletion successful
                                            print("✅ Account deleted successfully")
                                            // Dismiss settings and the app will redirect to login
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Notification Settings Button
struct NotificationSettingsButton: View {
    @State private var showingNotificationSettings = false
    
    var body: some View {
        Button(action: {
            showingNotificationSettings = true
        }) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Notification Settings")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
    }
}

// MARK: - Change Password View
struct ChangePasswordView: View {
    @Binding var currentPassword: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    let onPasswordChanged: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Change Password")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Enter your current password and choose a new secure password.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Password Fields
                    VStack(alignment: .leading, spacing: 20) {
                        // Current Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            SecureField("Enter your current password", text: $currentPassword)
                                .font(.system(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        }
                        
                        // New Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            SecureField("Enter new password", text: $newPassword)
                                .font(.system(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            newPassword.count >= 6 ? Color.green : Color(.systemGray4),
                                            lineWidth: newPassword.isEmpty ? 0.5 : 1
                                        )
                                )
                            
                            // Password requirements
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: newPassword.count >= 6 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(newPassword.count >= 6 ? .green : .red)
                                    
                                    Text("At least 6 characters")
                                        .font(.system(size: 12))
                                        .foregroundColor(newPassword.count >= 6 ? .green : .secondary)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: newPassword != currentPassword && !newPassword.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(newPassword != currentPassword && !newPassword.isEmpty ? .green : .red)
                                    
                                    Text("Different from current password")
                                        .font(.system(size: 12))
                                        .foregroundColor(newPassword != currentPassword && !newPassword.isEmpty ? .green : .secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            SecureField("Confirm new password", text: $confirmPassword)
                                .font(.system(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            (!confirmPassword.isEmpty && confirmPassword == newPassword) ? Color.green : Color(.systemGray4),
                                            lineWidth: confirmPassword.isEmpty ? 0.5 : 1
                                        )
                                )
                            
                            if !confirmPassword.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: confirmPassword == newPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(confirmPassword == newPassword ? .green : .red)
                                    
                                    Text("Passwords match")
                                        .font(.system(size: 12))
                                        .foregroundColor(confirmPassword == newPassword ? .green : .red)
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        // Change Password Button
                        Button(action: {
                            changePassword()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isLoading ? "Changing Password..." : "Change Password")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isFormValid() ? Color.blue : Color.gray.opacity(0.5)
                            )
                            .cornerRadius(10)
                        }
                        .disabled(!isFormValid() || isLoading)
                        .padding(.top, 16)
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert("Password Change", isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func isFormValid() -> Bool {
        return !currentPassword.isEmpty &&
               !newPassword.isEmpty &&
               !confirmPassword.isEmpty &&
               newPassword.count >= 6 &&
               newPassword == confirmPassword &&
               newPassword != currentPassword
    }
    
    private func changePassword() {
        guard isFormValid() else { return }
        
        isLoading = true
        
        FirebaseManager.shared.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword
        ) { [self] result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    self.onPasswordChanged()
                    self.dismiss()
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
}

 