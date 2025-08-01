//
//  SearchViewModel.swift
//  RefractiveExchange
//
//  Created by Assistant on Date
//

import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults = [FetchedPost]()
    @Published var isSearching = false
    @Published var recentSearches = [String]()

    @Published var selectedFilters = SearchFilters()
    
    private var allPosts = [FetchedPost]()
    private var cancellables = Set<AnyCancellable>()
    private let feedViewModel = FeedViewModel.shared
    private let searchService = SearchService.shared
    
    init() {
        setupSearchDebouncing()
        loadRecentSearches()
        
        // Subscribe to feed updates
        feedViewModel.$allPosts
            .sink { [weak self] posts in
                guard let self = self else { return }
                self.allPosts = posts
                if !self.searchText.isEmpty {
                    self.performSearch()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to comment updates for real-time search
        searchService.$allComments
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.searchText.isEmpty {
                    self.performSearch()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSearchDebouncing() {
        // Debounce search to avoid excessive filtering
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let filtered = self.searchService.searchPosts(posts: self.allPosts, query: self.searchText, filters: self.selectedFilters)
            
            DispatchQueue.main.async {
                self.searchResults = filtered
                self.isSearching = false
                self.saveRecentSearch(self.searchText)
                self.searchService.trackSearchQuery(self.searchText, resultCount: filtered.count)
            }
        }
    }
    


    
    // MARK: - Recent Searches
    private func saveRecentSearch(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !recentSearches.contains(trimmed) else { return }
        
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "RecentSearches")
    }
    
    // MARK: - Filter Management
    func applyFilters(_ filters: SearchFilters) {
        selectedFilters = filters
        performSearch()
    }
    
    func clearFilters() {
        selectedFilters = SearchFilters()
        performSearch()
    }
    

} 