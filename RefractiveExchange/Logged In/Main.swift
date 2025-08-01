import SwiftUI

struct Main: View {
    
    @StateObject var data = GetData()
    
    @State var searchActivated = false
    @State var currentTab: Tab = .eyeReddit
    @State var searchBar = ""
    @State var resetEyeRedditToHome = false
    @State var navigationPath = NavigationPath()
    @Namespace var animation
    
    var body: some View {
        
        ZStack {
            
            VStack(spacing: 0) {
                top
                
                switch currentTab {
                case .eyeReddit:
                    EyeReddit(data: data, resetToHome: $resetEyeRedditToHome, navigationPath: $navigationPath)
                case .messages:
                    ConversationListView()
                case .newPost:
                    CreatePostView(data: data, tabBarIndex: Binding(
                        get: { currentTab == .eyeReddit ? 0 : 1 },
                        set: { newValue in
                            if newValue == 0 {
                                withAnimation {
                                    currentTab = .eyeReddit
                                    resetEyeRedditToHome = true
                                }
                            }
                        }
                    ))
                case .account:
                    ProfileView(data: data)
                }
                
                bottomTabBar
            }
            .zIndex(0)
            
            CustomLoading(handle: $data.handle)
                .zIndex(2)
            
            CustomAlert(handle: $data.handle)
                .zIndex(3)
        }
    }
    
    var top: some View {
        HStack {
            // Home button always visible - takes you to main feed
            Button {
                withAnimation { 
                    // Clear any navigation stacks first
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast(navigationPath.count)
                    }
                    currentTab = .eyeReddit
                    resetEyeRedditToHome = true
                }
            } label: {
                Image(systemName: "homekit")
                    .imageScale(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 5)
            
            Spacer()
            
            Spacer()
            
            // DM button (Instagram-style message)
            Button {
                withAnimation {
                    currentTab = .messages
                }
            } label: {
                Image(systemName: "paperplane")
                    .imageScale(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.trailing, 5)
        }
        .padding(.horizontal)
        .frame(height: 44) // Fixed height to prevent layout shifts
        .overlay(
            // App Logo - overlaid in center without affecting layout, clickable link
            Link(destination: URL(string: "https://refractivefoundations.com/")!) {
                Image("RF Icon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 95, height: 95)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        )
    }
    
    var bottomTabBar: some View {
        HStack {
            // Home/Feed Tab
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: currentTab == .eyeReddit,
                action: {
                    withAnimation {
                        if !navigationPath.isEmpty {
                            navigationPath.removeLast(navigationPath.count)
                        }
                        currentTab = .eyeReddit
                        resetEyeRedditToHome = true
                    }
                }
            )
            
            Spacer()
            
            // New Post Tab (middle)
            TabBarButton(
                icon: "plus",
                title: "New Post",
                isSelected: currentTab == .newPost,
                action: {
                    withAnimation {
                        currentTab = .newPost
                    }
                }
            )
            
            Spacer()
            
            // Profile Tab
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: currentTab == .account,
                action: {
                    withAnimation {
                        currentTab = .account
                    }
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
            , alignment: .top
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
        .frame(minWidth: 60)
    }
}

// Simplified Tab Enum for Reddit-focused app
enum Tab {
    case eyeReddit
    case messages
    case newPost
    case account
}

// Note: AccountView replaced with ProfileView for Reddit-style experience