//
//  PushNotificationManager.swift
//  RefractiveExchange
//
//  Created for push notification functionality
//

import Foundation
import UserNotifications
import Firebase
import FirebaseAuth
import FirebaseMessaging
import UIKit

class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var isAuthorized = false
    @Published var fcmToken: String?
    
    private override init() {
        super.init()
        setupFirebaseMessaging()
    }
    
    // MARK: - Setup
    
    private func setupFirebaseMessaging() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permission Request
    
    func requestNotificationPermission() {
        print("🔔 Requesting notification permission...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error requesting notification permission: \(error.localizedDescription)")
                    return
                }
                
                self?.isAuthorized = granted
                print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
                
                if granted {
                    self?.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Token Management
    
    func getFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let token = token else {
                print("❌ FCM token is nil")
                return
            }
            
            DispatchQueue.main.async {
                self?.fcmToken = token
                print("✅ FCM Token: \(token)")
                self?.saveFCMTokenToFirestore(token)
            }
        }
    }
    
    private func saveFCMTokenToFirestore(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user to save FCM token")
            return
        }
        
        let data: [String: Any] = [
            "fcmToken": token,
            "lastUpdated": Timestamp()
        ]
        
        Firestore.firestore().collection("users").document(userId).setData(data, merge: true) { error in
            if let error = error {
                print("❌ Error saving FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token saved to Firestore")
            }
        }
    }
    
    // MARK: - Check Permission Status
    
    func checkNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
                
                switch settings.authorizationStatus {
                case .notDetermined:
                    print("🔔 Notification permission not determined")
                case .denied:
                    print("❌ Notification permission denied")
                case .authorized:
                    print("✅ Notification permission authorized")
                case .provisional:
                    print("🔔 Notification permission provisional")
                case .ephemeral:
                    print("🔔 Notification permission ephemeral")
                @unknown default:
                    print("🔔 Unknown notification permission status")
                }
            }
        }
    }
    
    // MARK: - Send Push Notification
    
    func sendPushNotification(to userId: String, title: String, body: String, data: [String: Any] = [:]) {
        // Get the user's FCM token
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching user FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  document.exists,
                  let fcmToken = document.data()?["fcmToken"] as? String else {
                print("❌ No FCM token found for user: \(userId)")
                return
            }
            
            self.sendNotificationToToken(fcmToken, title: title, body: body, data: data)
        }
    }
    
    private func sendNotificationToToken(_ token: String, title: String, body: String, data: [String: Any]) {
        // Note: In a production app, you would typically send this to your backend server
        // which would then use the Firebase Admin SDK to send the notification.
        // For demonstration purposes, this shows the structure of what would be sent.
        
        let payload: [String: Any] = [
            "to": token,
            "notification": [
                "title": title,
                "body": body,
                "sound": "default"
            ],
            "data": data
        ]
        
        print("📤 Would send push notification payload: \(payload)")
        
        // TODO: Implement server-side push notification sending
        // This requires a backend service with Firebase Admin SDK
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 FCM registration token: \(fcmToken ?? "nil")")
        
        DispatchQueue.main.async {
            self.fcmToken = fcmToken
            if let token = fcmToken {
                self.saveFCMTokenToFirestore(token)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📱 Received notification in foreground: \(notification.request.content.title)")
        
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("👆 User tapped notification: \(response.notification.request.content.title)")
        
        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        print("🔄 Handling notification tap with userInfo: \(userInfo)")
        
        // Extract notification data and navigate appropriately
        if let postId = userInfo["postId"] as? String {
            // Navigate to post
            NotificationCenter.default.post(name: .navigateToPost, object: postId)
        } else if let conversationId = userInfo["conversationId"] as? String {
            // Navigate to conversation
            NotificationCenter.default.post(name: .navigateToConversation, object: conversationId)
        }
    }
}

// MARK: - Notification Names for Navigation
extension Notification.Name {
    static let navigateToPost = Notification.Name("navigateToPost")
    static let navigateToConversation = Notification.Name("navigateToConversation")
}
