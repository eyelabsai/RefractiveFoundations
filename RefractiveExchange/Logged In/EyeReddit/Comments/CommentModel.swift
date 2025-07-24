//
//  CommentModel.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/7/23.
//

import Foundation
import Firebase
import FirebaseFirestore

class CommentModel: ObservableObject {
    var post: FetchedPost
    @Published var comments: [Comment] = []
    @Published var allComments: [Comment] = []
    
    
    init(post: FetchedPost)    {
        self.post = post
        self.comments = []
        fetchComments()
    }
    
    
    func fetchComments() {
        Firestore.firestore().collection("comments")
            .whereField("postId", isEqualTo: post.id)
            .order(by: "timestamp", descending: true) 
            .addSnapshotListener { (querySnapshot, error) in
                guard let documents = querySnapshot?.documents else {
                    print("No comments found for post")
                    return
                }

                DispatchQueue.main.async {
                    self.comments = documents.compactMap { document in
                        try? document.data(as: Comment.self)
                    }
                }
            }
    }






    
    
    
}
