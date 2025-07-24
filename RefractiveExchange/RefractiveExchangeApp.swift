//
//  RefractiveExchangeApp.swift
//  RefractiveExchange
//
//  Created by Gurpal Virdi on 7/24/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct RefractiveExchangeApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var darkModeManager = DarkModeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(darkModeManager)
                .environment(\.darkModeManager, darkModeManager)
        }
    }
}
