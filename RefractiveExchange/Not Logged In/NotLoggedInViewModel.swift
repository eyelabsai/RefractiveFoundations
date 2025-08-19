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
    @Published var loadingMessage = "Signing in..."
    @Published var errorMessage = ""
    
    func loginUser() {
        // Prevent multiple simultaneous login attempts
        guard !handle.loading else {
            print("⚠️ Login already in progress, ignoring duplicate attempt")
            return
        }
        
        // Trim whitespace and validate input
        let trimmedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear any previous error message
        errorMessage = ""
        
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            handle.setLoading(false) // Ensure loading is cleared
            return
        }
        
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address"
            handle.setLoading(false) // Ensure loading is cleared
            return
        }
        
        guard trimmedPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            handle.setLoading(false) // Ensure loading is cleared
            return
        }
        
        loadingMessage = "Signing in..."
        handle.setLoading(true)
        
        FirebaseManager.shared.signIn(email: trimmedEmail, password: trimmedPassword) { [weak self] result in
            DispatchQueue.main.async {
                print("🔄 Clearing loading state...")
                self?.handle.setLoading(false)
                print("🔄 Loading state cleared: \(self?.handle.loading ?? true)")
                
                switch result {
                case .success:
                    // Login successful - Firebase manager will handle state updates
                    print("✅ Login successful")
                    self?.errorMessage = "" // Clear any previous errors
                case .failure(let error):
                    print("❌ Login failed: \(error.localizedDescription)")
                    print("❌ Setting error message: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    // Double-check loading is cleared for errors
                    self?.handle.setLoading(false)
                    print("🔄 Loading definitely cleared after error: \(self?.handle.loading ?? true)")
                }
            }
        }
    }
    
    func sendResetEmail() {
        // Prevent multiple simultaneous reset attempts
        guard !handle.loading else {
            print("⚠️ Password reset already in progress, ignoring duplicate attempt")
            return
        }
        
        let trimmedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear any previous error message
        errorMessage = ""
        
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        loadingMessage = "Sending reset email..."
        handle.setLoading(true)
        
        FirebaseManager.shared.sendPasswordReset(email: trimmedEmail) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle.setLoading(false)
                
                switch result {
                case .success:
                    self?.handle.presentAlert(msg: "Password reset email sent! Please check your email and follow the instructions to reset your password.")
                    self?.resetPassword = false
                    self?.resetButtonText = "Log in"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
