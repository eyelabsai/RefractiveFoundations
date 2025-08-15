//
//  PostRow.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/6/23.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct PostRow: View {
    @ObservedObject var viewModel: PostRowModel
    var onCommentTapped: (() -> Void)? = nil
    var onPostTapped: (() -> Void)? = nil
    var onUsernameTapped: ((String, String) -> Void)? = nil
    var onSubredditTapped: ((String) -> Void)? = nil
    @State private var isSaved = false
    @State private var showDeleteAlert = false
    @State private var showEditView = false
    @State private var showPinAlert = false
    @State private var showUnpinAlert = false
    
    let saveService = SaveService.shared
    @ObservedObject var adminService = AdminService.shared
    
    init(post: FetchedPost, onCommentTapped: (() -> Void)? = nil, onPostTapped: (() -> Void)? = nil, onUsernameTapped: ((String, String) -> Void)? = nil, onSubredditTapped: ((String) -> Void)? = nil) {
        self.viewModel = PostRowModel(post: post)
        self.onCommentTapped = onCommentTapped
        self.onPostTapped = onPostTapped
        self.onUsernameTapped = onUsernameTapped
        self.onSubredditTapped = onSubredditTapped
    }
    
    var truncatedText: String {
        let maxLength = 300
        let text = self.viewModel.post.text
        if text.count > maxLength {
            let endIndex = text.index(text.startIndex, offsetBy: maxLength)
            return String(text[..<endIndex]) + "..."
        } else {
            return text
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            postContentButton
            postInteractionBar
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            checkIfPostIsSaved()
        }
    }
    
    // MARK: - Main Post Content Button
    private var postContentButton: some View {
        Button(action: {
            onPostTapped?()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                if !self.viewModel.post.author.isEmpty {
                    authorSection
                    postMainContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Author Section
    private var authorSection: some View {
        HStack(alignment: .top, spacing: 12) {
            authorAvatar
            authorInfo
        }
    }
    
    // MARK: - Author Avatar
    private var authorAvatar: some View {
        Group {
            if let avatarUrlString = self.viewModel.post.avatarUrl, let url = URL(string: avatarUrlString) {
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
                                .font(.system(size: 16))
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    )
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    // MARK: - Author Info Section
    private var authorInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                // First row: Subforum and username
                HStack(spacing: 6) {
                    subredditButton
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    authorButton
                    
                    Spacer()
                    
                    adminMenuButton
                }
                
                // Second row: Flair and timestamp
                metadataRow
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            deleteAlert
        }
        .sheet(isPresented: $showEditView) {
            editSheet
        }
        .alert("Pin Post", isPresented: $showPinAlert) {
            Button("Pin") { pinPost() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will pin the post to the top of the feed for all users to see.")
        }
        .alert("Unpin Post", isPresented: $showUnpinAlert) {
            Button("Unpin") { unpinPost() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the post from the top of the feed.")
        }
    }
    
    // MARK: - Component Views
    private var subredditButton: some View {
        Button(action: {
            onSubredditTapped?(self.viewModel.post.subreddit)
        }) {
            Text(self.viewModel.post.subreddit)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var authorButton: some View {
        Button(action: {
            onUsernameTapped?(self.viewModel.post.author, self.viewModel.post.uid)
        }) {
            HStack(spacing: 4) {
                Text("\(self.viewModel.post.author)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var adminMenuButton: some View {
        Group {
            if let currentUid = Auth.auth().currentUser?.uid {
                let isAuthor = currentUid == viewModel.post.uid
                let canPin = adminService.hasPermission(.pinPosts)
                
                if isAuthor || canPin {
                    ThreeDotsMenu(
                        isAuthor: isAuthor,
                        onEdit: isAuthor ? { showEditView = true } : nil,
                        onDelete: isAuthor ? { showDeleteAlert = true } : nil,
                        onPin: canPin ? { showPinAlert = true } : nil,
                        onUnpin: canPin ? { showUnpinAlert = true } : nil,
                        isPinned: viewModel.post.isPinned,
                        canPin: canPin,
                        size: 16
                    )
                }
            }
        }
    }
    
    // MARK: - Alert and Sheet Components
    private var deleteAlert: Alert {
        Alert(
            title: Text("Delete Post"),
            message: Text("Are you sure you want to delete this post? This action cannot be undone."),
            primaryButton: .destructive(Text("Delete")) {
                PostService().deletePost(viewModel.post) { success in
                    if success {
                        FeedViewModel.shared.refreshPosts()
                    }
                }
            },
            secondaryButton: .cancel()
        )
    }
    
    private var editSheet: some View {
        EditPostView(
            post: viewModel.post,
            onSave: { newText in
                viewModel.updatePostText(newText)
            },
            onCancel: {
                showEditView = false
            }
        )
    }
    
    // MARK: - Metadata Row
    private var metadataRow: some View {
        HStack(spacing: 6) {
            if let flair = viewModel.post.flair {
                FlairView(flair: flair)
            }
            
            Text("•")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(timeAgoString(from: self.viewModel.post.timestamp.dateValue()))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Post Main Content
    private var postMainContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Pinned post indicator (like Reddit)
            if viewModel.post.isPinned == true {
                pinnedIndicator
            }
            
            postTitle
            postTextContent
            postImages
        }
    }
    
    private var pinnedIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
            
            Text("PINNED BY MODERATOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var postTitle: some View {
        Text(self.viewModel.post.title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var postTextContent: some View {
        Group {
            if !truncatedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(truncatedText)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Show "edited" indicator if post was edited
                    if self.viewModel.post.editedAt != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Text("edited")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }
    
    private var postImages: some View {
        Group {
            if let imageURLs = self.viewModel.post.imageURLs, !imageURLs.isEmpty {
                imageCarousel(urls: imageURLs)
            }
        }
    }
    
    private func imageCarousel(urls: [String]) -> some View {
        Group {
            if urls.count == 1 {
                singleImage(url: urls[0])
            } else {
                multipleImagesCarousel(urls: urls)
            }
        }
    }
    
    private func singleImage(url: String) -> some View {
        Group {
            if let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 150, maxHeight: 400)
                    case .failure(_):
                        imageErrorView
                    case .empty:
                        imageLoadingView
                    @unknown default:
                        imageErrorView
                    }
                }
                .cornerRadius(8)
            }
        }
    }
    
    private var imageErrorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 24))
                .foregroundColor(.gray)
            Text("Failed to load image")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
    }
    
    private var imageLoadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Loading image...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
    }
    
    private func multipleImagesCarousel(urls: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(urls.count) images")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 150)
                                        .clipped()
                                        .cornerRadius(8)
                                case .failure(_):
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo.badge.exclamationmark")
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                        Text("Failed")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 200, height: 150)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                case .empty:
                                    VStack(spacing: 4) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.8)
                                        Text("Loading...")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 200, height: 150)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Post Interaction Bar
    private var postInteractionBar: some View {
        HStack(spacing: 16) {
            // Upvote button
            Button {
                viewModel.upvote()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.post.didLike ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.post.didLike ? .orange : .gray)
                    
                    Text("\(viewModel.post.upvotes.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.post.didLike ? .orange : .gray)
                }
            }
            
            // Comment button
            Button {
                onCommentTapped?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("Comment")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Save button for non-authors
            if let currentUid = Auth.auth().currentUser?.uid, currentUid != viewModel.post.uid {
                Button {
                    toggleSavePost()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(isSaved ? .orange : .gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Save Functionality
    private func checkIfPostIsSaved() {
        guard let postId = viewModel.post.id else { return }
        
        saveService.isPostSaved(postId) { saved in
            DispatchQueue.main.async {
                self.isSaved = saved
            }
        }
    }
    
    private func toggleSavePost() {
        guard let postId = viewModel.post.id else { return }
        
        saveService.toggleSavePost(postId) { saved in
            DispatchQueue.main.async {
                self.isSaved = saved
            }
        }
    }
    
    // Helper function for time formatting
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
    
    // MARK: - Admin Pin Functionality
    private func pinPost() {
        guard let postId = viewModel.post.id else { return }
        
        adminService.pinPost(postId) { success in
            DispatchQueue.main.async {
                if success {
                    // Refresh the feed to show updated pin status
                    FeedViewModel.shared.refreshPosts()
                } else {
                    print("❌ Failed to pin post")
                }
            }
        }
    }
    
    private func unpinPost() {
        guard let postId = viewModel.post.id else { return }
        
        adminService.unpinPost(postId) { success in
            DispatchQueue.main.async {
                if success {
                    // Refresh the feed to show updated pin status
                    FeedViewModel.shared.refreshPosts()
                } else {
                    print("❌ Failed to unpin post")
                }
            }
        }
    }
}