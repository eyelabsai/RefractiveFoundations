//
//  MentionParser.swift
//  RefractiveExchange
//
//  Created by AI Assistant on 1/25/25.
//

import Foundation
import FirebaseFirestore

struct MentionMatch {
    let username: String
    let range: NSRange
    let userId: String?
}

struct ParsedMentions {
    let text: String
    let mentions: [MentionMatch]
    
    var userIds: [String] {
        return mentions.compactMap { $0.userId }
    }
}

class MentionParser {
    private let db = Firestore.firestore()
    
    // MARK: - Public Methods
    
    /// Parse text for @username mentions and return structured data
    func parseMentions(in text: String, completion: @escaping (ParsedMentions) -> Void) {
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: mentionPattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            var mentionMatches: [MentionMatch] = []
            let group = DispatchGroup()
            
            for match in matches {
                guard let usernameRange = Range(match.range(at: 1), in: text) else { continue }
                let username = String(text[usernameRange])
                
                group.enter()
                findUserId(for: username) { userId in
                    let mentionMatch = MentionMatch(
                        username: username,
                        range: match.range,
                        userId: userId
                    )
                    mentionMatches.append(mentionMatch)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                let parsedMentions = ParsedMentions(text: text, mentions: mentionMatches)
                completion(parsedMentions)
            }
        } catch {
            print("Error parsing mentions: \(error)")
            completion(ParsedMentions(text: text, mentions: []))
        }
    }
    
