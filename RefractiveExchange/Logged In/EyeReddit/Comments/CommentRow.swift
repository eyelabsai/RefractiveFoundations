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
    let commentService = CommentService()
    
    init(comment: Comment)  {
        self.viewModel = CommentRowModel(comment: comment)
    }
        
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !self.viewModel.comment.author.isEmpty  {
                VStack(alignment: .leading, spacing: 8) {
                    // Comment header with author and time
                    HStack {
                        Text(self.viewModel.comment.author)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(timeAgoString(from: self.viewModel.comment.timestamp.dateValue()))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Delete button (only for comment author)
                        if let user = Auth.auth().currentUser {
                            let commentAuthor = self.viewModel.comment.author
                            if user.displayName == commentAuthor || user.uid == commentAuthor || commentAuthor == user.email {
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                }
                                .alert(isPresented: $showDeleteAlert) {
                                    Alert(
                                        title: Text("Delete Comment"),
                                        message: Text("Are you sure you want to delete this comment?"),
                                        primaryButton: .destructive(Text("Delete")) {
                                            commentService.deleteComment(self.viewModel.comment) { success in
                                                // No direct refresh here; parent view should refresh comments
                                            }
                                        },
                                        secondaryButton: .cancel()
                                    )
                                }
                            }
                        }
                    }

                    // Comment text
                    Text(self.viewModel.comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    // Vote buttons - Reddit style
                    HStack(spacing: 16) {
                        // Voting section
                        HStack(spacing: 6) {
                            Button {
                                viewModel.upvote()
                            } label: {
                                Image(systemName: viewModel.liked ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.liked ? .orange : .gray)
                            }
                            
                            Text("\(viewModel.comment.safeUpvotes.count - viewModel.comment.safeDownvotes.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(viewModel.liked ? .orange : viewModel.disliked ? .purple : .secondary)
                                .frame(minWidth: 20)
                            
                            Button {
                                viewModel.downvote()
                            } label: {
                                Image(systemName: viewModel.disliked ? "arrowtriangle.down.fill" : "arrowtriangle.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.disliked ? .purple : .gray)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .padding(.leading, 16)
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
