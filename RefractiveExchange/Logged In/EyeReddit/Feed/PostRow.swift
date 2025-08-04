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
    
    let saveService = SaveService.shared
    
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
            Button(action: {
                onPostTapped?()
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    if !self.viewModel.post.author.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            // Avatar with fallback
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
                                // Fallback avatar
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 16))
                                    )
                                    .frame(width: 40, height: 40)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                // Author and metadata
                                HStack(spacing: 6) {
                                    Button(action: {
                                        onSubredditTapped?(self.viewModel.post.subreddit)
                                    }) {
                                        Text(self.viewModel.post.subreddit)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Text("•")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                                    Button(action: {
                                        onUsernameTapped?(self.viewModel.post.author, self.viewModel.post.uid)
                                    }) {
                                        Text("\(self.viewModel.post.author)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
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
                                    
                                    // Three dots menu (only for post author) - moved to top right
                                    if let currentUid = Auth.auth().currentUser?.uid, currentUid == viewModel.post.uid {
                                        ThreeDotsMenu(
                                            isAuthor: true,
                                            onEdit: {
                                                showEditView = true
                                            },
                                            onDelete: {
                                                showDeleteAlert = true
                                            },
                                            size: 16
                                        )
                                        .alert(isPresented: $showDeleteAlert) {
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
                                        .sheet(isPresented: $showEditView) {
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
                                    }
                                }
                                
                                // Post content
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(self.viewModel.post.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    if !truncatedText.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(truncatedText)
                                                .font(.system(size: 14))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            // Show "edited" indicator if post was edited
                                            if self.viewModel.post.editedAt != nil {
                                                Text("(edited)")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                    }
                    
                    // Display multiple images in a horizontal scrollable gallery
                    if let imageURLs = viewModel.post.imageURLs, !imageURLs.isEmpty {
                        if imageURLs.count == 1 {
                            // Single image - display normally
                            if let url = URL(string: imageURLs[0]) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 150, maxHeight: 400)
                                    case .failure(_):
                                        // Error state with retry option
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
                                    case .empty:
                                        // Loading state
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                            Text("Loading image...")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                        .background(Color(.systemGray6))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                        } else {
                            // Multiple images - display in horizontal scroll view
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(imageURLs.count) images")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
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
                                    .padding(.leading, 12)
                                    .padding(.trailing, 12)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Action buttons - Reddit style (outside the main post button)
            HStack(spacing: 24) {
                // Vote section with Reddit-style layout
                HStack(spacing: 8) {
                    // Upvote button
                    Button {
                        viewModel.upvote()
                    } label: {
                        Image(systemName: viewModel.liked ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(viewModel.liked ? .orange : .gray)
                    }
                    
                    // Score (upvotes - downvotes)
                    Text("\(viewModel.post.upvotes.count - (viewModel.post.downvotes?.count ?? 0))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(viewModel.liked ? .orange : viewModel.disliked ? .purple : .primary)
                        .frame(minWidth: 30)
                    
                    // Downvote button
                    Button {
                        viewModel.downvote()
                    } label: {
                        Image(systemName: viewModel.disliked ? "arrowtriangle.down.fill" : "arrowtriangle.down")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(viewModel.disliked ? .purple : .gray)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(20)

                // Comment button
                Button {
                    onCommentTapped?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        Text("\(viewModel.comments.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
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

