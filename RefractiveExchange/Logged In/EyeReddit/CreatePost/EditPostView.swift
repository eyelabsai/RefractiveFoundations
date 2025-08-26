//
//  EditPostView.swift
//  RefractiveExchange
//
//  Created by AI Assistant on 12/19/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EditPostView: View {
    let post: FetchedPost
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedText: String
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let postService = PostService()
    
    init(post: FetchedPost, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.post = post
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedText = State(initialValue: post.text)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Edit Post")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Post title (read-only)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Text(post.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                // Text editor for post content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editedText)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 200)
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
                Button(action: savePost) {
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
    
    private func savePost() {
        let trimmedText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            errorMessage = "Post content cannot be empty"
            showError = true
            return
        }
        
        isSaving = true
        
        postService.editPost(post, newText: trimmedText) { success in
            DispatchQueue.main.async {
                isSaving = false
                
                if success {
                    // Update UI state first
                    onSave(trimmedText)
                    // Then dismiss the view
                    onCancel()
                } else {
                    errorMessage = "Failed to save post. Please try again."
                    showError = true
                }
            }
        }
    }
}

#Preview {
    let samplePost = FetchedPost(
        title: "Sample Post Title",
        text: "This is a sample post content that can be edited.",
        timestamp: Timestamp(date: Date()),
        upvotes: [],
        downvotes: [],
        subreddit: "i/SampleSubreddit",
        imageURLs: nil,
        videoURLs: nil,
        didLike: false,
        didDislike: false,
        author: "TestUser",
        uid: "test-uid",
        avatarUrl: nil,
        editedAt: nil
    )
    
    EditPostView(
        post: samplePost,
        onSave: { _ in },
        onCancel: { }
    )
}