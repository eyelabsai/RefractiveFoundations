//
//  AdminService.swift
//  RefractiveExchange
//
//  Created for admin functionality
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

class AdminService: ObservableObject {
    static let shared = AdminService()
    
    @Published var currentUserRole: UserRole = .user
    @Published var allUsers: [User] = []
    @Published var reportedContent: [ContentReport] = []
    @Published var auditLogs: [AuditLog] = []
    @Published var isLoadingUsers = false
    @Published var isLoadingReports = false
    
    private var usersListener: ListenerRegistration?
    private var reportsListener: ListenerRegistration?
    
    // MASTER ADMIN - Set your user ID here as the initial super admin
    private let masterAdminId = "DV17W9np8BhGKu5erUz0Ue0KXXl2"
    private let masterAdminEmail = "gurpal.virdi@gmail.com"
    
    private init() {}
    
    // MARK: - Role Management
    
    func checkCurrentUserRole() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Check if this is the master admin
        if currentUserId == masterAdminId {
            DispatchQueue.main.async {
                self.currentUserRole = .superAdmin
            }
            // Ensure master admin has super admin role in database
            setupMasterAdmin()
            return
        }
        
        Firestore.firestore().collection("users").document(currentUserId).getDocument { [weak self] document, error in
            if let error = error {
                print("❌ Error checking user role: \(error)")
                return
            }
            
            if let document = document, document.exists,
               let user = try? document.data(as: User.self) {
                DispatchQueue.main.async {
                    self?.currentUserRole = user.role ?? .user
                }
            }
        }
    }
    
    private func setupMasterAdmin() {
        let db = Firestore.firestore()
        
        // Check if master admin user document exists and has correct role
        db.collection("users").document(masterAdminId).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                // Update existing user to ensure super admin role
                let updateData: [String: Any] = [
                    "role": UserRole.superAdmin.rawValue,
                    "permissions": UserRole.superAdmin.defaultPermissions.map { $0.rawValue },
                    "isActive": true
                ]
                
                db.collection("users").document(self?.masterAdminId ?? "").updateData(updateData) { error in
                    if let error = error {
                        print("❌ Error updating master admin role: \(error)")
                    } else {
                        print("✅ Master admin role confirmed for \(self?.masterAdminEmail ?? "")")
                    }
                }
            } else {
                print("⚠️ Master admin user document not found. Please ensure you're logged in with \(self?.masterAdminEmail ?? "")")
            }
        }
    }
    
    func hasPermission(_ permission: AdminPermission) -> Bool {
        return currentUserRole.defaultPermissions.contains(permission)
    }
    
    func canAccessAdminPanel() -> Bool {
        return currentUserRole != .user
    }
    
    // MARK: - User Management
    
    func startListeningToUsers() {
        guard hasPermission(.manageUsers) else { return }
        
        isLoadingUsers = true
        usersListener?.remove()
        
        usersListener = Firestore.firestore().collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to users: \(error)")
                    DispatchQueue.main.async {
                        self?.isLoadingUsers = false
                    }
                    return
                }
                
                let users = snapshot?.documents.compactMap { document -> User? in
                    try? document.data(as: User.self)
                } ?? []
                
                DispatchQueue.main.async {
                    self?.allUsers = users.sorted { ($0.lastName + $0.firstName).lowercased() < ($1.lastName + $1.firstName).lowercased() }
                    self?.isLoadingUsers = false
                }
            }
    }
    
    func updateUserRole(_ userId: String, newRole: UserRole, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.manageUsers) else {
            completion(false)
            return
        }
        
        let updateData: [String: Any] = [
            "role": newRole.rawValue,
            "permissions": newRole.defaultPermissions.map { $0.rawValue }
        ]
        
        Firestore.firestore().collection("users").document(userId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error updating user role: \(error)")
                    completion(false)
                } else {
                    // Log the action
                    self?.logAdminAction(.roleChanged, targetUserId: userId, details: "Role changed to \(newRole.displayName)")
                    completion(true)
                }
            }
    }
    
    func banUser(_ userId: String, duration: TimeInterval, reason: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.banUsers) else {
            completion(false)
            return
        }
        
        let bannedUntil = Timestamp(date: Date().addingTimeInterval(duration))
        
        let updateData: [String: Any] = [
            "bannedUntil": bannedUntil,
            "banReason": reason,
            "isActive": false
        ]
        
        Firestore.firestore().collection("users").document(userId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error banning user: \(error)")
                    completion(false)
                } else {
                    self?.logAdminAction(.userBanned, targetUserId: userId, details: "Banned for: \(reason)")
                    completion(true)
                }
            }
    }
    
    func unbanUser(_ userId: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.banUsers) else {
            completion(false)
            return
        }
        
        let updateData: [String: Any] = [
            "bannedUntil": FieldValue.delete(),
            "banReason": FieldValue.delete(),
            "isActive": true
        ]
        
        Firestore.firestore().collection("users").document(userId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error unbanning user: \(error)")
                    completion(false)
                } else {
                    self?.logAdminAction(.userUnbanned, targetUserId: userId, details: "User unbanned")
                    completion(true)
                }
            }
    }
    
    func deleteUser(_ userId: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.deleteUsers) else {
            completion(false)
            return
        }
        
        // This is a complex operation that should:
        // 1. Delete user's posts
        // 2. Delete user's comments
        // 3. Delete user's messages
        // 4. Delete user document
        // For now, we'll just disable the account
        
        let updateData: [String: Any] = [
            "isActive": false,
            "email": "deleted@deleted.com",
            "firstName": "Deleted",
            "lastName": "User"
        ]
        
        Firestore.firestore().collection("users").document(userId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error deleting user: \(error)")
                    completion(false)
                } else {
                    self?.logAdminAction(.userDeleted, targetUserId: userId, details: "User account deleted")
                    completion(true)
                }
            }
    }
    
    // MARK: - Content Management
    
    func pinPost(_ postId: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.pinPosts) else {
            completion(false)
            return
        }
        
        guard let adminId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let updateData: [String: Any] = [
            "isPinned": true,
            "pinnedAt": Timestamp(),
            "pinnedBy": adminId
        ]
        
        Firestore.firestore().collection("posts").document(postId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error pinning post: \(error)")
                    completion(false)
                } else {
                    self?.logAdminAction(.postPinned, targetContentId: postId, details: "Post pinned to top of feed")
                    completion(true)
                }
            }
    }
    
    func unpinPost(_ postId: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.pinPosts) else {
            completion(false)
            return
        }
        
        let updateData: [String: Any] = [
            "isPinned": FieldValue.delete(),
            "pinnedAt": FieldValue.delete(),
            "pinnedBy": FieldValue.delete()
        ]
        
        Firestore.firestore().collection("posts").document(postId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error unpinning post: \(error)")
                    completion(false)
                } else {
                    self?.logAdminAction(.postUnpinned, targetContentId: postId, details: "Post unpinned from feed")
                    completion(true)
                }
            }
    }
    
    func deletePost(_ postId: String, reason: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.deleteAnyPost) else {
            completion(false)
            return
        }
        
        Firestore.firestore().collection("posts").document(postId).delete { [weak self] error in
            if let error = error {
                print("❌ Error deleting post: \(error)")
                completion(false)
            } else {
                self?.logAdminAction(.postDeleted, targetContentId: postId, details: "Reason: \(reason)")
                completion(true)
            }
        }
    }
    
    func deleteComment(_ commentId: String, reason: String, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.deleteAnyComment) else {
            completion(false)
            return
        }
        
        Firestore.firestore().collection("comments").document(commentId).delete { [weak self] error in
            if let error = error {
                print("❌ Error deleting comment: \(error)")
                completion(false)
            } else {
                self?.logAdminAction(.commentDeleted, targetContentId: commentId, details: "Reason: \(reason)")
                completion(true)
            }
        }
    }
    
    // MARK: - Report Management
    
    func startListeningToReports() {
        guard hasPermission(.viewReports) else { return }
        
        isLoadingReports = true
        reportsListener?.remove()
        
        reportsListener = Firestore.firestore().collection("reports")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to reports: \(error)")
                    DispatchQueue.main.async {
                        self?.isLoadingReports = false
                    }
                    return
                }
                
                let reports = snapshot?.documents.compactMap { document -> ContentReport? in
                    try? document.data(as: ContentReport.self)
                } ?? []
                
                DispatchQueue.main.async {
                    self?.reportedContent = reports.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                    self?.isLoadingReports = false
                }
            }
    }
    
    func resolveReport(_ reportId: String, action: ReportAction, completion: @escaping (Bool) -> Void) {
        guard hasPermission(.handleReports) else {
            completion(false)
            return
        }
        
        let updateData: [String: Any] = [
            "status": "resolved",
            "resolvedBy": Auth.auth().currentUser?.uid ?? "",
            "resolvedAt": Timestamp(),
            "action": action.rawValue
        ]
        
        Firestore.firestore().collection("reports").document(reportId)
            .updateData(updateData) { [weak self] error in
                if let error = error {
                    print("❌ Error resolving report: \(error)")
                    completion(false)
                } else {
                    self?.logAdminAction(.reportResolved, targetContentId: reportId, details: "Action: \(action.displayName)")
                    completion(true)
                }
            }
    }
    
    // MARK: - Audit Logging
    
    private func logAdminAction(_ action: AdminAction, targetUserId: String? = nil, targetContentId: String? = nil, details: String) {
        guard let adminId = Auth.auth().currentUser?.uid else { return }
        
        let auditLog = AuditLog(
            adminId: adminId,
            action: action,
            targetUserId: targetUserId,
            targetContentId: targetContentId,
            details: details,
            timestamp: Timestamp()
        )
        
        do {
            _ = try Firestore.firestore().collection("audit_logs").addDocument(from: auditLog)
            print("✅ Admin action logged: \(action.rawValue)")
        } catch {
            print("❌ Error logging admin action: \(error)")
        }
    }
    
    func fetchAuditLogs(completion: @escaping ([AuditLog]) -> Void) {
        guard hasPermission(.viewAuditLog) else {
            completion([])
            return
        }
        
        Firestore.firestore().collection("audit_logs")
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching audit logs: \(error)")
                    completion([])
                    return
                }
                
                let logs = snapshot?.documents.compactMap { document -> AuditLog? in
                    try? document.data(as: AuditLog.self)
                } ?? []
                
                completion(logs)
            }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        usersListener?.remove()
        reportsListener?.remove()
        usersListener = nil
        reportsListener = nil
        allUsers = []
        reportedContent = []
        auditLogs = []
    }
}

