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
    @State var isSidebarVisible: Bool = false
    @State var currentSubreddit = "i/All"
    @State private var isEyeRedditAvailable = false
    @State private var displayEyeReddit = true
    @Binding var resetToHome: Bool
    @Binding var navigationPath: NavigationPath

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if displayEyeReddit {
                //if viewModel.isEyeRedditAvailable {
                    VStack {
                        // Only show FeedView since navigation is now handled by Main.swift
                        ZStack(alignment: .topLeading) {
                            FeedView(viewModel: viewModel, data: data, currentSubreddit: $currentSubreddit, isSidebarVisible: $isSidebarVisible, navigationPath: $navigationPath)
                        }
                    }
                    .offset(x: isSidebarVisible ? 2*geometry.size.width / 3 : 0)
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
                currentSubreddit = "i/All"  // Reset to main subreddit
                viewModel.setSubreddit(subreddit: "i/All")  // Update view model properly
                viewModel.filterBySubreddit()  // Apply the filter immediately
                viewModel.refreshPosts()  // Refresh to get latest posts
                resetToHome = false  // Reset the flag
            }
        }
    }
}
