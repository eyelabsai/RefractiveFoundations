//
//  ClickableTextView.swift
//  RefractiveExchange
//
//  A SwiftUI component that renders text with clickable links and mentions
//

import SwiftUI
import Foundation

// MARK: - Supporting Types
struct TextSegment {
    let text: String
    let type: SegmentType
    let range: Range<String.Index>
}

enum SegmentType {
    case regular
    case mention
    case url
}

struct ClickableTextView: View {
    let text: String
    let font: Font
    let color: Color
    let multilineTextAlignment: TextAlignment
    let onMentionTapped: ((String, String) -> Void)? // (username, userId) -> Void
    
    init(
        text: String,
        font: Font = .body,
        color: Color = .primary,
        multilineTextAlignment: TextAlignment = .leading,
        onMentionTapped: ((String, String) -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.multilineTextAlignment = multilineTextAlignment
        self.onMentionTapped = onMentionTapped
    }
    
    var body: some View {
        // Always use the simple Text approach to preserve formatting
        Text(createAttributedString())
            .multilineTextAlignment(multilineTextAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "mention", let onMentionTapped = onMentionTapped {
                    // The URL format is mention://@username - we need to get the full host part
                    let mentionText = url.absoluteString.replacingOccurrences(of: "mention://", with: "")
                    print("🔗 ClickableTextView: Processing mention URL: \(url.absoluteString)")
                    print("🔗 ClickableTextView: Extracted mention text: '\(mentionText)'")
                    handleMentionTap(mentionText)
                    return .handled
                } else {
                    return .systemAction
                }
            })
    }
    
    // Helper to convert SwiftUI Font to UIFont size
    private func fontSizeFromSwiftUIFont(_ font: Font) -> CGFloat {
        // This is a simple approximation - SwiftUI Font to UIFont conversion is complex
        switch font {
        case .caption2:
            return 11
        case .caption:
            return 12
        case .footnote:
            return 13
        case .subheadline:
            return 15
        case .callout:
            return 16
        case .body:
            return 17
        case .headline:
            return 17
        case .title3:
            return 20
        case .title2:
            return 22
        case .title:
            return 28
        case .largeTitle:
            return 34
        default:
            return 16 // Default size
        }
    }
    
    // Helper to convert SwiftUI Color to UIColor
    private func uiColorFromSwiftUIColor(_ color: Color) -> UIColor {
        if color == .primary {
            return UIColor.label
        } else if color == .secondary {
            return UIColor.secondaryLabel
        } else {
            return UIColor.label // Default
        }
    }
    
