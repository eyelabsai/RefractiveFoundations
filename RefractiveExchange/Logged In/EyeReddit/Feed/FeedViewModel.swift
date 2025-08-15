//
//  FeedViewModel.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/6/23.
//

import Foundation

class FeedViewModel: ObservableObject   {
    static let shared = FeedViewModel()
    @Published var posts = [FetchedPost]()
    @Published var allPosts = [FetchedPost]()
    @Published var isEyeRedditAvailable: Bool = false
    var currentSubreddit: String = "i/All"
    let service = PostService()
    
    private init()  {
        refreshPosts()
        filterBySubreddit()
    }
    
    func setSubreddit(subreddit: String)    {
        self.currentSubreddit = subreddit
    }
    
    func refreshPosts() {
        print("🔄 Refreshing posts...")
        // Clear existing posts to force fresh fetch
        self.posts = []
        self.allPosts = []
        
        service.fetchPosts { posts in
            print("📥 Fetched \(posts.count) posts from Firebase")
            DispatchQueue.main.async {
                self.allPosts = posts
                self.filterBySubreddit()
                print("✅ Feed updated with \(self.posts.count) posts for subreddit: \(self.currentSubreddit)")
            }
        }
    }
    
    func filterBySubreddit()  {
        print("🔍 Filtering posts for subreddit: '\(currentSubreddit)'")
        print("📊 Total posts available: \(allPosts.count)")
        
        var filteredPosts: [FetchedPost]
        
        if currentSubreddit == "i/All"  {
            filteredPosts = allPosts
            print("✅ Showing all posts: \(filteredPosts.count)")
        } else  {
            filteredPosts = allPosts.filter({$0.subreddit == currentSubreddit})
            print("✅ Filtered posts: \(filteredPosts.count)")
            
            // Debug: Print all subreddits to see what we have
            let allSubreddits = Set(allPosts.map { $0.subreddit })
            print("🏷️ Available subreddits: \(allSubreddits)")
        }
        
        // Sort posts: Pinned posts first (by pinned date), then regular posts by timestamp
        self.posts = filteredPosts.sorted { post1, post2 in
            let isPinned1 = post1.isPinned ?? false
            let isPinned2 = post2.isPinned ?? false
            
            // If both pinned or both not pinned, sort by timestamp (newer first)
            if isPinned1 == isPinned2 {
                return post1.timestamp.dateValue() > post2.timestamp.dateValue()
            }
            
            // Pinned posts come first
            return isPinned1 && !isPinned2
        }
        
        let pinnedCount = posts.filter { $0.isPinned ?? false }.count
        if pinnedCount > 0 {
            print("📌 \(pinnedCount) pinned posts at top of feed")
        }
    }
    
    func updatePost(_ updatedPost: FetchedPost) {
        guard let postId = updatedPost.id else { return }
        
        // Update in allPosts (@Published will automatically trigger UI updates)
        if let index = allPosts.firstIndex(where: { $0.id == postId }) {
            allPosts[index] = updatedPost
        }
        
        // Update in filtered posts (@Published will automatically trigger UI updates)
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index] = updatedPost
        }
    }
    
}