// MARK: - Supporting Models

struct ContentReport: Codable, Identifiable {
    @DocumentID var id: String?
    var reporterId: String
    var contentType: ContentType
    var contentId: String
    var reason: ReportReason
    var description: String?
    var timestamp: Timestamp
    var status: ReportStatus
    var resolvedBy: String?
    var resolvedAt: Timestamp?
    var action: ReportAction?
    
    init(reporterId: String, contentType: ContentType, contentId: String, reason: ReportReason, description: String? = nil, timestamp: Timestamp = Timestamp(), status: ReportStatus = .pending) {
        self.reporterId = reporterId
        self.contentType = contentType
        self.contentId = contentId
        self.reason = reason
        self.description = description
        self.timestamp = timestamp
        self.status = status
    }
}

struct AuditLog: Codable, Identifiable {
    @DocumentID var id: String?
    var adminId: String
    var action: AdminAction
    var targetUserId: String?
    var targetContentId: String?
    var details: String
    var timestamp: Timestamp
}

enum ContentType: String, Codable {
    case post = "post"
    case comment = "comment"
    case user = "user"
    case message = "message"
}

enum ReportReason: String, Codable, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case inappropriate = "inappropriate"
    case misinformation = "misinformation"
    case violence = "violence"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .inappropriate: return "Inappropriate Content"
        case .misinformation: return "Misinformation"
        case .violence: return "Violence/Threats"
        case .other: return "Other"
        }
    }
}

