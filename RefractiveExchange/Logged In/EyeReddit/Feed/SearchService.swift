//
//  SearchService.swift
//  RefractiveExchange
//
//  Created by Assistant on Date
//

import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

class SearchService: ObservableObject {
    static let shared = SearchService()
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    @Published var allComments: [Comment] = []
    
    private init() {
        fetchAllComments()
    }
    
    // MARK: - Client-side Search (Current Implementation)
    
    /// Performs advanced client-side search with multiple criteria including comments
    func searchPosts(
        posts: [FetchedPost],
        query: String,
        filters: SearchFilters
    ) -> [FetchedPost] {
        return SmartSearchEngine.searchWithComments(posts: posts, comments: allComments, query: query, filters: filters)
    }
    
    // MARK: - Server-side Search (Future Enhancement)
    
    /// Performs server-side search using Firestore queries
    /// This provides more comprehensive search across all posts in the database
    func performServerSearch(
        query: String,
        filters: SearchFilters,
        completion: @escaping ([FetchedPost]) -> Void
    ) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion([])
            return
        }
        
        print("🔍 Performing server-side search for: '\(query)'")
        
        var firestoreQuery: Query = db.collection("posts")
        
        // Apply filters to Firestore query
        if !filters.subreddit.isEmpty {
            firestoreQuery = firestoreQuery.whereField("subreddit", isEqualTo: filters.subreddit)
        }
        
        if !filters.author.isEmpty {
            firestoreQuery = firestoreQuery.whereField("author", isEqualTo: filters.author)
        }
        
        // Date range filtering
        if filters.dateRange != .all {
            let cutoffDate = getDateCutoff(for: filters.dateRange)
            firestoreQuery = firestoreQuery.whereField("timestamp", isGreaterThan: cutoffDate)
        }
        
        // Image filtering (if needed)
        if let hasImage = filters.hasImage {
            if hasImage {
                firestoreQuery = firestoreQuery.whereField("imageURL", isNotEqualTo: NSNull())
            } else {
                firestoreQuery = firestoreQuery.whereField("imageURL", isEqualTo: NSNull())
            }
        }
        
        // Limit results for performance
        firestoreQuery = firestoreQuery.limit(to: 100)
        
        firestoreQuery.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Server search error: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("📭 No documents found in server search")
                completion([])
                return
            }
            
            print("📥 Server search returned \(documents.count) documents")
            
            // Convert documents to FetchedPost objects
            let posts = documents.compactMap { document -> FetchedPost? in
                try? document.data(as: FetchedPost.self)
            }
            
            // Perform client-side text filtering on server results
            let filteredPosts = SmartSearchEngine.filterByText(posts: posts, query: query)
            
            print("✅ Server search completed with \(filteredPosts.count) results")
            DispatchQueue.main.async {
                completion(filteredPosts)
            }
        }
    }
    
    // MARK: - Search Analytics
    
    /// Tracks search queries for analytics and improvements
    func trackSearchQuery(_ query: String, resultCount: Int) {
        // This could be expanded to include Firebase Analytics
        print("📊 Search Analytics: '\(query)' returned \(resultCount) results")
        
        // Store in UserDefaults for local analytics
        var searchAnalytics = UserDefaults.standard.dictionary(forKey: "SearchAnalytics") as? [String: Any] ?? [:]
        searchAnalytics[query] = [
            "count": (searchAnalytics[query] as? [String: Any])?["count"] as? Int ?? 0 + 1,
            "lastSearched": Date(),
            "lastResultCount": resultCount
        ]
        UserDefaults.standard.set(searchAnalytics, forKey: "SearchAnalytics")
    }
    
    /// Gets popular search terms based on usage
    func getPopularSearchTerms() -> [String] {
        guard let analytics = UserDefaults.standard.dictionary(forKey: "SearchAnalytics") as? [String: [String: Any]] else {
            return []
        }
        
        return analytics
            .sorted { (first, second) in
                let firstCount = first.value["count"] as? Int ?? 0
                let secondCount = second.value["count"] as? Int ?? 0
                return firstCount > secondCount
            }
            .prefix(10)
            .map { $0.key }
    }
    
    // MARK: - Comment Fetching
    
    /// Fetches all comments from Firestore for search functionality
    private func fetchAllComments() {
        print("🔍 Fetching all comments for search...")
        
        db.collection("comments")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching comments for search: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 No comments found")
                    return
                }
                
                let comments = documents.compactMap { document -> Comment? in
                    try? document.data(as: Comment.self)
                }
                
                DispatchQueue.main.async {
                    self?.allComments = comments
                    print("✅ Loaded \(comments.count) comments for search")
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func getDateCutoff(for dateRange: SearchFilters.DateRange) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch dateRange {
        case .all:
            return Date.distantPast
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: now) ?? Date.distantPast
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? Date.distantPast
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? Date.distantPast
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? Date.distantPast
        }
    }
}

