//
//  ClickableUITextView.swift
//  RefractiveExchange
//
//  A UIViewRepresentable wrapper for UITextView that handles clickable mentions and URLs
//

import SwiftUI
import UIKit

struct ClickableUITextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let onMentionTapped: ((String, String) -> Void)?
    
    init(
        text: String,
        font: UIFont = UIFont.systemFont(ofSize: 16),
        textColor: UIColor = UIColor.label,
        onMentionTapped: ((String, String) -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.onMentionTapped = onMentionTapped
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = UIColor.clear
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.required, for: .vertical)
        
        // Configure the attributed text
        updateAttributedText(textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        updateAttributedText(uiView)
    }
    
    private func updateAttributedText(_ textView: UITextView) {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Set base attributes
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: text.count))
        
        // Process mentions
        processMentions(attributedString)
        
        // Process URLs
        processURLs(attributedString)
        
        textView.attributedText = attributedString
    }
    
    private func processMentions(_ attributedString: NSMutableAttributedString) {
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        
        guard let regex = try? NSRegularExpression(pattern: mentionPattern, options: []) else {
            return
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        for match in matches {
            // Style the mention
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            attributedString.addAttribute(.font, value: font.withWeight(.medium), range: match.range)
            
            // Add custom link attribute for mentions
            let mentionText = (text as NSString).substring(with: match.range)
            attributedString.addAttribute(.link, value: "mention://\(mentionText)", range: match.range)
        }
    }
    
    private func processURLs(_ attributedString: NSMutableAttributedString) {
        // Enhanced URL pattern
        let urlPattern = #"(?i)\b(?:https?://[^\s<>"]*[^\s<>".,!?;:]|www\.[^\s<>"]*[^\s<>".,!?;:]|[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}(?:/[^\s<>"]*[^\s<>".,!?;:])?)"#
        
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []) else {
            return
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        for match in matches {
            let urlText = (text as NSString).substring(with: match.range)
            var urlToOpen = urlText
            
            // Add https:// if needed
            if urlToOpen.lowercased().hasPrefix("www.") {
                urlToOpen = "https://" + urlToOpen
            } else if !urlToOpen.lowercased().hasPrefix("http://") && !urlToOpen.lowercased().hasPrefix("https://") {
                if urlToOpen.contains(".") {
                    urlToOpen = "https://" + urlToOpen
                }
            }
            
            if let url = URL(string: urlToOpen) {
                attributedString.addAttribute(.link, value: url, range: match.range)
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: ClickableUITextView
        
        init(_ parent: ClickableUITextView) {
            self.parent = parent
        }
        
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            
            if URL.scheme == "mention" {
                // Handle mention tap
                let mentionText = URL.host ?? ""
                print("🔗 ClickableUITextView: Mention tapped: '\(mentionText)'")
                
                // Extract username from @username format
                let username = String(mentionText.dropFirst()) // Remove the @
                print("🔗 ClickableUITextView: Extracted username: '\(username)'")
                
                // Use MentionParser to find the user ID
                let mentionParser = MentionParser()
                mentionParser.findUserId(for: username) { userId in
                    DispatchQueue.main.async {
                        if let userId = userId {
                            print("🔗 ClickableUITextView: Found user ID: \(userId), calling onMentionTapped")
                            self.parent.onMentionTapped?(username, userId)
                        } else {
                            print("⚠️ ClickableUITextView: Could not find user ID for mention: @\(username)")
                        }
                    }
                }
                
                return false // We handle this ourselves
            } else {
                // Handle regular URLs
                UIApplication.shared.open(URL)
                return false
            }
        }
    }
}

// Extension to help with font weight
extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        return UIFont.systemFont(ofSize: pointSize, weight: weight)
    }
}
