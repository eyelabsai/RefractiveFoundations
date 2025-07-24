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
        guard !user.email.isEmpty, !password.isEmpty else {
            handle.presentAlert(msg: "Please fill in all fields")
            return
        }
        
        handle.setLoading(true)
        
        FirebaseManager.shared.signIn(email: user.email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle.setLoading(false)
                
                switch result {
                case .success:
                    // Login successful - Firebase manager will handle state updates
                    break
                case .failure(let error):
                    self?.handle.presentAlert(msg: error.localizedDescription)
                }
            }
        }
    }
    
    func sendResetEmail() {
        guard !user.email.isEmpty else {
            handle.presentAlert(msg: "Please enter your email address")
            return
        }
        
        handle.setLoading(true)
        
        FirebaseManager.shared.sendPasswordReset(email: user.email) { [weak self] result in
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
