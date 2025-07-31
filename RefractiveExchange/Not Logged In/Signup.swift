//
//  SignupScreen.swift
//  RefractiveExchange
//
//  Created by Gurpal Virdi on 7/25/25.
//

import SwiftUI
import Firebase

struct ElegantLoadingView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(rotation))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                }
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: scale)
                
                Text("Creating your account...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
        }
        .onAppear {
            rotation = 360
            scale = 1.2
        }
    }
}

struct SignupScreen: View {
    @StateObject private var viewModel = SignupViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Progress bar
                VStack(spacing: 16) {
                    HStack {
                        ForEach(0..<2, id: \.self) { index in
                            Rectangle()
                                .fill(index <= viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 3)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Text("Step \(viewModel.currentStep + 1) of 2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // App Icon - larger size
                Image("RF Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                
                // Dynamic content based on step
                if viewModel.currentStep == 0 {
                    Step1View(viewModel: viewModel)
                } else {
                    Step2View(viewModel: viewModel)
                }
                
                Spacer()
                
                // Navigation buttons
                VStack(spacing: 16) {
                    if viewModel.currentStep == 0 {
                        CustomButton(
                            loading: .constant(false),
                            title: .constant("Next"),
                            width: .constant(UIScreen.main.bounds.width - 48),
                            color: .blue,
                            action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.nextStep()
                                }
                            }
                        )
                        .disabled(!viewModel.isStep1Valid)
                        .opacity(viewModel.isStep1Valid ? 1.0 : 0.6)
                    } else {
                        CustomButton(
                            loading: $viewModel.handle.loading,
                            title: .constant("Create Account"),
                            width: .constant(UIScreen.main.bounds.width - 48),
                            color: .blue,
                            action: {
                                viewModel.createAccount()
                            }
                        )
                        .disabled(!viewModel.isStep2Valid)
                        .opacity(viewModel.isStep2Valid ? 1.0 : 0.6)
                        
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.previousStep()
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    
                    // Sign in link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15, weight: .regular))
                        
                        Button("Sign In") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .zIndex(0)
            
            CustomAlert(handle: $viewModel.handle)
                .zIndex(1)
            
            if viewModel.handle.loading {
                ElegantLoadingView()
                    .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
    }
}

struct Step1View: View {
    @ObservedObject var viewModel: SignupViewModel
    
    var body: some View {
        VStack(spacing: 20) {
                HStack(spacing: 12) {
                    CustomTextField(text: $viewModel.firstName, title: "First Name")
                    CustomTextField(text: $viewModel.lastName, title: "Last Name")
                }
                
                CustomTextField(text: $viewModel.email, title: "Email")
                
                // Subspecialty picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subspecialty")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(viewModel.specialties, id: \.self) { specialty in
                            Button(specialty) {
                                viewModel.selectedSpecialty = specialty
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.selectedSpecialty)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }


struct Step2View: View {
    @ObservedObject var viewModel: SignupViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Secure your account")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Choose your login credentials")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 20) {
                CustomTextField(text: $viewModel.username, title: "Username")
                
                CustomTextField(text: $viewModel.password, title: "Password", isPassword: true)
                
                CustomTextField(text: $viewModel.confirmPassword, title: "Confirm Password", isPassword: true)
            }
            .padding(.horizontal, 24)
        }
    }
}

class SignupViewModel: ObservableObject {
    @Published var currentStep = 0
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
    
    var isStep1Valid: Bool {
        return !firstName.isEmpty && 
               !lastName.isEmpty && 
               !email.isEmpty && 
               email.contains("@") && 
               email.contains(".")
    }
    
    var isStep2Valid: Bool {
        return !username.isEmpty && 
               !password.isEmpty && 
               password.count >= 6 && 
               password == confirmPassword
    }
    
    func nextStep() {
        if currentStep == 0 && isStep1Valid {
            currentStep = 1
        }
    }
    
    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    func createAccount() {
        print("🚀 Starting account creation process...")
        
        // Final validation
        guard isStep1Valid && isStep2Valid else {
            print("❌ Validation failed - Step 1 valid: \(isStep1Valid), Step 2 valid: \(isStep2Valid)")
            handle.presentAlert(msg: "Please fill in all required fields correctly")
            return
        }
        
        // Additional email validation
        guard email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).contains("@") &&
              email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).contains(".") else {
            handle.presentAlert(msg: "Please enter a valid email address")
            return
        }
        
        // Username validation
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handle.presentAlert(msg: "Please enter a username")
            return
        }
        
        // Trim all inputs
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📝 Account details - Email: \(trimmedEmail), Username: \(trimmedUsername), Name: \(trimmedFirstName) \(trimmedLastName)")
        
        handle.setLoading(true)
        
        // Check if username is already taken
        print("🔍 Checking if username '\(trimmedUsername)' is available...")
        let usersRef = Firestore.firestore().collection("users")
        usersRef.whereField("exchangeUsername", isEqualTo: trimmedUsername).getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error checking username availability: \(error.localizedDescription)")
                    self?.handle.setLoading(false)
                    
                    // Check if it's a network error
                    if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                        self?.handle.presentAlert(msg: "Network error. Please check your internet connection and try again.")
                    } else {
                        self?.handle.presentAlert(msg: "Error checking username: \(error.localizedDescription)")
                    }
                    return
                }
                
                if let docs = snapshot?.documents, !docs.isEmpty {
                    print("❌ Username '\(trimmedUsername)' is already taken")
                    self?.handle.setLoading(false)
                    self?.handle.presentAlert(msg: "Username is already taken. Please choose another.")
                    return
                }
                
                print("✅ Username '\(trimmedUsername)' is available")
                
                // Username is unique, proceed with signup
                print("🔐 Proceeding with Firebase Auth signup...")
                FirebaseManager.shared.signUp(
                    email: trimmedEmail,
                    password: self?.password ?? "",
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    specialty: self?.selectedSpecialty ?? "",
                    username: trimmedUsername
                ) { result in
                    DispatchQueue.main.async {
                        self?.handle.setLoading(false)
                        switch result {
                        case .success:
                            print("🎉 Account created successfully!")
                            // Account created successfully - Firebase manager will handle state updates
                            break
                        case .failure(let error):
                            print("❌ Account creation failed: \(error.localizedDescription)")
                            self?.handle.presentAlert(msg: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
