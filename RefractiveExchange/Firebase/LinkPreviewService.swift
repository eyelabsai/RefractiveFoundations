//
//  LinkPreviewService.swift
//  RefractiveExchange
//
//  Created for link preview functionality
//

import Foundation
import SwiftUI
import LinkPresentation

class LinkPreviewService: ObservableObject {
    static let shared = LinkPreviewService()
    
    @Published var isLoadingPreview = false
    
    private let session = URLSession.shared
    private var previewCache: [String: LinkPreviewData] = [:]
    
    private init() {}
    
    // MARK: - URL Detection
    
    /// Extracts URLs from text
    func extractURLs(from text: String) -> [String] {
        print("🔍 LinkPreviewService: Extracting URLs from text: '\(text)'")
        
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        print("🔍 LinkPreviewService: Found \(matches?.count ?? 0) potential matches")
        
        var urls: [String] = []
        matches?.forEach { match in
            if let range = Range(match.range, in: text) {
                var urlString = String(text[range])
                print("🔗 LinkPreviewService: Checking URL: '\(urlString)'")
                
                // Add https:// if no scheme is present
                if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                    urlString = "https://\(urlString)"
                    print("🔧 LinkPreviewService: Added https scheme: \(urlString)")
                }
                
                if isValidURL(urlString) {
                    print("✅ LinkPreviewService: Valid URL: \(urlString)")
                    urls.append(urlString)
                } else {
                    print("❌ LinkPreviewService: Invalid URL: \(urlString)")
                }
            }
        }
        
