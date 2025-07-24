//
//  FeedView.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/6/23.
//

import SwiftUI

struct FeedView: View {
    @ObservedObject var viewModel = FeedViewModel.shared
    @ObservedObject var data: GetData
    @EnvironmentObject var darkModeManager: DarkModeManager
    @State var showNewPostView: Bool = false
    @Binding var currentSubreddit: String
    @Binding var isSidebarVisible: Bool
    @Binding var navigationPath: NavigationPath

    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing)  {
                VStack(spacing: 0) {
                    // Reddit-style header
                    HStack {
                        Button(action: {
                            withAnimation {
                                isSidebarVisible.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                        
                        Text(currentSubreddit)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // Dark Mode Toggle
                            Button(action: {
                                darkModeManager.toggleDarkMode()
                            }) {
                                Image(systemName: darkModeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(darkModeManager.isDarkMode ? .yellow : .purple)
                            }
                            
                            // Search button (Reddit has this)
                            Button(action: {
                                // Search functionality
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color(.separator))
                        , alignment: .bottom
                    )
                    
                    ScrollView{
                        LazyVStack(alignment: .leading, spacing: 2){
                            ForEach(viewModel.posts) { post in
                                PostRow(
                                    post: post,
                                    onCommentTapped: {
                                        navigationPath.append(post)
                                    },
                                    onPostTapped: {
                                        navigationPath.append(post)
                                    }
                                )
                                .background(Color(.systemBackground))
                            }
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                    .refreshable {
                        viewModel.refreshPosts()
                    }
                }
            }
            .onAppear{
                viewModel.refreshPosts()
            }
            .navigationDestination(for: FetchedPost.self) { post in
                PostDetailView(post: post, data: data)
            }
        }
    }

}
