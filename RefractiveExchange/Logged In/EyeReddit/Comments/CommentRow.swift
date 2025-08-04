//
//  CommentRow.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/7/23.
//

import SwiftUI
import FirebaseAuth

struct CommentRow: View {
    
    @ObservedObject var viewModel: CommentRowModel
    @State private var showDeleteAlert = false
    @State private var showEditView = false
    var onUsernameTapped: ((String, String) -> Void)? = nil
    var onCommentUpdated: (() -> Void)? = nil
    let commentService = CommentService()
    
    init(comment: Comment, onUsernameTapped: ((String, String) -> Void)? = nil, onCommentUpdated: (() -> Void)? = nil)  {
        self.viewModel = CommentRowModel(comment: comment)
        self.onUsernameTapped = onUsernameTapped
        self.onCommentUpdated = onCommentUpdated
    }
        
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !self.viewModel.comment.author.isEmpty  {
                VStack(alignment: .leading, spacing: 12) {
                    // Comment header with author and time
                    HStack {
                        Button(action: {
                            onUsernameTapped?(self.viewModel.comment.author, self.viewModel.comment.safeUid)
                        }) {
                            Text(self.viewModel.comment.author)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if let flair = viewModel.comment.flair {
                            FlairView(flair: flair)
                        }
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(timeAgoString(from: self.viewModel.comment.timestamp.dateValue()))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Three dots menu (only for comment author)
                        if let user = Auth.auth().currentUser {
                            let commentAuthor = self.viewModel.comment.author
                            let commentUid = self.viewModel.comment.safeUid
                            let isAuthor = user.uid == commentUid || user.displayName == commentAuthor || user.uid == commentAuthor || commentAuthor == user.email
                            
                            if isAuthor {
                                ThreeDotsMenu(
                                    isAuthor: true,
                                    onEdit: {
                                        showEditView = true
                                    },
                                    onDelete: {
                                        showDeleteAlert = true
                                    },
                                    size: 12
                                )
                                .alert(isPresented: $showDeleteAlert) {
                                    Alert(
                                        title: Text("Delete Comment"),
                                        message: Text("Are you sure you want to delete this comment?"),
                                        primaryButton: .destructive(Text("Delete")) {
                                            commentService.deleteComment(self.viewModel.comment) { success in
                                                if success {
                                                    onCommentUpdated?()
                                                }
                                            }
                                        },
                                        secondaryButton: .cancel()
                                    )
                                }
                                .sheet(isPresented: $showEditView) {
                                    EditCommentView(
                                        comment: self.viewModel.comment,
                                        onSave: { newText in
                                            viewModel.updateCommentText(newText)
                                            onCommentUpdated?()
                                        },
                                        onCancel: {
                                            showEditView = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Comment text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.viewModel.comment.text)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        // Show "edited" indicator if comment was edited
                        if self.viewModel.comment.editedAt != nil {
                            Text("(edited)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    
                    // Vote buttons - Reddit style
                    HStack(spacing: 16) {
                        // Voting section
                        HStack(spacing: 8) {
                            Button {
                                viewModel.upvote()
                            } label: {
                                Image(systemName: viewModel.liked ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(viewModel.liked ? .orange : .gray)
                            }
                            
                            Text("\(viewModel.comment.safeUpvotes.count - viewModel.comment.safeDownvotes.count)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(viewModel.liked ? .orange : viewModel.disliked ? .purple : .secondary)
                                .frame(minWidth: 24)
                            
                            Button {
                                viewModel.downvote()
                            } label: {
                                Image(systemName: viewModel.disliked ? "arrowtriangle.down.fill" : "arrowtriangle.down")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(viewModel.disliked ? .purple : .gray)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        
                        Spacer()
                    }
                }
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

//struct CommentRow_Previews: PreviewProvider {
//    static var previews: some View {
//        CommentRow()
//    }
//}
