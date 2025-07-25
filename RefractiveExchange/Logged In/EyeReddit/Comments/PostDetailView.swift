//
//  PostDetailView.swift
//  RefractiveExchange
//
//  Reddit-style post detail view
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct PostDetailView: View {
    let post: FetchedPost
    @ObservedObject var data: GetData
    @ObservedObject var viewModel: PostRowModel
    @ObservedObject var commentModel: CommentModel
    @Environment(\.dismiss) var dismiss
    @State var commentText = ""
    @State var isLoading = false
    @State private var showErrorToast: Bool = false
    @State private var isSaved = false
    @State private var selectedUserProfile: UserProfile?
    
    let saveService = SaveService.shared
    
    init(post: FetchedPost, data: GetData) {
        self.post = post
        self.data = data
        self.viewModel = PostRowModel(post: post)
        self.commentModel = CommentModel(post: post)
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Full Post Content - Reddit Style
                        fullPostView
                        
                        // Divider
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 8)
                        
                        // Comments Section
                        commentsSection
                    }
                }
                
                // Comment Input - Always at bottom like Reddit
                commentInputView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Share functionality
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            commentModel.fetchComments()
            checkIfPostIsSaved()
        }
        .sheet(item: $selectedUserProfile) { userProfile in
            PublicProfileView(
                username: userProfile.username,
                userId: userProfile.userId,
                data: data
            )
        }
    }
    
    // MARK: - Full Post View (Reddit Style)
    private var fullPostView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author and metadata
            HStack(spacing: 8) {
                // Avatar
                Group {
                    if let avatarUrlString = post.avatarUrl, let url = URL(string: avatarUrlString) {
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
                    } else {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            )
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.subreddit)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(timeAgoString(from: post.timestamp.dateValue()))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("u/\(post.author)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Post title - Large and prominent like Reddit
            Text(post.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Post text - Full text, not truncated
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            }
            
            // Post image if available
            if let imageUrlString = post.imageURL, let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
                .cornerRadius(8)
                .padding(.vertical, 8)
            }
            
            // Vote and action buttons - Reddit style
            HStack(spacing: 0) {
                // Voting container
                HStack(spacing: 8) {
                    Button {
                        viewModel.upvote()
                    } label: {
                        Image(systemName: viewModel.liked ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(viewModel.liked ? .orange : .gray)
                    }
                    
                    Text("\(post.upvotes.count - (post.downvotes?.count ?? 0))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(viewModel.liked ? .orange : viewModel.disliked ? .purple : .primary)
                        .frame(minWidth: 30)
                    
                    Button {
                        viewModel.downvote()
                    } label: {
                        Image(systemName: viewModel.disliked ? "arrowtriangle.down.fill" : "arrowtriangle.down")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(viewModel.disliked ? .purple : .gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(20)
                
                Spacer()
                
                // Comment count
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("\(commentModel.comments.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                // Save button
                Button(action: {
                    toggleSavePost()
                }) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(isSaved ? .orange : .gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                // Share button
                Button(action: {
                    // Share functionality
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Comments header
            HStack {
                Text("Comments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(commentModel.comments.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Comments list
            if commentModel.comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No comments yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Be the first to share what you think!")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .background(Color(.systemBackground))
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(commentModel.comments, id: \.timestamp) { comment in
                        CommentRow(
                            comment: comment,
                            onUsernameTapped: { username, userId in
                                selectedUserProfile = UserProfile(username: username, userId: userId)
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
    }
    
    // MARK: - Comment Input
    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // User avatar (small)
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    )
                    .frame(width: 28, height: 28)
                
                // Comment input field
                TextField("Add a comment...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                
                // Post button
                Button("Post") {
                    postComment()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Functions
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
    
    private func postComment() {
        let trimmedCommentText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommentText.isEmpty {
            showErrorToast = true
            return
        }
        
        isLoading = true
        Task {
            do {
                let authorName = data.user?.exchangeUsername?.isEmpty == false ? data.user!.exchangeUsername! : "\(data.user?.firstName ?? "Anonymous") \(data.user?.lastName ?? "User")"
                let comment = Comment(postId: post.id!, text: trimmedCommentText, author: authorName, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], uid: Auth.auth().currentUser?.uid ?? "")
                try await uploadFirebase(comment)
                
                await MainActor.run {
                    commentText = ""
                    isLoading = false
                    commentModel.fetchComments()
                }
                
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } catch {
                await MainActor.run {
                    isLoading = false
                    showErrorToast = true
                }
            }
        }
    }
    
    private func uploadFirebase(_ comment: Comment) async throws {
        let docData: [String: Any] = [
            "postId": comment.postId,
            "text": comment.text,
            "author": comment.author,
            "timestamp": comment.timestamp,
            "upvotes": comment.upvotes,
            "downvotes": comment.downvotes,
            "uid": comment.uid
        ]
        
        _ = try await Firestore.firestore().collection("comments").addDocument(data: docData)
    }
    
    private func checkIfPostIsSaved() {
        guard let postId = post.id else { return }
        
        saveService.isPostSaved(postId) { saved in
            DispatchQueue.main.async {
                self.isSaved = saved
            }
        }
    }
    
    private func toggleSavePost() {
        guard let postId = post.id else { return }
        
        saveService.toggleSavePost(postId) { saved in
            DispatchQueue.main.async {
                self.isSaved = saved
            }
        }
    }
}

#Preview {
    PostDetailView(post: FetchedPost(
        title: "Sample Post Title",
        text: "This is a sample post text that demonstrates how the post detail view looks with longer content.",
        timestamp: Timestamp(date: Date()),
        upvotes: ["user1", "user2"],
        downvotes: ["user3"],
        subreddit: "r/SampleSubreddit",
        imageURL: nil,
        didLike: false,
        didDislike: false,
        author: "SampleUser",
        uid: "sample_uid",
        avatarUrl: nil
    ), data: GetData())
} 