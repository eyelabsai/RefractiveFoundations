//
//  User.swift
//  RefractiveExchange
//

//

import Foundation
import FirebaseFirestore

// IOLCase represents an Intraocular Lens case
struct IOLCase: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var timestamp: Timestamp
    var authorId: String
    var imageURL: String?
    var tags: [String]
    
    init(title: String = "", description: String = "", timestamp: Timestamp = Timestamp(), authorId: String = "", imageURL: String? = nil, tags: [String] = []) {
        self.title = title
        self.description = description
        self.timestamp = timestamp
        self.authorId = authorId
        self.imageURL = imageURL
        self.tags = tags
    }
}

struct User: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var cases: [IOLCase]?
    var credential: String
    var email: String
    var firstName: String
    var lastName: String
    var position: String
    var specialty: String
    var state: String
    var suffix: String
    var uid: String
    var avatarUrl: String?
    var exchangeUsername: String
    var favoriteLenses: [String]?
    var savedPosts: [String]?
    var dateJoined: Timestamp?
    var practiceLocation: String?
    var practiceName: String?
    var hasCompletedOnboarding: Bool?
    var role: UserRole?
    var permissions: [AdminPermission]?
    var isActive: Bool?
    var lastActiveAt: Timestamp?
    var bannedUntil: Timestamp?
    var banReason: String?
    
    init(cases: [IOLCase] = [], credential: String = "", email: String = "", firstName: String = "", lastName: String = "", position: String = "", specialty: String = "", state: String = "", suffix: String = "", uid: String = "", avatarUrl: String? = nil, exchangeUsername: String = "", favoriteLenses: [String]? = nil, savedPosts: [String]? = nil, dateJoined: Timestamp? = nil, practiceLocation: String? = nil, practiceName: String? = nil, hasCompletedOnboarding: Bool? = nil, role: UserRole? = nil, permissions: [AdminPermission]? = nil, isActive: Bool? = nil, lastActiveAt: Timestamp? = nil, bannedUntil: Timestamp? = nil, banReason: String? = nil) {
        self.cases = cases
        self.credential = credential
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.position = position
        self.specialty = specialty
        self.state = state
        self.suffix = suffix
        self.uid = uid
        self.avatarUrl = avatarUrl
        self.exchangeUsername = exchangeUsername
        self.favoriteLenses = favoriteLenses
        self.savedPosts = savedPosts
        self.dateJoined = dateJoined
        self.practiceLocation = practiceLocation
        self.practiceName = practiceName
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.role = role
        self.permissions = permissions
        self.isActive = isActive
        self.lastActiveAt = lastActiveAt
        self.bannedUntil = bannedUntil
        self.banReason = banReason
    }
    
    // Equatable conformance
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    // MARK: - Admin Helper Methods
    
    func hasRole(_ role: UserRole) -> Bool {
        return self.role == role
    }
    
    func hasPermission(_ permission: AdminPermission) -> Bool {
        return permissions?.contains(permission) ?? false
    }
    
    func isAdmin() -> Bool {
        return hasRole(.admin) || hasRole(.superAdmin)
    }
    
    func isModerator() -> Bool {
        return hasRole(.moderator) || isAdmin()
    }
    
    func canModerate() -> Bool {
        return isModerator() || isAdmin()
    }
    
    func isBanned() -> Bool {
        if let bannedUntil = bannedUntil {
            return bannedUntil.dateValue() > Date()
        }
        return false
    }
    
    func isActiveUser() -> Bool {
        return (isActive ?? true) && !isBanned()
    }
}

// MARK: - User Role Enum
enum UserRole: String, Codable, CaseIterable {
    case user = "user"
    case moderator = "moderator"
    case admin = "admin"
    case superAdmin = "super_admin"
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .moderator: return "Moderator"
        case .admin: return "Admin"
        case .superAdmin: return "Super Admin"
        }
    }
    
    var badge: String {
        switch self {
        case .user: return ""
        case .moderator: return "MOD"
        case .admin: return "ADMIN"
        case .superAdmin: return "SUPER"
        }
    }
    
    var badgeColor: String {
        switch self {
        case .user: return "clear"
        case .moderator: return "green"
        case .admin: return "orange"
        case .superAdmin: return "red"
        }
    }
}

