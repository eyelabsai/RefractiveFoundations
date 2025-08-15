//
//  AdminPanelView.swift
//  RefractiveExchange
//
//  Created for admin functionality
//

import SwiftUI
import Firebase

struct AdminPanelView: View {
    @ObservedObject var firebaseManager = FirebaseManager.shared
    @ObservedObject var adminService = AdminService.shared
    @State private var selectedTab: AdminTab = .users
    @State private var showingCreateAdminAlert = false
    @State private var newAdminEmail = ""
    @State private var selectedRole: UserRole = .admin
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if adminService.canAccessAdminPanel() {
                    // Admin Role Badge
                    adminRoleBadge
                    
                    // Tab Bar
                    adminTabBar
                    
                    // Content based on selected tab
                    TabView(selection: $selectedTab) {
                        UserManagementView()
                            .tag(AdminTab.users)
                        
                        ContentModerationView()
                            .tag(AdminTab.content)
                        
                        ReportsView()
                            .tag(AdminTab.reports)
                        
                        AuditLogView()
                            .tag(AdminTab.audit)
                        
                        SystemSettingsView()
                            .tag(AdminTab.settings)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    unauthorizedView
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if adminService.hasPermission(.manageUsers) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Create Admin") {
                            showingCreateAdminAlert = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateAdminAlert) {
                CreateAdminSheet(
                    email: $newAdminEmail,
                    selectedRole: $selectedRole,
                    onCancel: {
                        newAdminEmail = ""
                        selectedRole = .admin
                    },
                    onCreate: {
                        createAdminAccount()
                    }
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            adminService.checkCurrentUserRole()
            adminService.startListeningToUsers()
            adminService.startListeningToReports()
        }
    }
    
    // MARK: - Admin Role Badge
    private var adminRoleBadge: some View {
        HStack {
            Image(systemName: "shield.fill")
                .foregroundColor(roleColor)
            
            Text(adminService.currentUserRole.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(roleColor)
            
            if !adminService.currentUserRole.badge.isEmpty {
                Text(adminService.currentUserRole.badge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(roleColor)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(roleColor.opacity(0.1))
    }
    
    private var roleColor: Color {
        switch adminService.currentUserRole.badgeColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        default: return .orange
        }
    }
    
    // MARK: - Admin Tab Bar
    private var adminTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                AdminTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Unauthorized View
    private var unauthorizedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 64))
                .foregroundColor(.red.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Access Denied")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("You don't have permission to access the admin panel. Contact a system administrator if you believe this is an error.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // TODO: getTabCount function will be added once AdminService is integrated
    
    private func createAdminAccount() {
        guard !newAdminEmail.isEmpty else { return }
        
        // Find user by email and promote to admin
        Firestore.firestore().collection("users")
            .whereField("email", isEqualTo: newAdminEmail)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error finding user: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("❌ No user found with email: \(newAdminEmail)")
                    return
                }
                
                let userDoc = documents.first!
                let userId = userDoc.documentID
                
                // Promote to selected role
                adminService.updateUserRole(userId, newRole: selectedRole) { success in
                    DispatchQueue.main.async {
                        if success {
                            print("✅ Successfully promoted \(newAdminEmail) to \(selectedRole.displayName)")
                        } else {
                            print("❌ Failed to promote user to \(selectedRole.displayName)")
                        }
                        newAdminEmail = ""
                        selectedRole = .admin
                    }
                }
            }
    }
}

// MARK: - Admin Tab Enum
enum AdminTab: String, CaseIterable {
    case users = "users"
    case content = "content"
    case reports = "reports"
    case audit = "audit"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .users: return "Users"
        case .content: return "Content"
        case .reports: return "Reports"
        case .audit: return "Audit"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .users: return "person.3.fill"
        case .content: return "doc.text.fill"
        case .reports: return "flag.fill"
        case .audit: return "list.bullet.clipboard.fill"
        case .settings: return "gear.fill"
        }
    }
}

// MARK: - Admin Tab Button
struct AdminTabButton: View {
    let tab: AdminTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .blue : .clear)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - User Management View
struct UserManagementView: View {
    @ObservedObject var adminService = AdminService.shared
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var showingUserDetail = false
    @State private var filterRole: UserRole? = nil
    
    var filteredUsers: [User] {
        var users = adminService.allUsers
        
        if let role = filterRole {
            users = users.filter { $0.role == role }
        }
        
        if !searchText.isEmpty {
            users = users.filter { user in
                let fullName = "\(user.firstName) \(user.lastName)".lowercased()
                let email = user.email.lowercased()
                let searchLower = searchText.lowercased()
                return fullName.contains(searchLower) || email.contains(searchLower)
            }
        }
        
        return users.sorted { ($0.lastName + $0.firstName).lowercased() < ($1.lastName + $1.firstName).lowercased() }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter
            VStack(spacing: 8) {
                SearchBar(text: $searchText, placeholder: "Search users...")
                
                // Role Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: filterRole == nil) {
                            filterRole = nil
                        }
                        
                        ForEach(UserRole.allCases, id: \.self) { role in
                            if role != .user { // Don't show regular users in filter
                                FilterChip(title: role.displayName, isSelected: filterRole == role) {
                                    filterRole = role
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Users List
            if adminService.isLoadingUsers {
                ProgressView("Loading users...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredUsers) { user in
                        UserRowView(user: user) {
                            selectedUser = user
                            showingUserDetail = true
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingUserDetail) {
            if let user = selectedUser {
                UserDetailView(user: user)
            }
        }
    }
}

// MARK: - User Row View
struct UserRowView: View {
    let user: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                    )
                    .frame(width: 40, height: 40)
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Role badge
                        if let role = user.role, role != .user {
                            Text(role.badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(roleColor(for: role))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        if user.isBanned() {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(user.email)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(user.specialty)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func roleColor(for role: UserRole) -> Color {
        switch role.badgeColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        default: return .gray
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Placeholder Views
struct ContentModerationView: View {
    var body: some View {
        Text("Content Moderation")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
}

struct ReportsView: View {
    var body: some View {
        Text("Reports")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
}

struct AuditLogView: View {
    var body: some View {
        Text("Audit Log")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
}

struct SystemSettingsView: View {
    var body: some View {
        Text("System Settings")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
}

struct UserDetailView: View {
    let user: User
    
    var body: some View {
        NavigationView {
            Text("User Detail for \(user.firstName) \(user.lastName)")
                .navigationTitle("User Details")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Create Admin Sheet
struct CreateAdminSheet: View {
    @Binding var email: String
    @Binding var selectedRole: UserRole
    let onCancel: () -> Void
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Promote User")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Enter the email address of the user you want to promote")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        TextField("Enter user's email", text: $email)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Role Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Menu {
                            ForEach([UserRole.moderator, UserRole.admin, UserRole.superAdmin], id: \.self) { role in
                                Button(action: {
                                    selectedRole = role
                                }) {
                                    HStack {
                                        Text(role.displayName)
                                        Spacer()
                                        if selectedRole == role {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedRole.displayName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Role Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(roleDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onCreate()
                        dismiss()
                    }) {
                        Text("Promote User")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(email.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(email.isEmpty)
                    
                    Button(action: {
                        onCancel()
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Promote User")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
    
    private var roleDescription: String {
        switch selectedRole {
        case .moderator:
            return "Can view reports, handle reports, delete posts/comments, lock posts, and view user details"
        case .admin:
            return "Can manage users, ban users, view analytics, plus all moderator permissions"
        case .superAdmin:
            return "Has all permissions including system settings and full user management"
        default:
            return ""
        }
    }
}

#Preview {
    AdminPanelView()
}