    private var clickableTextView: some View {
        let textSegments = parseTextSegments()
        
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(groupSegmentsByLines(textSegments), id: \.0) { lineIndex, lineSegments in
                HStack(spacing: 0) {
                    ForEach(Array(lineSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                        createTextForSegment(segment)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    private func groupSegmentsByLines(_ segments: [TextSegment]) -> [(Int, [TextSegment])] {
        var lines: [(Int, [TextSegment])] = []
        var currentLine: [TextSegment] = []
        var lineIndex = 0
        
        for segment in segments {
            if segment.text.contains("\n") {
                // Split segments that contain newlines
                let parts = segment.text.components(separatedBy: "\n")
                for (index, part) in parts.enumerated() {
                    if !part.isEmpty {
                        currentLine.append(TextSegment(text: part, type: segment.type, range: segment.range))
                    }
                    if index < parts.count - 1 {
                        // End of line
                        lines.append((lineIndex, currentLine))
                        currentLine = []
                        lineIndex += 1
                    }
                }
            } else {
                currentLine.append(segment)
            }
        }
        
        if !currentLine.isEmpty {
            lines.append((lineIndex, currentLine))
        }
        
        return lines
    }
    
    private func createTextForSegment(_ segment: TextSegment) -> some View {
        Group {
            switch segment.type {
            case .mention:
                Text(segment.text)
                    .foregroundColor(.blue)
                    .font(font.weight(.medium))
                    .onTapGesture {
                        handleMentionTap(segment.text)
                    }
            case .url:
                Text(segment.text)
                    .foregroundColor(.blue)
                    .underline()
                    .font(font)
                    .onTapGesture {
                        openURL(segment.text)
                    }
            case .regular:
                Text(segment.text)
                    .foregroundColor(color)
                    .font(font)
            }
        }
    }
    
    private func parseTextSegments() -> [TextSegment] {
        var segments: [TextSegment] = []
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        let urlPattern = #"(?i)\b(?:https?://[^\s<>"]*[^\s<>".,!?;:]|www\.[^\s<>"]*[^\s<>".,!?;:]|[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}(?:/[^\s<>"]*[^\s<>".,!?;:])?)"#
        
        // Find all matches for mentions and URLs
        var allMatches: [(range: Range<String.Index>, type: SegmentType)] = []
        
        // Find mentions
        if let mentionRegex = try? NSRegularExpression(pattern: mentionPattern, options: []) {
            let mentionMatches = mentionRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            for match in mentionMatches {
                if let range = Range(match.range, in: text) {
                    allMatches.append((range: range, type: .mention))
                }
            }
        }
        
        // Find URLs
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let urlMatches = urlRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            for match in urlMatches {
                if let range = Range(match.range, in: text) {
                    allMatches.append((range: range, type: .url))
                }
            }
        }
        
        // Sort matches by location
        allMatches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Create segments
        var currentIndex = text.startIndex
        
        for match in allMatches {
            // Add regular text before the match
            if currentIndex < match.range.lowerBound {
                let regularText = String(text[currentIndex..<match.range.lowerBound])
                if !regularText.isEmpty {
                    segments.append(TextSegment(
                        text: regularText,
                        type: .regular,
                        range: currentIndex..<match.range.lowerBound
                    ))
                }
            }
            
            // Add the special segment (mention or URL)
            let matchText = String(text[match.range])
            segments.append(TextSegment(
                text: matchText,
                type: match.type,
                range: match.range
            ))
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining regular text
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex..<text.endIndex])
            if !remainingText.isEmpty {
                segments.append(TextSegment(
                    text: remainingText,
                    type: .regular,
                    range: currentIndex..<text.endIndex
                ))
            }
        }
        
        return segments
    }
    
    private func handleMentionTap(_ mentionText: String) {
        print("🔗 ClickableTextView: Mention tapped: '\(mentionText)'")
        
        // Check if the mentionText starts with @ and remove it, otherwise use as-is
        let username = mentionText.hasPrefix("@") ? String(mentionText.dropFirst()) : mentionText
        print("🔗 ClickableTextView: Extracted username: '\(username)'")
        
        // TEMPORARY HARDCODED SOLUTION for mentions that don't work with database lookup
        // This is a quick fix while we debug the database lookup issue
        let hardcodedUsers = [
            "matthewhirabayashi": "5FykdF5xj9T3Bt07tqNk89XGMC32",
            "gurpalvirdi": "DV17W9np8BhGKu5erUz0Ue0KXXl2"
        ]
        
        if let hardcodedUserId = hardcodedUsers[username.lowercased()] {
            print("🔗 ClickableTextView: Using hardcoded ID for \(username)")
            self.onMentionTapped?(username, hardcodedUserId)
            return
        }
        
        // Use MentionParser to find the user ID for this username
        let mentionParser = MentionParser()
        mentionParser.findUserId(for: username) { userId in
            DispatchQueue.main.async {
                if let userId = userId {
                    print("🔗 ClickableTextView: Found user ID: \(userId), calling onMentionTapped")
                    self.onMentionTapped?(username, userId)
                } else {
                    print("⚠️ Could not find user ID for mention: @\(username)")
                    print("⚠️ Available alternative: Try clicking on the username in the post header instead")
                }
            }
        }
    }
    
    private func openURL(_ urlText: String) {
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
            UIApplication.shared.open(url)
        }
    }
    
    private func processMentions(_ attributedString: inout AttributedString) {
        let mentionPattern = "@([a-zA-Z0-9_\\.]+)"
        
        guard let regex = try? NSRegularExpression(pattern: mentionPattern, options: []) else {
            return
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        // Process matches in reverse order to avoid index shifting
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            
            // Convert String range to AttributedString range
            let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: match.range.location)
            let endIndex = attributedString.index(startIndex, offsetByCharacters: match.range.length)
            let attributedRange = startIndex..<endIndex
            
            // Apply mention styling
            attributedString[attributedRange].foregroundColor = .blue
            attributedString[attributedRange].font = Font.system(size: 14, weight: .medium)
            
            // Add clickable link if callback is provided
            if onMentionTapped != nil {
                let mentionText = String(text[range])
                if let url = URL(string: "mention://\(mentionText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mentionText)") {
                    attributedString[attributedRange].link = url
                }
            }
        }
    }
    
    private func createAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Set the default font and color
        attributedString.font = font
        attributedString.foregroundColor = color
        
        // First, process @ mentions
        processMentions(&attributedString)
        
        // Then process URL links
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
        
        ClickableTextView(
            text: "Hey @johndoe and @janedoe, check out this link: https://example.com",
            font: .system(size: 14),
            color: .primary,
            onMentionTapped: { username, userId in
                print("Tapped mention: @\(username) with ID: \(userId)")
            }
        )
    }
    .padding()
}
