//
//  ClickableTextView.swift
//  RefractiveExchange
//
//  A SwiftUI component that renders text with clickable links
//

import SwiftUI
import Foundation

struct ClickableTextView: View {
    let text: String
    let font: Font
    let color: Color
    let multilineTextAlignment: TextAlignment
    
    init(
        text: String,
        font: Font = .body,
        color: Color = .primary,
        multilineTextAlignment: TextAlignment = .leading
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.multilineTextAlignment = multilineTextAlignment
    }
    
    var body: some View {
        Text(createAttributedString())
            .multilineTextAlignment(multilineTextAlignment)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func createAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Set the default font and color
        attributedString.font = font
        attributedString.foregroundColor = color
        
        // Enhanced URL pattern to find links (includes domains without protocols)
        let urlPattern = #"(?i)\b(?:https?://[^\s<>"]*[^\s<>".,!?;:]|www\.[^\s<>"]*[^\s<>".,!?;:]|[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}(?:/[^\s<>"]*[^\s<>".,!?;:])?)"#
        
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []) else {
            return attributedString
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        // Process matches in reverse order to avoid index shifting
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            
            let urlText = String(text[range])
            var urlToOpen = urlText
            
            // Add https:// if the URL starts with www.
            if urlToOpen.lowercased().hasPrefix("www.") {
                urlToOpen = "https://" + urlToOpen
            }
            
            // Add https:// if no protocol is specified and it looks like a domain
            if !urlToOpen.lowercased().hasPrefix("http://") && !urlToOpen.lowercased().hasPrefix("https://") {
                // Check if it looks like a domain (contains a dot)
                if urlToOpen.contains(".") {
                    urlToOpen = "https://" + urlToOpen
                }
            }
            
            if let url = URL(string: urlToOpen) {
                // Convert String range to AttributedString range
                let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: match.range.location)
                let endIndex = attributedString.index(startIndex, offsetByCharacters: match.range.length)
                let attributedRange = startIndex..<endIndex
                
                // Apply link attributes
                attributedString[attributedRange].link = url
                attributedString[attributedRange].foregroundColor = .blue
                attributedString[attributedRange].underlineStyle = .single
            }
        }
        
        return attributedString
    }
    
}

#Preview {
    VStack(spacing: 20) {
        ClickableTextView(
            text: "Check out this website: https://www.example.com for more info!",
            font: .body,
            color: .primary
        )
        
        ClickableTextView(
            text: "Visit www.github.com or https://stackoverflow.com for coding help.",
            font: .system(size: 14),
            color: .secondary
        )
        
        ClickableTextView(
            text: "Refractivefoundations.com",
            font: .system(size: 15),
            color: .primary
        )
        
        ClickableTextView(
            text: "Multiple links: https://apple.com and www.google.com work great!",
            font: .system(size: 14),
            color: .primary
        )
        
        ClickableTextView(
            text: "No links here, just plain text.",
            font: .caption,
            color: .primary
        )
    }
    .padding()
}
