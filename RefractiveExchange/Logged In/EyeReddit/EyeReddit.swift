//
//  EyeReddit.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/4/23.
//

import SwiftUI

struct EyeReddit: View {
    @ObservedObject var viewModel = FeedViewModel.shared
    @ObservedObject var data: GetData
    @State private var index = 0
    @State var isSidebarVisible: Bool = false
    @State var currentSubreddit = "i/All"
    @State private var isCreatePostViewPresented = false
    @State private var isEyeRedditAvailable = false
    @State private var displayEyeReddit = true
    @Binding var resetToHome: Bool
    @Binding var navigationPath: NavigationPath


    var tabItems = ["Feed", "New", "Profile"]
    var tabBarImages = ["list.bullet", "plus", "person"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if displayEyeReddit {
                //if viewModel.isEyeRedditAvailable {
                    VStack {
                        switch index {
                        case 0:
                            ZStack(alignment: .topLeading) {
                                FeedView(viewModel: viewModel, data: data, currentSubreddit: $currentSubreddit, isSidebarVisible: $isSidebarVisible, navigationPath: $navigationPath)
                            }
                        case 1:
                            Text("")
                        case 2:
                            ProfileView(data: data)
                        default:
                            Text("Error")
                        }
                        Spacer()
                        if index != 1 {
                            CustomTabBar(
                                selected: $index, 
                                tabItems: tabItems, 
                                tabBarImages: tabBarImages,
                                onTabSelected: { newIndex in
                                    if newIndex == 0 {
                                        // Reset to main feed
                                        if !navigationPath.isEmpty {
                                            navigationPath.removeLast(navigationPath.count)
                                        }
                                    }
                                    index = newIndex
                                }
                            )
                        }
                    }
                    .offset(x: isSidebarVisible ? 2*geometry.size.width / 3 : 0)
                    .onChange(of: index) { newIndex in
                        if newIndex == 1 {
                            isCreatePostViewPresented = true
                        }
                    }
                    .fullScreenCover(isPresented: $isCreatePostViewPresented) {
                        CreatePostView(subreddit: currentSubreddit, data: data, tabBarIndex: $index)
                    }
                } else {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Coming Soon!")
                                .poppinsMedium(24)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                if isSidebarVisible {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isSidebarVisible.toggle()
                        }
                    SideMenu(isShowing: $isSidebarVisible, content: AnyView(SideMenuView(presentSideMenu: $isSidebarVisible, currentSubreddit: $currentSubreddit, feedModel: viewModel)))
                        .transition(.move(edge: .leading))
                        .frame(width: 2*geometry.size.width / 3)
                        .position(x: geometry.size.width / 3, y: geometry.size.height / 2)
                }
            }
        }
        .animation(Animation.easeIn(duration: 0.2), value: isSidebarVisible)
        .onChange(of: resetToHome) { shouldReset in
            if shouldReset {
                index = 0  // Reset to main feed
                currentSubreddit = "i/All"  // Reset to main subreddit
                viewModel.currentSubreddit = "i/All"  // Update view model
                viewModel.refreshPosts()  // Refresh to show all posts
                resetToHome = false  // Reset the flag
            }
        }
    }
}
