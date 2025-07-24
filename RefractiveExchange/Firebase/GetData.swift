import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class GetData: ObservableObject {
    @Published var user: User?
    @Published var handle = AlertHandler()
    
    init() {
        fetchUser()
    }
    
    func fetchUser() {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ GetData: No authenticated user")
            return 
        }
        
        print("🔍 GetData: Fetching user document for UID: \(uid)")
        
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            if let error = error {
                print("❌ GetData: Error fetching user: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: User.self)
                    print("✅ GetData: Successfully loaded user: \(user.firstName) \(user.lastName)")
                    print("👤 GetData: User specialty: \(user.specialty)")
                    print("👤 GetData: User username: \(user.exchangeUsername ?? "none")")
                    DispatchQueue.main.async {
                        self?.user = user
                    }
                } catch {
                    print("❌ GetData: Error decoding user: \(error)")
                }
            } else {
                print("⚠️ GetData: User document doesn't exist for UID: \(uid)")
                print("💡 GetData: User might need to complete registration")
            }
        }
    }
    
    func updateUser(_ user: User) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            try Firestore.firestore().collection("users").document(uid).setData(from: user, merge: true)
            DispatchQueue.main.async {
                self.user = user
            }
        } catch {
            print("Error updating user: \(error)")
        }
    }
}

// Alert handling for UI feedback
class AlertHandler: ObservableObject {
    @Published var loading = false
    @Published var alert = false
    @Published var msg = ""
    
    func presentAlert(msg: String) {
        DispatchQueue.main.async {
            self.msg = msg
            self.alert = true
            self.loading = false
        }
    }
    
    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.loading = loading
        }
    }
} 