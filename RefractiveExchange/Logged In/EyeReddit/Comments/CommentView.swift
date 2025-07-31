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

struct CommentView: View {
    
    @ObservedObject var viewModel: CommentModel
    @Environment(\.dismiss) var dismiss
    @State var commentText = ""
    @State var isLoading = false
    @ObservedObject var data: GetData
    @State private var showErrorToast: Bool = false
    
    
    
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
                let authorName = !data.user!.exchangeUsername.isEmpty ? data.user!.exchangeUsername : "\(data.user!.firstName) \(data.user!.lastName)"
                let comment = Comment(postId: viewModel.post.id!, text: trimmedCommentText, author: authorName, timestamp: Timestamp(date: Date()), upvotes: [], downvotes: [], uid: Auth.auth().currentUser?.uid ?? "")
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
        
        _ = try await Firestore.firestore().collection("comments").addDocument(data: docData)
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
                        
                        
                        if let urlString = viewModel.post.imageURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
    
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.95, alignment: .leading)
                    
                    Divider()
                    Text("Comments (\(self.viewModel.comments.count))")
                        .poppinsBold(18)
                        .multilineTextAlignment(.leading)
                    Divider()
                    LazyVStack(alignment: .leading, spacing: 0.5){
                        ForEach(viewModel.comments, id: \.timestamp) { comment in
                            CommentRow(comment: comment)
                                .padding()
                                .ignoresSafeArea()
                        }
                    }
                    .ignoresSafeArea()
                }
                Spacer()
                
                HStack  {
                    CustomTextField(text: $commentText, title: "Leave your thoughts...")
                        .frame(width: UIScreen.main.bounds.width * 0.75, height: 40)
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
    }
}
