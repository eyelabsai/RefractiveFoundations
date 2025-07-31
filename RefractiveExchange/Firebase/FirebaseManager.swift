import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var isUserAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        configureFirebase()
        checkAuthenticationStatus()
    }
    
    private func configureFirebase() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
    
    private func checkAuthenticationStatus() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isUserAuthenticated = user != nil
                if let user = user {
                    self?.fetchUserData(uid: user.uid)
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔐 Attempting sign in with email: \(email)")
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error as NSError? {
                print("❌ Sign in failed with error code \(error.code): \(error.localizedDescription)")
                let message: String
                switch AuthErrorCode(rawValue: error.code) {
                case .wrongPassword:
                    message = "Incorrect password."
                case .userNotFound:
                    message = "No account found with this email."
                case .invalidEmail:
                    message = "Invalid email address."
                case .userDisabled:
                    message = "This account has been disabled."
                case .networkError:
                    message = "Network error. Please check your internet connection."
                default:
                    message = error.localizedDescription
                }
                completion(.failure(NSError(domain: "FirebaseManager", code: error.code, userInfo: [NSLocalizedDescriptionKey: message])))
            } else {
                print("✅ Sign in successful")
                completion(.success(()))
            }
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, specialty: String, username: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔐 Attempting to create user account with email: \(email)")
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error as NSError? {
                print("❌ Firebase Auth signup failed with error code \(error.code): \(error.localizedDescription)")
                let message: String
                switch AuthErrorCode(rawValue: error.code) {
                case .emailAlreadyInUse:
                    message = "Email already in use. Please use a different email."
                case .weakPassword:
                    message = "Password is too weak. Please use a stronger password."
                case .invalidEmail:
                    message = "Invalid email address format."
                case .networkError:
                    message = "Network error. Please check your internet connection and try again."
                case .tooManyRequests:
                    message = "Too many attempts. Please wait and try again later."
                default:
                    message = "Account creation failed: \(error.localizedDescription)"
                }
                completion(.failure(NSError(domain: "FirebaseManager", code: error.code, userInfo: [NSLocalizedDescriptionKey: message])))
                return
            }
            
            guard let user = result?.user else {
                print("❌ Failed to get user from authentication result")
                completion(.failure(NSError(domain: "FirebaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user account"])))
                return
            }
            
            print("✅ Firebase Auth account created successfully for UID: \(user.uid)")
            
            // Create user document in Firestore
            print("🔥 Creating user document for UID: \(user.uid)")
            print("📝 User data: \(firstName) \(lastName), email: \(email), specialty: \(specialty), username: \(username ?? "none")")
            
            let userData = User(
                credential: "",
                email: email,
                firstName: firstName,
                lastName: lastName,
                position: "",
                specialty: specialty,
                state: "",
                suffix: "",
                uid: user.uid,
                avatarUrl: nil,
                exchangeUsername: username ?? "",
                favoriteLenses: [],
                savedPosts: [],
                dateJoined: Timestamp(date: Date())
            )
            
            self?.saveUserData(user: userData) { result in
                switch result {
                case .success:
                    print("✅ User account and document created successfully")
                    completion(.success(()))
                case .failure(let error):
                    print("❌ Failed to save user document: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isUserAuthenticated = false
            currentUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Migration Helper
    func createMissingUserDocument(completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user for migration")
            completion(false)
            return
        }
        
        let uid = currentUser.uid
        let email = currentUser.email ?? ""
        
        print("🔧 Checking if user document exists for UID: \(uid)")
        
        // Check if user document already exists
        Firestore.firestore().collection("users").document(uid).getDocument { document, error in
            if let document = document, document.exists {
                print("✅ User document already exists, no migration needed")
                completion(true)
                return
            }
            
            print("🚀 Creating missing user document for UID: \(uid)")
            
            // Create a basic user document with default values
            let userData = User(
                credential: "",
                email: email,
                firstName: "User", // Default - user can update later
                lastName: "", // Default - user can update later  
                position: "",
                specialty: "General Ophthalmology", // Default
                state: "",
                suffix: "",
                uid: uid,
                avatarUrl: nil,
                exchangeUsername: "", // User can set this later
                favoriteLenses: [],
                savedPosts: [],
                dateJoined: Timestamp(date: Date())
            )
            
            self.saveUserData(user: userData) { result in
                switch result {
                case .success:
                    print("✅ Successfully created user document for existing user")
                    completion(true)
                case .failure(let error):
                    print("❌ Failed to create user document: \(error)")
                    completion(false)
                }
            }
        }
    }

    private func saveUserData(user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            print("💾 Saving user data to Firestore for UID: \(user.uid)")
            try Firestore.firestore().collection("users").document(user.uid).setData(from: user)
            print("✅ User document saved successfully")
            completion(.success(()))
        } catch {
            print("❌ Error saving user document: \(error)")
            completion(.failure(error))
        }
    }

    private func fetchUserData(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: User.self)
                    DispatchQueue.main.async {
                        self?.currentUser = user
                    }
                } catch {
                    print("Error decoding user: \(error)")
                }
            } else {
                print("⚠️ User document not found, attempting to create it...")
                self?.createMissingUserDocument { success in
                    if success {
                        // Retry fetching after creating the document
                        self?.fetchUserData(uid: uid)
                    }
                }
            }
        }
    }
} 