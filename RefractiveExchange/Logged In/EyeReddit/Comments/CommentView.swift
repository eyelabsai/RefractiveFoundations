//
//  CommentView.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/7/23.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

// Note: NotificationService import will be added once the module is properly integrated

struct CommentView: View {
    
    @ObservedObject var viewModel: CommentModel
    @Environment(\.dismiss) var dismiss
    @State var commentText = ""
    @State var isLoading = false
    @ObservedObject var data: GetData
    @State private var showErrorToast: Bool = false
    @State private var selectedUserProfile: UserProfile?
    
    // Mention autocomplete states
    @State private var showingUserSuggestions = false
    @State private var userSuggestions: [User] = []
    @State private var mentionParser = MentionParser()
    
    
    
    init(post: FetchedPost, data: GetData)    {
        self.viewModel = CommentModel(post: post)
        self.data = data
    }
    
    func postComment() {
        let trimmedCommentText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommentText.isEmpty {
            showErrorToast = true
            return
        }
        
        
        isLoading = true
        Task {
            do {
                let firstName = data.user!.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let lastName = data.user!.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                let authorName = (!firstName.isEmpty || !lastName.isEmpty) ? 
                    "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines) :
                    (!data.user!.exchangeUsername.isEmpty ? data.user!.exchangeUsername : "Unknown User")
                let comment = Comment(postId: viewModel.post.id!, text: trimmedCommentText, author: authorName, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], uid: Auth.auth().currentUser?.uid ?? "", editedAt: nil)
                try await uploadFirebase(comment)
                commentText = ""
                refreshComments()
                
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } catch {
                isLoading = false
            }
        }
    }
    
    func uploadFirebase(_ comment: Comment) async throws {
        let docData: [String: Any] = [
            "postId": comment.postId,
            "text": comment.text,
            "author": comment.author,
            "timestamp": comment.timestamp,
            "upvotes": comment.upvotes,
            "downvotes": comment.downvotes,
            "uid": comment.uid
        ]
        
        let docRef = try await Firestore.firestore().collection("comments").addDocument(data: docData)
        
        // Parse mentions in the comment text and create notifications
        let mentionParser = MentionParser()
        mentionParser.parseMentions(in: comment.text) { parsedMentions in
            // Create mention notifications for each mentioned user
            for userId in parsedMentions.userIds {
                NotificationService.shared.createMentionNotification(
                    mentionerId: comment.uid ?? "",
                    mentionedUserId: userId,
                    contentId: docRef.documentID,
                    contentType: .comment,
                    contentText: comment.text,
                    postTitle: viewModel.post.title,
                    postId: viewModel.post.id
                )
            }
            
            if !parsedMentions.userIds.isEmpty {
                print("✅ Created mention notifications for \(parsedMentions.userIds.count) users in comment")
            }
        }
        
        // Create notification for post comment
        NotificationService.shared.createPostCommentNotification(
            postId: comment.postId,
            postAuthorId: viewModel.post.uid,
            commenterId: comment.uid ?? "",
            postTitle: viewModel.post.title,
            commentText: comment.text
        )
    }
    
    func refreshComments() {
        viewModel.fetchComments()
    }
    
    
    var body: some View {
        ZStack {
            VStack{
                ScrollView{
                    VStack {
                        if !self.viewModel.post.author.isEmpty  {
                            HStack(alignment: .top, spacing: 12) {
                                if let avatarUrlString = self.viewModel.post.avatarUrl, let url = URL(string: avatarUrlString) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Image("blank-avatar")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(self.viewModel.post.author)")
                                            .poppinsRegular(12)
                                        Text(self.viewModel.post.timestamp.dateValue().formatted())
                                            .poppinsRegular(12)
                                            .opacity(0.5)
                                        Text(self.viewModel.post.subreddit)
                                            .poppinsRegular(10)
                                            .foregroundColor(Color.black.opacity(0.3))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(self.viewModel.post.title)
                                            .poppinsBold(18)
                                            .multilineTextAlignment(.leading)
                                        Text(self.viewModel.post.text)
                                            .poppinsMedium(14)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(.leading, -44)
                                }
                            }
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.95, alignment: .leading)
                        }
                        
                        
                        if let imageURLs = viewModel.post.imageURLs, !imageURLs.isEmpty {
                            if imageURLs.count == 1 {
                                // Single image
                                if let url = URL(string: imageURLs[0]) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            } else {
                                // Multiple images - compact view
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                                            if let url = URL(string: urlString) {
                                                AsyncImage(url: url) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 120, height: 90)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                } placeholder: {
                                                    ProgressView()
                                                        .frame(width: 120, height: 90)
                                                        .background(Color(.systemGray6))
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                        }
    
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.95, alignment: .leading)
                    
                    Divider()
                    Text("Comments (\(self.viewModel.comments.count))")
                        .poppinsBold(18)
                        .multilineTextAlignment(.leading)
                    Divider()
                    LazyVStack(alignment: .leading, spacing: 8){
                        ForEach(viewModel.comments, id: \.timestamp) { comment in
                            CommentRow(
                                comment: comment,
                                onUsernameTapped: { username, userId in
                                    selectedUserProfile = UserProfile(username: username, userId: userId)
                                },
                                onCommentUpdated: {
                                    refreshComments()
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .ignoresSafeArea()
                }
                Spacer()
                
                VStack(spacing: 0) {
                    HStack  {
                        TextField("Leave your thoughts...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: UIScreen.main.bounds.width * 0.75, height: 40)
                            .onChange(of: commentText) { newValue in
                                checkForMentions(in: newValue)
                            }
                        Button {
                            postComment()
                        } label: {
                            Text("Post")
                                .bold()
                                .padding(.horizontal)
                                .padding(.vertical)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    
                    // User suggestions overlay
                    if showingUserSuggestions && !userSuggestions.isEmpty {
                        userSuggestionsView
                    }
                }
            }
            
            if showErrorToast {
                CustomToastView(text: "Comment can't be empty", opacity: 0.8, textColor: .black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
                    .onAppear(perform: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showErrorToast = false
                            }
                        }
                    })
                    .zIndex(1)
            }
        }
        .fullScreenCover(item: $selectedUserProfile) { userProfile in
            PublicProfileView(
                username: userProfile.username,
                userId: userProfile.userId,
                data: data
            )
        }
    }
    
    // MARK: - User Suggestions View
    private var userSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(userSuggestions, id: \.id) { user in
                Button(action: {
                    insertMention(user: user)
                }) {
                    HStack {
                        AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(user.firstName) \(user.lastName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("@\(!user.exchangeUsername.isEmpty ? user.exchangeUsername : "\(user.firstName)\(user.lastName)".replacingOccurrences(of: " ", with: "").lowercased())")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if user.id != userSuggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Mention Functions
    private func checkForMentions(in text: String) {
        print("🔍 CommentView: Checking for mentions in text: '\(text)'")
        
        // Find the last @ symbol and check if we're typing a username
        guard let lastAtIndex = text.lastIndex(of: "@") else {
            print("🔍 CommentView: No @ found, hiding suggestions")
            showingUserSuggestions = false
            return
        }
        
        let afterAtIndex = text.index(after: lastAtIndex)
        guard afterAtIndex < text.endIndex else {
            print("🔍 CommentView: Nothing after @, hiding suggestions")
            showingUserSuggestions = false
            return
        }
        
        let afterAt = text[afterAtIndex...]
        
        // Check if there's a space after the @ (if so, we're not in a mention anymore)
        if afterAt.contains(" ") || afterAt.contains("\n") {
            print("🔍 CommentView: Space/newline after @, hiding suggestions")
            showingUserSuggestions = false
            return
        }
        
        let currentPrefix = String(afterAt)
        print("🔍 CommentView: Current prefix: '\(currentPrefix)'")
        
        // Only search if we have at least 1 character after @
        if currentPrefix.count >= 1 {
            print("🔍 CommentView: Searching for users with prefix: '\(currentPrefix)'")
            mentionParser.searchUsers(with: currentPrefix) { users in
                DispatchQueue.main.async {
                    print("🔍 CommentView: Received \(users.count) users from search")
                    self.userSuggestions = users
                    self.showingUserSuggestions = !users.isEmpty
                    print("🔍 CommentView: showingUserSuggestions = \(self.showingUserSuggestions)")
                }
            }
        } else {
            print("🔍 CommentView: Prefix too short, hiding suggestions")
            showingUserSuggestions = false
        }
    }
    
    private func insertMention(user: User) {
        // Find the last @ and replace everything after it with the username
        guard let lastAtIndex = commentText.lastIndex(of: "@") else { return }
        
        let beforeAt = commentText[..<lastAtIndex]
        
        // Use exchangeUsername if available, otherwise create one from first/last name
        let username: String
        if !user.exchangeUsername.isEmpty {
            username = user.exchangeUsername
        } else {
            // Create username from first and last name (remove spaces, lowercase)
            username = "\(user.firstName)\(user.lastName)".replacingOccurrences(of: " ", with: "").lowercased()
        }
        
        let newText = beforeAt + "@\(username) "
        
        commentText = String(newText)
        showingUserSuggestions = false
    }
}