// MARK: - Search Filters (Shared with SearchViewModel)
struct SearchFilters {
    var subreddit: String = ""
    var author: String = ""
    var hasImage: Bool? = nil
    var dateRange: DateRange = .all
    
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case day = "Past Day"
        case week = "Past Week"
        case month = "Past Month"
        case year = "Past Year"
    }
}

// MARK: - Smart Search Engine
struct SmartSearchEngine {
    
    /// Main search function that includes comments in search
    static func searchWithComments(posts: [FetchedPost], comments: [Comment], query: String, filters: SearchFilters) -> [FetchedPost] {
        let searchTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return [] }
        
        // Find posts that match directly
        var matchingPosts = Set<String>()
        
        // Add posts that match in their content
        for post in posts {
            if applyFilters(post: post, filters: filters) &&
               matchesSearchTerms(post: post, searchTerms: searchTerms) {
                if let postId = post.id {
                    matchingPosts.insert(postId)
                }
            }
        }
        
        // Add posts whose comments match the search terms
        for comment in comments {
            if matchesSearchTermsInComment(comment: comment, searchTerms: searchTerms) {
                matchingPosts.insert(comment.postId)
            }
        }
        
        // Filter posts to only include matching ones and apply filters
        let filteredPosts = posts.filter { post in
            guard let postId = post.id else { return false }
            return matchingPosts.contains(postId) && applyFilters(post: post, filters: filters)
        }
        
