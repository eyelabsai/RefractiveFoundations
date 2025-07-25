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
    @State private var isSaved = false
    
    let saveService = SaveService.shared
    
    init(post: FetchedPost, onCommentTapped: (() -> Void)? = nil, onPostTapped: (() -> Void)? = nil, onUsernameTapped: ((String, String) -> Void)? = nil) {
        self.viewModel = PostRowModel(post: post)
        self.onCommentTapped = onCommentTapped
        self.onPostTapped = onPostTapped
        self.onUsernameTapped = onUsernameTapped
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
                                onUsernameTapped?(self.viewModel.post.author, self.viewModel.post.uid)
                            }) {
                                Text("\(self.viewModel.post.author)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(timeAgoString(from: self.viewModel.post.timestamp.dateValue()))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(self.viewModel.post.subreddit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.vertical, 2)

                        // Post content - Clickable
                        Button(action: {
                            onPostTapped?()
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(self.viewModel.post.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if !truncatedText.isEmpty {
                                    Text(truncatedText)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
            
            if let urlString = viewModel.post.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }


            
            // Action buttons - Reddit style
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
                
                // Save button
                Button {
                    toggleSavePost()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(isSaved ? .orange : .gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                Spacer()
                // Delete button (only for post author)
                if let currentUid = Auth.auth().currentUser?.uid, currentUid == viewModel.post.uid {
                    Button(role: .destructive) {
                        PostService().deletePost(viewModel.post) { success in
                            if success {
                                FeedViewModel.shared.refreshPosts()
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, -16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
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

