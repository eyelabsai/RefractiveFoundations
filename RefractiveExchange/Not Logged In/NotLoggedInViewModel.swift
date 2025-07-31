//
//  NotLoggedInViewModel.swift
//  IOL CON
//

//

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth

class NotLoggedInViewModel: ObservableObject {
    @Published var user = User()
    @Published var password = ""
    @Published var resetPassword = false
    @Published var resetButtonText = "Log in"
    @Published var handle = AlertHandler()
    
    func loginUser() {
        // Trim whitespace and validate input
        let trimmedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            handle.presentAlert(msg: "Please fill in all fields")
            return
        }
        
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            handle.presentAlert(msg: "Please enter a valid email address")
            return
        }
        
        guard trimmedPassword.count >= 6 else {
            handle.presentAlert(msg: "Password must be at least 6 characters")
            return
        }
        
        handle.setLoading(true)
        
        FirebaseManager.shared.signIn(email: trimmedEmail, password: trimmedPassword) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle.setLoading(false)
                
                switch result {
                case .success:
                    // Login successful - Firebase manager will handle state updates
                    print("✅ Login successful")
                    break
                case .failure(let error):
                    print("❌ Login failed: \(error.localizedDescription)")
                    self?.handle.presentAlert(msg: error.localizedDescription)
                }
            }
        }
    }
    
    func sendResetEmail() {
        let trimmedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            handle.presentAlert(msg: "Please enter your email address")
            return
        }
        
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            handle.presentAlert(msg: "Please enter a valid email address")
            return
        }
        
        handle.setLoading(true)
        
        FirebaseManager.shared.sendPasswordReset(email: trimmedEmail) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle.setLoading(false)
                
                switch result {
                case .success:
                    self?.handle.presentAlert(msg: "Password reset email sent successfully")
                    self?.resetPassword = false
                    self?.resetButtonText = "Log in"
                case .failure(let error):
                    self?.handle.presentAlert(msg: error.localizedDescription)
                }
            }
        }
    }
}
