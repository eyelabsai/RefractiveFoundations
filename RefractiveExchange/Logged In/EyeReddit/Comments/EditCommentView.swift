//
//  EditCommentView.swift
//  RefractiveExchange
//
//  Created by AI Assistant on 12/19/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EditCommentView: View {
    let comment: Comment
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedText: String
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let commentService = CommentService()
    
    init(comment: Comment, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.comment = comment
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedText = State(initialValue: comment.text)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Edit Comment")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editedText)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 120)
                        .padding(.horizontal)
                }
                
                // Character count
                HStack {
                    Text("\(editedText.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save button
                Button(action: saveComment) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSaving ? "Saving..." : "Save Changes")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveComment() {
        let trimmedText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            errorMessage = "Comment cannot be empty"
            showError = true
            return
        }
        
        isSaving = true
        
        commentService.editComment(comment, newText: trimmedText) { success in
            DispatchQueue.main.async {
                isSaving = false
                
                if success {
                    onSave(trimmedText)
                    onCancel() // Dismiss the edit view
                } else {
                    errorMessage = "Failed to save comment. Please try again."
                    showError = true
                }
            }
        }
    }
}

#Preview {
    let sampleComment = Comment(
        postId: "sample",
        text: "This is a sample comment",
        author: "TestUser",
        timestamp: Timestamp(date: Date()),
        uid: "test-uid"
    )
    
    EditCommentView(
        comment: sampleComment,
        onSave: { _ in },
        onCancel: { }
    )
} 