enum ReportStatus: String, Codable {
    case pending = "pending"
    case resolved = "resolved"
    case dismissed = "dismissed"
}

enum ReportAction: String, Codable {
    case noAction = "no_action"
    case contentRemoved = "content_removed"
    case userWarned = "user_warned"
    case userBanned = "user_banned"
    
    var displayName: String {
        switch self {
        case .noAction: return "No Action"
        case .contentRemoved: return "Content Removed"
        case .userWarned: return "User Warned"
        case .userBanned: return "User Banned"
        }
    }
}

enum AdminAction: String, Codable {
    case roleChanged = "role_changed"
    case userBanned = "user_banned"
    case userUnbanned = "user_unbanned"
    case userDeleted = "user_deleted"
    case postDeleted = "post_deleted"
    case postPinned = "post_pinned"
    case postUnpinned = "post_unpinned"
    case commentDeleted = "comment_deleted"
    case reportResolved = "report_resolved"
    
    var displayName: String {
        switch self {
        case .roleChanged: return "Role Changed"
        case .userBanned: return "User Banned"
        case .userUnbanned: return "User Unbanned"
        case .userDeleted: return "User Deleted"
        case .postDeleted: return "Post Deleted"
        case .postPinned: return "Post Pinned"
        case .postUnpinned: return "Post Unpinned"
        case .commentDeleted: return "Comment Deleted"
        case .reportResolved: return "Report Resolved"
        }
    }
}
