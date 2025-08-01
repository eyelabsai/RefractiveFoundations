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
    @Environment(\.colorScheme) var colorScheme
    
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
                
                // App Logo - prominently displayed and large
                Image("RF Icon")
                    .renderingMode(colorScheme == .dark ? Image.TemplateRenderingMode.template : Image.TemplateRenderingMode.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 7)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                
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
                        VStack(spacing: 8) {
                            CustomButton(
                                loading: $viewModel.handle.loading,
                                title: .constant("Create Account"),
                                width: .constant(UIScreen.main.bounds.width - 48),
                                color: .blue,
                                action: {
                                    viewModel.createAccount()
                                }
                            )
                            .disabled(!viewModel.isStep2Valid || viewModel.handle.loading)
                            .opacity((viewModel.isStep2Valid && !viewModel.handle.loading) ? 1.0 : 0.6)
                            
                            if viewModel.handle.loading {
                                Text("Checking availability...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.handle.loading)
                            }
                        }
                        
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
                
                // Email field with live validation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TextField("", text: $viewModel.email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .onChange(of: viewModel.email) { newValue in
                            viewModel.checkEmailAvailability(newValue)
                        }
                    
                    // Live email validation message
                    if !viewModel.email.isEmpty && viewModel.email.contains("@") && viewModel.email.contains(".") {
                        if viewModel.isCheckingEmail {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking availability...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        } else if viewModel.isEmailTaken {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                                Text("Email is already registered")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 4)
                        } else if viewModel.isEmailAvailable {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                                Text("Email is available")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 4)
                        }
                    } else if !viewModel.email.isEmpty && (!viewModel.email.contains("@") || !viewModel.email.contains(".")) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text("Please enter a valid email address")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                CustomTextField(text: $viewModel.practiceLocation, title: "Practice Location (City)")
                
                CustomTextField(text: $viewModel.practiceName, title: "Practice Name")
                
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
                                .foregroundColor(viewModel.selectedSpecialty == "Choose one" ? .secondary : .primary)
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
                // Username field with live validation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TextField("", text: $viewModel.username)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: viewModel.username) { newValue in
                            viewModel.checkUsernameAvailability(newValue)
                        }
                    
                    // Live username validation message
                    if !viewModel.username.isEmpty {
                        if viewModel.isCheckingUsername {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking availability...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        } else if viewModel.isUsernameTaken {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                                Text("Username is already taken")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 4)
                        } else if viewModel.isUsernameAvailable {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                                Text("Username is available")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                CustomTextField(text: $viewModel.password, title: "Password", isPassword: true)
                
                // Custom confirm password field with validation styling
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    SecureField("", text: $viewModel.confirmPassword)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.password)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    !viewModel.confirmPassword.isEmpty ? 
                                        (viewModel.passwordsMatch ? Color.green : Color.red) : 
                                        Color(.systemGray4),
                                    lineWidth: 1.5
                                )
                        )
                }
                
                // Password match validation message
                if !viewModel.confirmPassword.isEmpty {
                    if viewModel.passwordsMatch {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            
                            Text("Passwords match")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.passwordsMatch)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                            
                            Text("Passwords don't match")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.passwordsMatch)
                    }
                }
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
    @Published var selectedSpecialty = "Choose one"
    @Published var practiceLocation = ""
    @Published var practiceName = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var handle = AlertHandler()
    
    // Username validation states
    @Published var isCheckingUsername = false
    @Published var isUsernameTaken = false
    @Published var isUsernameAvailable = false
    
    // Email validation states
    @Published var isCheckingEmail = false
    @Published var isEmailTaken = false
    @Published var isEmailAvailable = false
    
    let specialties = [
        "Resident",
        "Fellow",
        "Refractive Surgeon",
        "Optometrist/APP",
        "Industry"
    ]
    
    var isStep1Valid: Bool {
        return !firstName.isEmpty && 
               !lastName.isEmpty && 
               !email.isEmpty && 
               email.contains("@") && 
               email.contains(".") &&
               !practiceLocation.isEmpty &&
               !practiceName.isEmpty &&
               !isEmailTaken &&
               selectedSpecialty != "Choose one"
    }
    
    var isStep2Valid: Bool {
        return !username.isEmpty && 
               !password.isEmpty && 
               password.count >= 6 && 
               passwordsMatch &&
               !isUsernameTaken
    }
    
    var passwordsMatch: Bool {
        return password == confirmPassword
    }
    
    // Debounced username availability check
    private var usernameCheckTimer: Timer?
    
    // Debounced email availability check
    private var emailCheckTimer: Timer?
    
    func checkEmailAvailability(_ email: String) {
        // Reset states
        isCheckingEmail = false
        isEmailTaken = false
        isEmailAvailable = false
        
        // Cancel previous timer
        emailCheckTimer?.invalidate()
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Don't check if email is empty or invalid format
        guard !trimmedEmail.isEmpty && trimmedEmail.contains("@") && trimmedEmail.contains(".") else { return }
        
        // Set checking state
        isCheckingEmail = true
        
        // Debounce the check to avoid too many requests
        emailCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performEmailCheck(trimmedEmail)
        }
    }
    
    private func performEmailCheck(_ email: String) {
        guard !email.isEmpty else {
            DispatchQueue.main.async {
                self.isCheckingEmail = false
            }
            return
        }
        
        print("🔍 Live checking email: '\(email)'")
        
        Firestore.firestore().collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isCheckingEmail = false
                    
                    if let error = error {
                        print("❌ Error checking email: \(error.localizedDescription)")
                        return
                    }
                    
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        print("❌ Email '\(email)' is taken")
                        self?.isEmailTaken = true
                        self?.isEmailAvailable = false
                    } else {
                        print("✅ Email '\(email)' is available")
                        self?.isEmailTaken = false
                        self?.isEmailAvailable = true
                    }
                }
            }
    }
    
    func checkUsernameAvailability(_ username: String) {
        // Reset states
        isCheckingUsername = false
        isUsernameTaken = false
        isUsernameAvailable = false
        
        // Cancel previous timer
        usernameCheckTimer?.invalidate()
        
        // Don't check if username is too short
        guard username.count >= 3 else { return }
        
        // Set checking state
        isCheckingUsername = true
        
        // Debounce the check to avoid too many requests
        usernameCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performUsernameCheck(username)
        }
    }
    
    private func performUsernameCheck(_ username: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUsername.isEmpty else {
            DispatchQueue.main.async {
                self.isCheckingUsername = false
            }
            return
        }
        
        print("🔍 Live checking username: '\(trimmedUsername)'")
        
        Firestore.firestore().collection("users")
            .whereField("exchangeUsername", isEqualTo: trimmedUsername)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isCheckingUsername = false
                    
                    if let error = error {
                        print("❌ Error checking username: \(error.localizedDescription)")
                        return
                    }
                    
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        print("❌ Username '\(trimmedUsername)' is taken")
                        self?.isUsernameTaken = true
                        self?.isUsernameAvailable = false
                    } else {
                        print("✅ Username '\(trimmedUsername)' is available")
                        self?.isUsernameTaken = false
                        self?.isUsernameAvailable = true
                    }
                }
            }
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
                    self?.handle.presentAlert(msg: "Username '\(trimmedUsername)' is already taken. Please choose a different username.")
                    return
                }
                
                print("✅ Username '\(trimmedUsername)' is available")
                
                // Username is unique, proceed with signup (email already validated in real-time)
                print("🔐 Proceeding with Firebase Auth signup...")
                FirebaseManager.shared.signUp(
                    email: trimmedEmail,
                    password: self?.password ?? "",
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    specialty: self?.selectedSpecialty ?? "",
                    username: trimmedUsername,
                    practiceLocation: self?.practiceLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                    practiceName: self?.practiceName.trimmingCharacters(in: .whitespacesAndNewlines)
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