        // Sort by relevance
        return filteredPosts.sorted { post1, post2 in
            let relevance1 = calculateRelevanceWithComments(post: post1, comments: comments, searchTerms: searchTerms)
            let relevance2 = calculateRelevanceWithComments(post: post2, comments: comments, searchTerms: searchTerms)
            
            if relevance1 != relevance2 {
                return relevance1 > relevance2
            }
            
            return post1.timestamp.dateValue() > post2.timestamp.dateValue()
        }
    }
    
    /// Legacy search function for backwards compatibility
    static func search(posts: [FetchedPost], query: String, filters: SearchFilters) -> [FetchedPost] {
        return searchWithComments(posts: posts, comments: [], query: query, filters: filters)
    }
    
    /// Filters posts by text query only (used for server search results)
    static func filterByText(posts: [FetchedPost], query: String) -> [FetchedPost] {
        let searchTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return posts }
        
        return posts
            .filter { post in
                matchesSearchTerms(post: post, searchTerms: searchTerms)
            }
            .sorted { post1, post2 in
                let relevance1 = calculateRelevance(post: post1, searchTerms: searchTerms)
                let relevance2 = calculateRelevance(post: post2, searchTerms: searchTerms)
                
                if relevance1 != relevance2 {
                    return relevance1 > relevance2
                }
                
                return post1.timestamp.dateValue() > post2.timestamp.dateValue()
            }
    }
    
    // MARK: - Private Methods
    
    private static func applyFilters(post: FetchedPost, filters: SearchFilters) -> Bool {
        if !filters.subreddit.isEmpty && post.subreddit.lowercased() != filters.subreddit.lowercased() {
            return false
        }
        
        if !filters.author.isEmpty && post.author.lowercased() != filters.author.lowercased() {
            return false
        }
        
        if let hasImage = filters.hasImage {
            let postHasImage = post.imageURL != nil && !post.imageURL!.isEmpty
            if hasImage != postHasImage {
                return false
            }
        }
        
        return isWithinDateRange(post: post, range: filters.dateRange)
    }
    
    private static func matchesSearchTerms(post: FetchedPost, searchTerms: [String]) -> Bool {
        let searchableText = [
            post.title,
            post.text,
            post.author,
            post.subreddit
        ].compactMap { $0 }.joined(separator: " ").lowercased()
        
        return searchTerms.allSatisfy { term in
            searchableText.contains(term) ||
            searchableText.range(of: term, options: .caseInsensitive) != nil ||
            isPhoneticMatch(searchableText: searchableText, term: term)
        }
    }
    
    private static func calculateRelevance(post: FetchedPost, searchTerms: [String]) -> Int {
        var score = 0
        let title = post.title.lowercased()
        let text = post.text.lowercased()
        let author = post.author.lowercased()
        let subreddit = post.subreddit.lowercased()
        
        for term in searchTerms {
            // Title matches are worth more
            if title.contains(term) {
                score += 10
                if title.hasPrefix(term) {
                    score += 5
                }
            }
            
            // Text matches
            if text.contains(term) {
                score += 3
            }
            
            // Author matches
            if author.contains(term) {
                score += 7
            }
            
            // Subreddit matches
            if subreddit.contains(term) {
                score += 5
            }
            
            // Exact word matches
            let words = [title, text, author, subreddit].joined(separator: " ").components(separatedBy: .whitespacesAndNewlines)
            if words.contains(term) {
                score += 8
            }
        }
        
        return score
    }
    
    private static func calculateRelevanceWithComments(post: FetchedPost, comments: [Comment], searchTerms: [String]) -> Int {
        var score = calculateRelevance(post: post, searchTerms: searchTerms)
        
        // Add comment relevance
        guard let postId = post.id else { return score }
        let postComments = comments.filter { $0.postId == postId }
        
        for comment in postComments {
            for term in searchTerms {
                let commentText = comment.text.lowercased()
                let commentAuthor = comment.author.lowercased()
                
                // Comment text matches (worth less than post content)
                if commentText.contains(term) {
                    score += 2
                }
                
                // Comment author matches
                if commentAuthor.contains(term) {
                    score += 4
                }
                
                // Exact word matches in comments
                let commentWords = [commentText, commentAuthor].joined(separator: " ").components(separatedBy: .whitespacesAndNewlines)
                if commentWords.contains(term) {
                    score += 3
                }
            }
        }
        
        return score
    }
    
    private static func matchesSearchTermsInComment(comment: Comment, searchTerms: [String]) -> Bool {
        let searchableText = [
            comment.text,
            comment.author
        ].joined(separator: " ").lowercased()
        
        return searchTerms.allSatisfy { term in
            searchableText.contains(term) ||
            searchableText.range(of: term, options: .caseInsensitive) != nil ||
            isPhoneticMatch(searchableText: searchableText, term: term)
        }
    }
    
    private static func isPhoneticMatch(searchableText: String, term: String) -> Bool {
        let phoneticPairs = [
            ("ph", "f"), ("ck", "k"), ("s", "z"), ("c", "k"),
            ("i", "y"), ("ei", "ai"), ("ou", "u")
        ]
        
        var modifiedTerm = term
        for (original, replacement) in phoneticPairs {
            modifiedTerm = modifiedTerm.replacingOccurrences(of: original, with: replacement)
        }
        
        return searchableText.contains(modifiedTerm) && modifiedTerm != term
    }
    
    private static func isWithinDateRange(post: FetchedPost, range: SearchFilters.DateRange) -> Bool {
        let postDate = post.timestamp.dateValue()
        let now = Date()
        
        switch range {
        case .all:
            return true
        case .day:
            return postDate > Calendar.current.date(byAdding: .day, value: -1, to: now) ?? Date.distantPast
        case .week:
            return postDate > Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) ?? Date.distantPast
        case .month:
            return postDate > Calendar.current.date(byAdding: .month, value: -1, to: now) ?? Date.distantPast
        case .year:
            return postDate > Calendar.current.date(byAdding: .year, value: -1, to: now) ?? Date.distantPast
        }
    }
} 