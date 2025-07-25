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
            
            VStack {
                top
                
                switch currentTab {
                case .eyeReddit:
                    EyeReddit(data: data, resetToHome: $resetEyeRedditToHome, navigationPath: $navigationPath)
                case .account:
                    ProfileView(data: data)
                }
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
            
            // App Logo/Title
            Text("Refractive Foundations")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.blue)
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// Simplified Tab Enum for Reddit-focused app
enum Tab {
    case eyeReddit
    case account
}

// Note: AccountView replaced with ProfileView for Reddit-style experience
