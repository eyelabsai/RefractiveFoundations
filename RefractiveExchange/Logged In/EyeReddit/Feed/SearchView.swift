//
//  SearchView.swift
//  RefractiveExchange
//
//  Created by Assistant on Date
//

import SwiftUI

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @ObservedObject var data: GetData
    @EnvironmentObject var darkModeManager: DarkModeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilters = false
    @State private var searchFieldFocused = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Search Content
                if searchViewModel.searchText.isEmpty {
                    searchSuggestionsView
                } else if searchViewModel.isSearching {
                    searchingView
                } else if searchViewModel.searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsView
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(filters: $searchViewModel.selectedFilters)
                    .environmentObject(darkModeManager)
            }
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search posts, users, subreddits...", text: $searchViewModel.searchText)
                        .focused($isSearchFieldFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.search)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            searchViewModel.performSearch()
                        }
                    
                    if !searchViewModel.searchText.isEmpty {
                        Button(action: {
                            searchViewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Filter button
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(hasActiveFilters ? .blue : .primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Active filters indicator
            if hasActiveFilters {
                activeFiltersView
            }
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Active Filters
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !searchViewModel.selectedFilters.subreddit.isEmpty {
                    filterChip(title: "r/\(searchViewModel.selectedFilters.subreddit)", onRemove: {
                        searchViewModel.selectedFilters.subreddit = ""
                        searchViewModel.performSearch()
                    })
                }
                
                if !searchViewModel.selectedFilters.author.isEmpty {
                    filterChip(title: "by \(searchViewModel.selectedFilters.author)", onRemove: {
                        searchViewModel.selectedFilters.author = ""
                        searchViewModel.performSearch()
                    })
                }
                
                if let hasImage = searchViewModel.selectedFilters.hasImage {
                    filterChip(title: hasImage ? "Has Image" : "Text Only", onRemove: {
                        searchViewModel.selectedFilters.hasImage = nil
                        searchViewModel.performSearch()
                    })
                }
                
                if searchViewModel.selectedFilters.dateRange != .all {
                    filterChip(title: searchViewModel.selectedFilters.dateRange.rawValue, onRemove: {
                        searchViewModel.selectedFilters.dateRange = .all
                        searchViewModel.performSearch()
                    })
                }
                
                Button(action: {
                    searchViewModel.clearFilters()
                }) {
                    Text("Clear All")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    private func filterChip(title: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .cornerRadius(4)
    }
    
    // MARK: - Search Suggestions
    private var searchSuggestionsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !searchViewModel.recentSearches.isEmpty {
                    sectionHeader("Recent Searches") {
                        Button("Clear All") {
                            searchViewModel.clearRecentSearches()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    ForEach(searchViewModel.recentSearches, id: \.self) { search in
                        suggestionRow(
                            icon: "clock",
                            title: search,
                            subtitle: "Recent search"
                        ) {
                            searchViewModel.searchText = search
                            searchViewModel.performSearch()
                        }
                    }
                }
                

                
                // Quick filter suggestions
                sectionHeader("Quick Filters", action: nil)
                
                suggestionRow(icon: "photo", title: "Posts with images", subtitle: "Show only image posts") {
                    searchViewModel.selectedFilters.hasImage = true
                    searchViewModel.performSearch()
                }
                
                suggestionRow(icon: "clock", title: "Recent posts", subtitle: "Past 24 hours") {
                    searchViewModel.selectedFilters.dateRange = .day
                    searchViewModel.performSearch()
                }
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Results header
            HStack {
                Text("\(searchViewModel.searchResults.count) result\(searchViewModel.searchResults.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            
            // Results list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(searchViewModel.searchResults) { post in
                        NavigationLink(destination: PostDetailView(post: post, data: data)) {
                            SearchResultCard(post: post, searchQuery: searchViewModel.searchText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Loading & Empty States
    private var searchingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No results found")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Try different keywords or check your filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Clear Filters") {
                searchViewModel.clearFilters()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String, action: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let action = action {
                Button("Clear All", action: action)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func suggestionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var hasActiveFilters: Bool {
        !searchViewModel.selectedFilters.subreddit.isEmpty ||
        !searchViewModel.selectedFilters.author.isEmpty ||
        searchViewModel.selectedFilters.hasImage != nil ||
        searchViewModel.selectedFilters.dateRange != .all
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let post: FetchedPost
    let searchQuery: String
    @EnvironmentObject var darkModeManager: DarkModeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with subreddit and metadata
            HStack {
                Text("r/\(post.subreddit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("u/\(post.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(timeAgoString(from: post.timestamp.dateValue()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Post title
            Text(post.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            
            // Post content preview (if available)
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Image preview (if available)
            if let imageURLs = post.imageURLs, !imageURLs.isEmpty {
                HStack {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(imageURLs.count == 1 ? "Image" : "\(imageURLs.count) Images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            // Bottom row with engagement metrics
            HStack(spacing: 16) {
                // Upvotes
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(post.upvotes.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Comments indicator
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Comments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Search match indicator
                if isSearchMatch {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Match")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
    
    private var isSearchMatch: Bool {
        let query = searchQuery.lowercased()
        let searchableText = [post.title, post.text, post.author, post.subreddit]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        
        return searchableText.contains(query)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Search Filters View
struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var darkModeManager: DarkModeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section("Content Type") {
                    Picker("Image Filter", selection: Binding<Int>(
                        get: { 
                            if filters.hasImage == nil { return 0 }
                            return filters.hasImage! ? 1 : 2
                        },
                        set: { newValue in
                            switch newValue {
                            case 0: filters.hasImage = nil
                            case 1: filters.hasImage = true
                            case 2: filters.hasImage = false
                            default: filters.hasImage = nil
                            }
                        }
                    )) {
                        Text("All Posts").tag(0)
                        Text("With Images").tag(1)
                        Text("Text Only").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Time Range") {
                    Picker("Date Range", selection: $filters.dateRange) {
                        ForEach(SearchFilters.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Filter by") {
                    HStack {
                        Text("Subreddit")
                        TextField("Enter subreddit name", text: $filters.subreddit)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Author")
                        TextField("Enter username", text: $filters.author)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
} 