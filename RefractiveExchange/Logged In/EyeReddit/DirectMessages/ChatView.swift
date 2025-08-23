//
//  ChatView.swift
//  RefractiveExchange
//
//  Individual DM Conversation View
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ChatView: View {
    let conversationId: String
    let otherUser: User?
    let displayName: String
    
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var messages: [DirectMessage] = []
    @State private var messageText = ""
    @State private var messageListener: ListenerRegistration?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var actualConversationId: String = ""
    @State private var showingUserProfile = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesScrollView
            
            // Message input
            messageInputView
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let otherUser = otherUser {
                    Button(action: {
                        showingUserProfile = true
                    }) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                            )
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .sheet(isPresented: $showingUserProfile) {
            if let user = otherUser {
                PublicProfileView(
                    username: user.exchangeUsername,
                    userId: user.uid,
                    data: GetData()
                )
            }
        }
        .onAppear {
            print("📱 ChatView appeared with conversationId: '\(conversationId)'")
            if !conversationId.isEmpty {
                actualConversationId = conversationId
                // Restore conversation if it was deleted for current user
                restoreConversationIfDeleted()
            }
            startListeningToMessages()
            markMessagesAsRead()
        }
        .onDisappear {
            stopListening()
        }
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isLoading {
                        loadingView
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == firebaseManager.currentUser?.uid,
                                otherUserDisplayName: displayName,
                                onOtherUserTapped: {
                                    showingUserProfile = true
                                }
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messages.count) { _ in
                // Auto-scroll to bottom when new messages arrive
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading messages...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 32))
                )
                .frame(width: 80, height: 80)
            
            VStack(spacing: 8) {
                Text("Start the conversation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Say hello to \(displayName)!")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 50)
    }
    
    // MARK: - Message Input View
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(22)
                    .lineLimit(1...6)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Methods
    private func startListeningToMessages() {
        // Use the current conversation ID (either passed in or the one we got from sending a message)
        let currentConversationId = !conversationId.isEmpty ? conversationId : actualConversationId
        print("🎧 Starting to listen to messages for conversation: \(currentConversationId)")
        
        // If we have a conversationId, listen to existing messages
        if !currentConversationId.isEmpty {
            messageListener?.remove() // Remove any existing listener
            messageListener = DirectMessageService.shared.listenToMessages(conversationId: currentConversationId) { [self] fetchedMessages in
                DispatchQueue.main.async {
                    self.messages = fetchedMessages
                    self.isLoading = false
                    
                    // Mark messages as read when they come in
                    if !fetchedMessages.isEmpty {
                        self.markMessagesAsRead()
                    }
                }
            }
        } else {
            // This is a new conversation - no messages to load yet
            print("💭 No conversation ID - this is a new conversation")
            isLoading = false
        }
    }
    
    private func stopListening() {
        messageListener?.remove()
        messageListener = nil
    }
    
    private func sendMessage() {
        guard let currentUserId = firebaseManager.currentUser?.uid,
              let otherUser = otherUser,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let otherUserId = otherUser.uid
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        
        DirectMessageService.shared.sendMessage(to: otherUserId, text: trimmedMessage) { result in
            DispatchQueue.main.async {
                self.isSending = false
                
                switch result {
                case .success(let returnedConversationId):
                    self.messageText = ""
                    
                    // If this was a new conversation, update our conversation ID and start listening
                    if self.actualConversationId.isEmpty {
                        print("🔄 First message sent, got conversation ID: \(returnedConversationId)")
                        self.actualConversationId = returnedConversationId
                        self.startListeningToMessages()
                    }
                    
                case .failure(let error):
                    print("❌ Error sending message: \(error)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    private func markMessagesAsRead() {
        guard let currentUserId = firebaseManager.currentUser?.uid else { return }
        
        // Use the current conversation ID (either passed in or the one we got from sending a message)
        let currentConversationId = !conversationId.isEmpty ? conversationId : actualConversationId
        guard !currentConversationId.isEmpty else { return }
        
        DirectMessageService.shared.markMessagesAsRead(conversationId: currentConversationId, userId: currentUserId) { success in
            if success {
                print("✅ Messages marked as read")
            }
        }
    }
    
    private func restoreConversationIfDeleted() {
        guard let currentUserId = firebaseManager.currentUser?.uid else { return }
        let currentConversationId = !conversationId.isEmpty ? conversationId : actualConversationId
        guard !currentConversationId.isEmpty else { return }
        
        DirectMessageService.shared.restoreConversationForUser(conversationId: currentConversationId, userId: currentUserId) { success in
            if success {
                print("✅ Conversation restored for user")
            }
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: DirectMessage
    let isFromCurrentUser: Bool
    let otherUserDisplayName: String
    let onOtherUserTapped: (() -> Void)?
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        let now = Date()
        let messageDate = message.timestamp.dateValue()
        
        // If message is from today, show time only
        if Calendar.current.isDate(messageDate, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
        } else {
            // If message is older, show date and time
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: messageDate)
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text(message.text)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                        
                        // Read status indicator could go here
                    }
                    
                    Text(formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button(action: {
                            onOtherUserTapped?()
                        }) {
                            Text(message.text)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text(formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationView {
        ChatView(
            conversationId: "sample_conversation",
            otherUser: User(
                firstName: "John",
                lastName: "Doe",
                specialty: "Ophthalmology",
                exchangeUsername: "johndoe"
            ),
            displayName: "johndoe"
        )
    }
} 