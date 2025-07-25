//
//  SignupScreen.swift
//  RefractiveExchange
//
//  Created by Gurpal Virdi on 7/24/25.
//

import SwiftUI
import Firebase

struct SignupScreen: View {
    @StateObject private var viewModel = SignupViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                
                // App Icon
                Image("144")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.top, 20)
                
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 10)
                
                VStack(spacing: 15) {
                    CustomTextField(text: $viewModel.firstName, title: "First Name")
                    CustomTextField(text: $viewModel.lastName, title: "Last Name")
                    CustomTextField(text: $viewModel.email, title: "Email")
                    
                    // Specialty picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Medical Specialty")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Picker("Specialty", selection: $viewModel.selectedSpecialty) {
                            ForEach(viewModel.specialties, id: \.self) { specialty in
                                Text(specialty).tag(specialty)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    CustomTextField(text: $viewModel.username, title: "Username")
                    CustomTextField(text: $viewModel.password, title: "Password", isPassword: true)
                    CustomTextField(text: $viewModel.confirmPassword, title: "Confirm Password", isPassword: true)
                }
                
                CustomButton(
                    loading: $viewModel.handle.loading,
                    title: .constant("Create Account"),
                    width: .constant(UIScreen.main.bounds.width - 50),
                    color: .blue,
                    action: {
                        viewModel.createAccount()
                    }
                )
                .padding(.top, 20)
                
                HStack(spacing: 5) {
                    Text("Already have an account?")
                        .foregroundColor(.black)
                        .font(.system(size: 16, weight: .medium))
                    
                    Button("Sign In") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .zIndex(0)
            
            CustomAlert(handle: $viewModel.handle)
                .zIndex(1)
        }
        .navigationBarHidden(true)
    }
}

class SignupViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var username = ""
    @Published var selectedSpecialty = "General Ophthalmology"
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var handle = AlertHandler()
    
    let specialties = [
        "General Ophthalmology",
        "Anterior Segment, Cataract, & Cornea",
        "Glaucoma", 
        "Retina",
        "Neuro-Ophthalmology",
        "Pediatric Ophthalmology",
        "Ocular Oncology",
        "Oculoplastic Surgery",
        "Uveitis",
        "Resident/Fellow",
        "Medical Student",
        "Other"
    ]
    
    func createAccount() {
        // Validation
        guard !firstName.isEmpty else {
            handle.presentAlert(msg: "Please enter your first name")
            return
        }
        
        guard !lastName.isEmpty else {
            handle.presentAlert(msg: "Please enter your last name")
            return
        }
        
        guard !email.isEmpty else {
            handle.presentAlert(msg: "Please enter your email")
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            handle.presentAlert(msg: "Please enter a valid email address")
            return
        }
        
        guard !password.isEmpty else {
            handle.presentAlert(msg: "Please enter a password")
            return
        }
        
        guard password.count >= 6 else {
            handle.presentAlert(msg: "Password must be at least 6 characters")
            return
        }
        
        guard password == confirmPassword else {
            handle.presentAlert(msg: "Passwords don't match")
            return
        }
        
        guard !username.isEmpty else {
            handle.presentAlert(msg: "Please enter a username")
            return
        }
        
        handle.setLoading(true)
        
        // Check if username is already taken
        let usersRef = Firestore.firestore().collection("users")
        usersRef.whereField("exchangeUsername", isEqualTo: username).getDocuments { [weak self] snapshot, error in
            if let error = error {
                self?.handle.setLoading(false)
                self?.handle.presentAlert(msg: "Error checking username: \(error.localizedDescription)")
                return
            }
            if let docs = snapshot?.documents, !docs.isEmpty {
                self?.handle.setLoading(false)
                self?.handle.presentAlert(msg: "Username is already taken. Please choose another.")
                return
            }
            // Username is unique, proceed with signup
            FirebaseManager.shared.signUp(
                email: self?.email ?? "",
                password: self?.password ?? "",
                firstName: self?.firstName ?? "",
                lastName: self?.lastName ?? "",
                specialty: self?.selectedSpecialty ?? "",
                username: self?.username ?? ""
            ) { result in
                DispatchQueue.main.async {
                    self?.handle.setLoading(false)
                    switch result {
                    case .success:
                        // Account created successfully - Firebase manager will handle state updates
                        break
                    case .failure(let error):
                        self?.handle.presentAlert(msg: error.localizedDescription)
                    }
                }
            }
        }
    }
}
