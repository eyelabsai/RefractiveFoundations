//
//  RefractiveFoundationsApp.swift
//  RefractiveFoundations
//
//  Created by Gurpal Virdi on 7/24/25.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Setup push notifications
        PushNotificationManager.shared.checkNotificationPermissionStatus()
        
        return true
    }
    
    // Handle APNs registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs device token received")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

@main
struct RefractiveFoundationsApp: App {
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
