rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own user data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Allow reading other users' basic profile info (for displaying names)
      allow read: if request.auth != null;
    }
    
    // Allow authenticated users to read/write posts
    match /posts/{postId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write notifications
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write comments
    match /comments/{commentId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write direct messages
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write admin data
    match /admins/{adminId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write notification preferences
    match /notificationPreferences/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