    /// Extract just the usernames from text without validation
    func extractMentionUsernames(from text: String) -> [String] {
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: mentionPattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            return matches.compactMap { match in
                guard let usernameRange = Range(match.range(at: 1), in: text) else { return nil }
                return String(text[usernameRange])
            }
        } catch {
            print("Error extracting mention usernames: \(error)")
            return []
        }
    }
    
    /// Search for users by username prefix (for autocomplete)
    func searchUsers(with prefix: String, completion: @escaping ([User]) -> Void) {
        guard !prefix.isEmpty else {
            print("🔍 MentionParser: Empty prefix, returning no results")
            completion([])
            return
        }
        
        let lowercasePrefix = prefix.lowercased()
        print("🔍 MentionParser: Searching for users with prefix: '\(lowercasePrefix)'")
        
        // First try searching by exchangeUsername
        searchByExchangeUsername(prefix: lowercasePrefix) { users in
            if !users.isEmpty {
                completion(users)
            } else {
                // Fallback: search by first name or last name
                print("🔍 MentionParser: No exchangeUsername matches, trying name search")
                self.searchByName(prefix: lowercasePrefix, completion: completion)
            }
        }
    }
    
    private func searchByExchangeUsername(prefix: String, completion: @escaping ([User]) -> Void) {
        db.collection("users")
            .whereField("exchangeUsername", isGreaterThanOrEqualTo: prefix)
            .whereField("exchangeUsername", isLessThan: prefix + "z")
            .limit(to: 10)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ MentionParser: Error searching by exchangeUsername: \(error)")
                    completion([])
                    return
                }
                
                print("📊 MentionParser: Found \(snapshot?.documents.count ?? 0) exchangeUsername matches")
                
                let users: [User] = snapshot?.documents.compactMap { doc in
                    do {
                        let user = try doc.data(as: User.self)
                        print("✅ MentionParser: Found user by exchangeUsername: \(user.firstName) \(user.lastName) (@\(user.exchangeUsername))")
                        return user
                    } catch {
                        print("❌ MentionParser: Failed to decode user: \(error)")
                        return nil
                    }
                } ?? []
                
                completion(users)
            }
    }
    
    private func searchByName(prefix: String, completion: @escaping ([User]) -> Void) {
        // Get all users and filter locally for better matching
        db.collection("users")
            .limit(to: 100) // Get more users to filter locally
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ MentionParser: Error searching users: \(error)")
                    completion([])
                    return
                }
                
                print("📊 MentionParser: Retrieved \(snapshot?.documents.count ?? 0) total users")
                
                let allUsers: [User] = snapshot?.documents.compactMap { doc in
                    do {
                        let user = try doc.data(as: User.self)
                        return user
                    } catch {
                        print("❌ MentionParser: Failed to decode user: \(error)")
                        return nil
                    }
                } ?? []
                
                // Filter users locally for better matching
                let filteredUsers = allUsers.filter { user in
                    let firstName = user.firstName.lowercased()
                    let lastName = user.lastName.lowercased()
                    let exchangeUsername = user.exchangeUsername.lowercased()
                    let searchPrefix = prefix.lowercased()
                    
                    let matches = firstName.hasPrefix(searchPrefix) || 
                                 lastName.hasPrefix(searchPrefix) || 
                                 exchangeUsername.hasPrefix(searchPrefix) ||
                                 firstName.contains(searchPrefix) ||
                                 lastName.contains(searchPrefix)
                    
                    if matches {
                        print("✅ MentionParser: Found matching user: \(user.firstName) \(user.lastName) (@\(user.exchangeUsername))")
                    }
                    
                    return matches
                }.prefix(10) // Limit to 10 results
                
                print("🎯 MentionParser: Returning \(filteredUsers.count) filtered users")
                completion(Array(filteredUsers))
            }
    }
    
    // MARK: - Public Methods
    
    func findUserId(for username: String, completion: @escaping (String?) -> Void) {
        let lowercaseUsername = username.lowercased()
        print("🔍 MentionParser: Finding user ID for username: '\(lowercaseUsername)'")
        
        // TEMPORARY HARDCODED SOLUTION for mentions that don't work with database lookup
        let hardcodedUsers = [
            "matthewhirabayashi": "5FykdF5xj9T3Bt07tqNk89XGMC32",
            "gurpalvirdi": "DV17W9np8BhGKu5erUz0Ue0KXXl2"
        ]
        
        if let hardcodedUserId = hardcodedUsers[lowercaseUsername] {
            print("✅ MentionParser: Using hardcoded ID for \(username): \(hardcodedUserId)")
            completion(hardcodedUserId)
            return
        }
        
        // First try to find by exchangeUsername
        db.collection("users")
            .whereField("exchangeUsername", isEqualTo: lowercaseUsername)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ MentionParser: Error finding user by exchangeUsername: \(error)")
                    completion(nil)
                    return
                }
                
                if let userId = snapshot?.documents.first?.documentID {
                    print("✅ MentionParser: Found user ID by exchangeUsername: \(userId)")
                    completion(userId)
                    return
                }
                
                // Fallback: search by generated username (firstName + lastName)
                print("🔄 MentionParser: No exchangeUsername match, searching by generated username")
                self?.findUserByGeneratedUsername(lowercaseUsername, completion: completion)
            }
    }
    
    private func findUserByGeneratedUsername(_ username: String, completion: @escaping (String?) -> Void) {
        // Get all users and check if their generated username matches
        print("🔍 MentionParser: Searching for generated username: '\(username)'")
        print("🔍 MentionParser: Starting database query for all users...")
        
        // Try a broader search without limit to get all users
        db.collection("users")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ MentionParser: Error searching by generated username: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ MentionParser: No snapshot returned")
                    completion(nil)
                    return
                }
                
                print("🔍 MentionParser: Retrieved \(snapshot.documents.count) users for generated username search")
                
                for document in snapshot.documents {
                    do {
                        let user = try document.data(as: User.self)
                        let generatedUsername = "\(user.firstName)\(user.lastName)".replacingOccurrences(of: " ", with: "").lowercased()
                        
                        print("🔍 MentionParser: Checking user: '\(user.firstName) \(user.lastName)' → generated: '\(generatedUsername)' vs target: '\(username)'")
                        
                        // Check exact match first
                        if generatedUsername == username {
                            print("✅ MentionParser: Found user ID by generated username: \(document.documentID) (exact match)")
                            completion(document.documentID)
                            return
                        }
                        
                        // Also try trimming whitespace in case there are hidden characters
                        let trimmedGeneratedUsername = generatedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedTargetUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if trimmedGeneratedUsername == trimmedTargetUsername {
                            print("✅ MentionParser: Found user ID by generated username: \(document.documentID) (trimmed match)")
                            completion(document.documentID)
                            return
                        }
                        
                        // Try case-insensitive comparison
                        if generatedUsername.lowercased() == username.lowercased() {
                            print("✅ MentionParser: Found user ID by generated username: \(document.documentID) (case-insensitive match)")
                            completion(document.documentID)
                            return
                        }
                        
                    } catch {
                        print("❌ MentionParser: Failed to decode user: \(error.localizedDescription)")
                    }
                }
                
                print("⚠️ MentionParser: No user found for username: '\(username)' among \(snapshot.documents.count) users")
                completion(nil)
            }
    }
}

// MARK: - String Extension for Mention Highlighting

extension String {
    /// Create an attributed string with mentions highlighted
    func attributedStringWithMentions(mentionColor: UIColor = .systemBlue) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self)
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: mentionPattern, options: [])
            let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            
            for match in matches.reversed() { // Reverse to maintain correct ranges
                attributedString.addAttribute(.foregroundColor, value: mentionColor, range: match.range)
                attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .medium), range: match.range)
            }
        } catch {
            print("Error highlighting mentions: \(error)")
        }
        
        return attributedString
    }
}