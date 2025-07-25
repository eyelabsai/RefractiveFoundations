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
                // User is logged in - show main Reddit app
                Main()
                    .onAppear {
                        darkModeManager.applyTheme() // Restore user preference
                    }
            } else {
                // User is not logged in - show authentication
                NavigationView {
                    LoginScreen()
                }
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
    }
}

#Preview {
    ContentView()
}