// MARK: - Admin Permission Enum
enum AdminPermission: String, Codable, CaseIterable {
    // User Management
    case manageUsers = "manage_users"
    case banUsers = "ban_users"
    case deleteUsers = "delete_users"
    case viewUserDetails = "view_user_details"
    
    // Content Management
    case deleteAnyPost = "delete_any_post"
    case editAnyPost = "edit_any_post"
    case pinPosts = "pin_posts"
    case lockPosts = "lock_posts"
    case deleteAnyComment = "delete_any_comment"
    case editAnyComment = "edit_any_comment"
    
    // Moderation
    case viewReports = "view_reports"
    case handleReports = "handle_reports"
    case viewAuditLog = "view_audit_log"
    
    // System Management
    case manageCategories = "manage_categories"
    case systemSettings = "system_settings"
    case viewAnalytics = "view_analytics"
    
    var displayName: String {
        switch self {
        case .manageUsers: return "Manage Users"
        case .banUsers: return "Ban/Unban Users"
        case .deleteUsers: return "Delete Users"
        case .viewUserDetails: return "View User Details"
        case .deleteAnyPost: return "Delete Any Post"
        case .editAnyPost: return "Edit Any Post"
        case .pinPosts: return "Pin Posts"
        case .lockPosts: return "Lock Posts"
        case .deleteAnyComment: return "Delete Any Comment"
        case .editAnyComment: return "Edit Any Comment"
        case .viewReports: return "View Reports"
        case .handleReports: return "Handle Reports"
        case .viewAuditLog: return "View Audit Log"
        case .manageCategories: return "Manage Categories"
        case .systemSettings: return "System Settings"
        case .viewAnalytics: return "View Analytics"
        }
    }
    
    var description: String {
        switch self {
        case .manageUsers: return "Create, edit, and manage user accounts"
        case .banUsers: return "Ban or unban users from the platform"
        case .deleteUsers: return "Permanently delete user accounts"
        case .viewUserDetails: return "View detailed user information and activity"
        case .deleteAnyPost: return "Delete any post regardless of author"
        case .editAnyPost: return "Edit content of any post"
        case .pinPosts: return "Pin important posts to top of feeds"
        case .lockPosts: return "Lock posts to prevent new comments"
        case .deleteAnyComment: return "Delete any comment regardless of author"
        case .editAnyComment: return "Edit content of any comment"
        case .viewReports: return "View user reports and flagged content"
        case .handleReports: return "Resolve reports and take moderation actions"
        case .viewAuditLog: return "View system audit logs and admin actions"
        case .manageCategories: return "Create and manage post categories/subreddits"
        case .systemSettings: return "Modify system-wide settings and configurations"
        case .viewAnalytics: return "Access platform analytics and usage statistics"
        }
    }
}

// MARK: - Default Role Permissions
extension UserRole {
    var defaultPermissions: [AdminPermission] {
        switch self {
        case .user:
            return []
        case .moderator:
            return [
                .viewReports,
                .handleReports,
                .deleteAnyPost,
                .deleteAnyComment,
                .lockPosts,
                .viewUserDetails
            ]
        case .admin:
            return [
                .manageUsers,
                .banUsers,
                .viewUserDetails,
                .deleteAnyPost,
                .editAnyPost,
                .pinPosts,
                .lockPosts,
                .deleteAnyComment,
                .editAnyComment,
                .viewReports,
                .handleReports,
                .viewAuditLog,
                .manageCategories,
                .viewAnalytics
            ]
        case .superAdmin:
            return AdminPermission.allCases
        }
    }
}

