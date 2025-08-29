//
//  MentionTextView.swift
//  RefractiveExchange
//
//  Created by AI Assistant on 1/25/25.
//

import SwiftUI
import UIKit

// MARK: - Mention Text View (for displaying text with highlighted mentions)
struct MentionTextView: View {
    let text: String
    let mentionColor: Color
    let onMentionTap: ((String) -> Void)?
    
    init(text: String, mentionColor: Color = .blue, onMentionTap: ((String) -> Void)? = nil) {
        self.text = text
        self.mentionColor = mentionColor
        self.onMentionTap = onMentionTap
    }
    
    var body: some View {
        MentionTextRepresentable(
            text: text,
            mentionColor: UIColor(mentionColor),
            onMentionTap: onMentionTap
        )
    }
}

// MARK: - UIViewRepresentable for handling mention taps
private struct MentionTextRepresentable: UIViewRepresentable {
    let text: String
    let mentionColor: UIColor
    let onMentionTap: ((String) -> Void)?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributedText = createAttributedString()
        uiView.attributedText = attributedText
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Set default text attributes
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: text.count))
        
        // Find and highlight mentions
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        do {
            let regex = try NSRegularExpression(pattern: mentionPattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches {
                // Highlight the mention
                attributedString.addAttribute(.foregroundColor, value: mentionColor, range: match.range)
                attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .medium), range: match.range)
                
                // Add link attribute for tap handling
                if let usernameRange = Range(match.range(at: 1), in: text) {
                    let username = String(text[usernameRange])
                    attributedString.addAttribute(.link, value: "mention://\(username)", range: match.range)
                }
            }
        } catch {
            print("Error highlighting mentions: \(error)")
        }
        
        return attributedString
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: MentionTextRepresentable
        
        init(_ parent: MentionTextRepresentable) {
            self.parent = parent
        }
        
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if URL.scheme == "mention" {
                let username = URL.host ?? ""
                parent.onMentionTap?(username)
                return false // Don't let the system handle the URL
            }
            return true
        }
    }
}

// MARK: - Simple Mention Input Field (just basic text editor with background parsing)
struct MentionInputField: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MentionTextView(text: "Hey @johndoe and @janedoe, check this out! This is a test post with mentions.")
            .padding()
        
        MentionInputField(text: .constant(""), placeholder: "Write something...")
            .padding()
    }
}
