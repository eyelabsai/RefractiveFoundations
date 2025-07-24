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
        
        if currentSubreddit == "i/All"  {
            self.posts = allPosts
            print("✅ Showing all posts: \(posts.count)")
        } else  {
            self.posts = allPosts.filter({$0.subreddit == currentSubreddit})
            print("✅ Filtered posts: \(posts.count)")
            
            // Debug: Print all subreddits to see what we have
            let allSubreddits = Set(allPosts.map { $0.subreddit })
            print("🏷️ Available subreddits: \(allSubreddits)")
        }
    }
    
}
