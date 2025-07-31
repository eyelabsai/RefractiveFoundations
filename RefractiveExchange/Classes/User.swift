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

struct User: Codable, Identifiable {
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
    
    init(cases: [IOLCase] = [], credential: String = "", email: String = "", firstName: String = "", lastName: String = "", position: String = "", specialty: String = "", state: String = "", suffix: String = "", uid: String = "", avatarUrl: String? = nil, exchangeUsername: String = "", favoriteLenses: [String]? = nil, savedPosts: [String]? = nil, dateJoined: Timestamp? = nil) {
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
    }
}