        print("🔗 LinkPreviewService: Final URLs: \(urls)")
        return urls
    }
    
    /// Checks if a URL is valid and should show a preview
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Must have a scheme (http/https)
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        
        // Must have a host
        guard url.host != nil else { return false }
        
        // Filter out certain file types that shouldn't show previews
        let fileExtension = url.pathExtension.lowercased()
        let excludedExtensions = ["jpg", "jpeg", "png", "gif", "webp", "pdf", "mp4", "mov", "avi"]
        
        return !excludedExtensions.contains(fileExtension)
    }
    
    // MARK: - Link Preview Generation
    
    /// Generates link preview data for a URL
    func generateLinkPreview(for urlString: String, completion: @escaping (LinkPreviewData?) -> Void) {
        print("🔄 LinkPreviewService: Generating preview for: \(urlString)")
        
        // Check cache first
        if let cachedPreview = previewCache[urlString] {
            print("💾 LinkPreviewService: Using cached preview for: \(urlString)")
            completion(cachedPreview)
            return
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ LinkPreviewService: Invalid URL: \(urlString)")
            completion(nil)
            return
        }
        
        DispatchQueue.main.async {
            self.isLoadingPreview = true
        }
        
        print("🔄 LinkPreviewService: Starting metadata fetch for: \(urlString)")
        
        // Try using LPLinkMetadata first (iOS 13+)
        if #available(iOS 13.0, *) {
            let metadataProvider = LPMetadataProvider()
            metadataProvider.startFetchingMetadata(for: url) { [weak self] metadata, error in
                DispatchQueue.main.async {
                    self?.isLoadingPreview = false
                    
                    if let error = error {
                        print("❌ LinkPreview error: \(error.localizedDescription)")
                        // Fallback to manual parsing
                        self?.parseHTMLMetadata(for: urlString, completion: completion)
                        return
                    }
                    
                    guard let metadata = metadata else {
                        completion(nil)
                        return
                    }
                    
                    // Extract image URL properly
                    self?.extractImageURLFromMetadata(metadata) { imageUrl in
                        let linkPreview = LinkPreviewData(
                            url: urlString,
                            title: metadata.title,
                            description: self?.extractDescription(from: metadata),
                            imageUrl: imageUrl,
                            siteName: self?.extractSiteName(from: metadata)
                        )
                        
                        // Cache the result
                        self?.previewCache[urlString] = linkPreview
                        completion(linkPreview)
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            parseHTMLMetadata(for: urlString, completion: completion)
        }
    }
    
    // MARK: - LPLinkMetadata Helpers
    
    @available(iOS 13.0, *)
    private func extractDescription(from metadata: LPLinkMetadata) -> String? {
        // Try different sources for description
        if let description = metadata.value(forKey: "description") as? String, !description.isEmpty {
            return description
        }
        
        // Fallback to summary or other properties
        return nil
    }
    
    @available(iOS 13.0, *)
    private func extractImageURLFromMetadata(_ metadata: LPLinkMetadata, completion: @escaping (String?) -> Void) {
        // Try to get the image from the image provider
        if let imageProvider = metadata.imageProvider {
            print("🖼️ LinkPreview: Found image provider, loading image...")
            
            imageProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                if let error = error {
                    print("❌ LinkPreview: Error loading image: \(error)")
                    // Try icon as fallback
                    self.tryIconProvider(metadata, completion: completion)
                    return
                }
                
                if let uiImage = image as? UIImage {
                    print("✅ LinkPreview: Successfully loaded image")
                    // For now, we'll use a direct approach for YouTube URLs
                    self.extractDirectImageURL(from: metadata, completion: completion)
                } else {
                    print("⚠️ LinkPreview: Image object is not UIImage")
                    self.tryIconProvider(metadata, completion: completion)
                }
            }
        } else {
            print("⚠️ LinkPreview: No image provider found")
            tryIconProvider(metadata, completion: completion)
        }
    }
    
    @available(iOS 13.0, *)
    private func tryIconProvider(_ metadata: LPLinkMetadata, completion: @escaping (String?) -> Void) {
        if let iconProvider = metadata.iconProvider {
            print("🔸 LinkPreview: Trying icon provider...")
            iconProvider.loadObject(ofClass: UIImage.self) { (icon, error) in
                if let error = error {
                    print("❌ LinkPreview: Error loading icon: \(error)")
                    self.extractDirectImageURL(from: metadata, completion: completion)
                    return
                }
                
                if icon != nil {
                    print("✅ LinkPreview: Successfully loaded icon")
                    self.extractDirectImageURL(from: metadata, completion: completion)
                } else {
                    print("⚠️ LinkPreview: Icon object is nil")
                    self.extractDirectImageURL(from: metadata, completion: completion)
                }
            }
        } else {
            print("⚠️ LinkPreview: No icon provider found")
            extractDirectImageURL(from: metadata, completion: completion)
        }
    }
    
    @available(iOS 13.0, *)
    private func extractDirectImageURL(from metadata: LPLinkMetadata, completion: @escaping (String?) -> Void) {
        // For YouTube, try to construct the thumbnail URL directly
        if let url = metadata.originalURL, url.host?.contains("youtube") == true {
            if let videoId = extractYouTubeVideoId(from: url.absoluteString) {
                let thumbnailUrl = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
                print("🎬 LinkPreview: Using YouTube thumbnail: \(thumbnailUrl)")
                completion(thumbnailUrl)
                return
            }
        }
        
        // Try to extract from Open Graph data in the HTML
        if let urlString = metadata.originalURL?.absoluteString {
            fetchImageURLFromHTML(urlString: urlString, completion: completion)
        } else {
            completion(nil)
        }
    }
    
    private func extractYouTubeVideoId(from urlString: String) -> String? {
        // Extract video ID from various YouTube URL formats
        let patterns = [
            "v=([a-zA-Z0-9_-]+)",           // ?v=VIDEO_ID
            "youtu.be/([a-zA-Z0-9_-]+)",    // youtu.be/VIDEO_ID
            "embed/([a-zA-Z0-9_-]+)"        // /embed/VIDEO_ID
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: urlString, range: NSRange(location: 0, length: urlString.count)) {
                if let range = Range(match.range(at: 1), in: urlString) {
                    return String(urlString[range])
                }
            }
        }
        return nil
    }
    
    private func fetchImageURLFromHTML(urlString: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5.0 // Quick timeout for image extraction
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ LinkPreview: Error fetching HTML for image: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data,
                  let htmlString = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            // Try Open Graph image
            if let ogImage = self.extractMetaContent(from: htmlString, property: "og:image") {
                let absoluteUrl = self.makeAbsoluteURL(ogImage, baseURL: urlString)
                print("🖼️ LinkPreview: Found og:image: \(absoluteUrl)")
                completion(absoluteUrl)
                return
            }
            
            // Try Twitter card image
            if let twitterImage = self.extractMetaContent(from: htmlString, name: "twitter:image") {
                let absoluteUrl = self.makeAbsoluteURL(twitterImage, baseURL: urlString)
                print("🖼️ LinkPreview: Found twitter:image: \(absoluteUrl)")
                completion(absoluteUrl)
                return
            }
            
            completion(nil)
        }.resume()
    }
    
    @available(iOS 13.0, *)
    private func extractSiteName(from metadata: LPLinkMetadata) -> String? {
        if let siteName = metadata.value(forKey: "siteName") as? String, !siteName.isEmpty {
            return siteName
        }
        
        // Extract from URL as fallback
        return metadata.originalURL?.host
    }
    
    // MARK: - HTML Metadata Parsing (Fallback)
    
    /// Fallback method to parse HTML metadata manually
    private func parseHTMLMetadata(for urlString: String, completion: @escaping (LinkPreviewData?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoadingPreview = false
                
                if let error = error {
                    print("❌ HTML parsing error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data,
                      let htmlString = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }
                
                let linkPreview = self?.parseHTMLContent(htmlString, originalURL: urlString)
                
                // Cache the result
                if let linkPreview = linkPreview {
                    self?.previewCache[urlString] = linkPreview
                }
                
                completion(linkPreview)
            }
        }.resume()
    }
    
    /// Parses HTML content to extract Open Graph and meta tags
    private func parseHTMLContent(_ htmlString: String, originalURL: String) -> LinkPreviewData? {
        var title: String?
        var description: String?
        var imageUrl: String?
        var siteName: String?
        
        // Extract Open Graph title
        if let ogTitle = extractMetaContent(from: htmlString, property: "og:title") {
            title = ogTitle
        } else if let htmlTitle = extractHTMLTitle(from: htmlString) {
            title = htmlTitle
        }
        
        // Extract Open Graph description
        if let ogDescription = extractMetaContent(from: htmlString, property: "og:description") {
            description = ogDescription
        } else if let metaDescription = extractMetaContent(from: htmlString, name: "description") {
            description = metaDescription
        }
        
        // Extract Open Graph image
        if let ogImage = extractMetaContent(from: htmlString, property: "og:image") {
            imageUrl = makeAbsoluteURL(ogImage, baseURL: originalURL)
        }
        
        // Extract site name
        if let ogSiteName = extractMetaContent(from: htmlString, property: "og:site_name") {
            siteName = ogSiteName
        }
        
        return LinkPreviewData(
            url: originalURL,
            title: title,
            description: description,
            imageUrl: imageUrl,
            siteName: siteName
        )
    }
    
    // MARK: - HTML Parsing Helpers
    
    private func extractHTMLTitle(from html: String) -> String? {
        let pattern = "<title[^>]*>([^<]+)</title>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: html.utf16.count)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let titleRange = Range(match.range(at: 1), in: html) {
                return String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "<meta[^>]*property=['\"]?\(NSRegularExpression.escapedPattern(for: property))['\"]?[^>]*content=['\"]?([^'\"]*)['\"]?[^>]*>"
        return extractWithPattern(pattern, from: html)
    }
    
    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta[^>]*name=['\"]?\(NSRegularExpression.escapedPattern(for: name))['\"]?[^>]*content=['\"]?([^'\"]*)['\"]?[^>]*>"
        return extractWithPattern(pattern, from: html)
    }
    
    private func extractWithPattern(_ pattern: String, from html: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: html.utf16.count)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let contentRange = Range(match.range(at: 1), in: html) {
                let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : content
            }
        }
        return nil
    }
    
    private func makeAbsoluteURL(_ urlString: String, baseURL: String) -> String {
        if urlString.hasPrefix("http") {
            return urlString
        }
        
        guard let base = URL(string: baseURL) else { return urlString }
        
        if urlString.hasPrefix("//") {
            return "\(base.scheme ?? "https"):\(urlString)"
        }
        
        if urlString.hasPrefix("/") {
            return "\(base.scheme ?? "https")://\(base.host ?? "")\(urlString)"
        }
        
        // Relative URL
        return base.appendingPathComponent(urlString).absoluteString
    }
    
    // MARK: - Cache Management
    
    /// Clears the preview cache
    func clearCache() {
        previewCache.removeAll()
    }
    
    /// Gets cached preview data
    func getCachedPreview(for url: String) -> LinkPreviewData? {
        return previewCache[url]
    }
}
