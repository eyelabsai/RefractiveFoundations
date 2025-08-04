//
//  ContentView.swift
//  RefractiveFoundations
//
//  Created by Gurpal Virdi on 7/24/25.
//

import SwiftUI
import Firebase

struct ContentView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showMainApp = false
    @EnvironmentObject var darkModeManager: DarkModeManager
    
    var body: some View {
        Group {
            if firebaseManager.isUserAuthenticated {
                // User is logged in - check onboarding status
                if shouldShowOnboarding {
                    OnboardingView {
                        firebaseManager.markOnboardingCompleted()
                    }
                    .transition(.opacity)
                } else {
                    // User has completed onboarding - show main app
                    Main()
                        .onAppear {
                            darkModeManager.applyTheme() // Restore user preference
                        }
                }
            } else {
                // User is not logged in - show authentication
                NavigationView {
                    LoginScreen(model: NotLoggedInViewModel())
                }
                .navigationViewStyle(StackNavigationViewStyle()) // Force single column layout
                .onAppear {
                    // Force light mode when logged out
                    DispatchQueue.main.async {
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                        for window in windowScene.windows {
                            window.overrideUserInterfaceStyle = .light
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: shouldShowOnboarding)
    }
    
    private var shouldShowOnboarding: Bool {
        guard let currentUser = firebaseManager.currentUser else { return false }
        return currentUser.hasCompletedOnboarding != true
    }
}

#Preview {
    ContentView()
}
