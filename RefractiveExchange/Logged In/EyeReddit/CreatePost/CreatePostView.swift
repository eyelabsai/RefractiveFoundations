//
//  CreatePostView.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/6/23.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import LinkPresentation

struct CreatePostView: View {
    
    @State private var title = ""
    @State private var text = ""
    @State var subreddit = ""
    @State private var selectedSubredditIndex = 0
    // Curated list of refractive surgery-specific subforums
    let subredditsWithoutAll = [
        "Choose one",
        "i/IOLs",
        "i/Surgical Techniques", 
        "i/Complications",
        "i/Refractive Surgery",
        "i/Cataract Surgery",
        "i/Corneal Surgery",
        "i/Residents & Fellows"
    ]
    
    // Original comprehensive list (commented out for now)
    // let subredditsWithoutAll = ["i/Anterior Segment, Cataract, & Cornea", "i/Glaucoma", "i/Retina", "i/Neuro-Opthamology", "i/Pediatric Opthamology", "i/Ocular Oncology", "i/Oculoplastic Surgery", "i/Uveitis", "i/Residents & Fellows", "i/Medical Students", "i/Company Representatives"]

    @State var postImageData: [Data] = [] // Changed to array for multiple images
    @State var postVideoURLs: [URL] = [] // Array for multiple videos
    @State private var isLoading = false
    @ObservedObject var data: GetData
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel = CreateViewModel()
    @ObservedObject var feedViewModel = FeedViewModel.shared
    @Binding var tabBarIndex: Int
    
    @State private var selectedImages: [UIImage] = [] // Changed to array for multiple images
    @State private var selectedVideoURLs: [URL] = [] // Array for selected videos
    @State private var showErrorToast: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var showSubforumPrompt: Bool = false
    @State private var detectedLinks: [String] = []
    @State private var linkPreview: LinkPreviewData? = nil
    @State private var isLoadingLinkPreview: Bool = false
    
    // Mention autocomplete states
    @State private var showingUserSuggestions = false
    @State private var userSuggestions: [User] = []
    @State private var mentionParser = MentionParser()
    
    @ObservedObject private var linkPreviewService = LinkPreviewService.shared

    
    
    var body: some View {
        VStack{
            HStack {
                Image(systemName: "xmark")
                    .font(.system(size: 25))
                    .foregroundColor(.gray)
                    .onTapGesture {
                        withAnimation {
                            tabBarIndex = 0
                        }
                        dismiss()
                    }
                Spacer()
                
                Button("Post") {
                    if selectedSubredditIndex == 0 {
                        showSubforumPrompt = true
                    } else {
                        createPost()
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(title.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(20)
                .disabled(title.isEmpty || isLoading)


            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    TextField("Title", text: $title)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 15)
                        .background(Color(.systemBackground))
                        .onChange(of: title) { _ in
                            detectLinksInText(text)
                        }
                    Divider()
                        .padding(.horizontal, 15)
                    
                    if showErrorToast {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                CustomToastView(text: "Create post error",opacity: 0.2,textColor: .primary)
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                        .onAppear(perform: {
                            // Automatically hide after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showErrorToast = false
                                }
                            }
                        })
                    }
                    
                    if showSuccessToast {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                CustomToastView(text: "Post submitted successfully!",opacity: 0.2,textColor: .green)
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                        .onAppear(perform: {
                            // Automatically hide after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showSuccessToast = false
                                }
                            }
                        })
                    }
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .foregroundColor(.primary)
                            .font(.title3)
                            .lineSpacing(5)
                            .autocorrectionDisabled(false) // Enable autocorrect for post content
                            .padding()
                            .frame(minWidth: UIScreen.main.bounds.width, maxWidth: UIScreen.main.bounds.width, minHeight: 80, maxHeight: UIScreen.main.bounds.height / 2)
                        
                        if text.isEmpty {
                            Text("body text (optional)")
                                .foregroundColor(.gray)
                                .font(.title3)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: text) { newValue in
                        detectLinksInText(newValue)
                        checkForMentions(in: newValue)
                    }
                    
                    // Link Preview Section
                    if isLoadingLinkPreview {
                        LinkPreviewLoadingView()
                            .padding(.horizontal, 15)
                    } else if let linkPreview = linkPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Link Preview")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Remove") {
                                    self.linkPreview = nil
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            }
                            
                            LinkPreviewView(linkPreview: linkPreview) {
                                // Handle link tap if needed
                                if let url = URL(string: linkPreview.url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        .padding(.horizontal, 15)
                    }
                    
                    // User suggestions for mentions
                    if showingUserSuggestions && !userSuggestions.isEmpty {
                        userSuggestionsView
                    }
                    



                    

                }

            }
            .gesture(DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            

            Spacer()
            Text("Specify a SubForum: ")
                .bold()
                .foregroundColor(.primary)
            Picker("SpecifySubForum", selection: $selectedSubredditIndex) {
                ForEach(0..<subredditsWithoutAll.count) { index in
                    Text(subredditsWithoutAll[index])
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Divider()
            
            // Media picker section
            VStack(alignment: .leading, spacing: 16) {
                // Multi-image picker section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Images")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    MultiImagePicker(selectedImages: $selectedImages, maxImageCount: 5)
                }
                
                // Multi-video picker section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Videos")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    MultiVideoPicker(selectedVideoURLs: $selectedVideoURLs, maxVideoCount: 3)
                }
            }
            .padding(.horizontal, 20)
            
        }

        .overlay {
            if isLoading    {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(2.0)
            }
            
        }
        .onReceive(viewModel.$didUpload) { success in
            if success   {
                viewModel.didUpload = false
                dismiss()
            }
        }
        .alert("Choose a SubForum", isPresented: $showSubforumPrompt) {
            Button("OK") {
                showSubforumPrompt = false
            }
        } message: {
            Text("Please select a subforum before posting.")
        }
    }
    
    // MARK: - Post Creation Function
    private func createPost() {
        guard !title.isEmpty else { return }
        
        // Prevent multiple submissions
        guard !isLoading else { return }
        
        // Prepare image data for multiple images
        postImageData = []
        for uiImage in selectedImages {
            // Resize image for better performance and storage efficiency
            let imageToProcess = resizeImage(image: uiImage, targetSize: CGSize(width: 800, height: 800)) ?? uiImage
            if let imageData = imageToProcess.jpegData(compressionQuality: 0.7) {
                postImageData.append(imageData)
            }
        }
        
        // Prepare video URLs
        postVideoURLs = selectedVideoURLs
        
        // Clean up text field
        let finalText = text
        
        isLoading = true
        
        // Create post using Firebase
        CreatePostViewHandler.createPost(
            data: data,
            title: title,
            text: finalText,
            subredditList: subredditsWithoutAll,
            selectedSubredditIndex: selectedSubredditIndex,
            postImageData: postImageData,
            postVideoURLs: postVideoURLs,
            linkPreview: linkPreview
        ) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Post created successfully
                    print("✅ Post created successfully!")
                    
                    // Clear form fields
                    self.title = ""
                    self.text = ""
                    self.selectedImages = []
                    self.postImageData = []
                    self.selectedVideoURLs = []
                    self.postVideoURLs = []
                    self.selectedSubredditIndex = 0
                    self.linkPreview = nil
                    self.detectedLinks = []
                    
                    // Show success feedback
                    withAnimation {
                        self.showSuccessToast = true
                    }
                    
                    // Refresh the feed
                    self.feedViewModel.refreshPosts()
                    
                    // Navigate back to feed immediately
                    withAnimation {
                        self.tabBarIndex = 0
                    }
                    self.dismiss()
                } else {
                    // Show error
                    print("❌ Failed to create post")
                    withAnimation {
                        self.showErrorToast = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        // Safety checks to prevent NaN values
        guard size.width > 0 && size.height > 0 && 
              targetSize.width > 0 && targetSize.height > 0 &&
              size.width.isFinite && size.height.isFinite &&
              targetSize.width.isFinite && targetSize.height.isFinite else {
            print("⚠️ Invalid image dimensions detected")
            return image
        }
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // Additional safety check for ratio
        guard ratio > 0 && ratio.isFinite else {
            print("⚠️ Invalid ratio calculated")
            return image
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Final safety check for new size
        guard newSize.width > 0 && newSize.height > 0 &&
              newSize.width.isFinite && newSize.height.isFinite else {
            print("⚠️ Invalid new size calculated")
            return image
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    // MARK: - Link Detection
    private func detectLinksInText(_ text: String) {
        // Combine title and text to search for URLs
        let combinedText = "\(title) \(text)"
        let urls = linkPreviewService.extractURLs(from: combinedText)
        
        if let firstURL = urls.first, firstURL != detectedLinks.first {
            print("🔗 New link detected, generating preview...")
            detectedLinks = urls
            generateLinkPreview(for: firstURL)
        } else if urls.isEmpty && !detectedLinks.isEmpty {
            detectedLinks = []
            linkPreview = nil
        }
    }
    
    private func generateLinkPreview(for url: String) {
        print("🔄 Starting link preview generation for: \(url)")
        isLoadingLinkPreview = true
        
        linkPreviewService.generateLinkPreview(for: url) { preview in
            DispatchQueue.main.async {
                self.isLoadingLinkPreview = false
                if let preview = preview {
                    print("✅ Link preview generated successfully: \(preview.title ?? "No title")")
                    self.linkPreview = preview
                } else {
                    print("❌ Failed to generate link preview")
                    self.linkPreview = nil
                }
            }
        }
    }
    
    // MARK: - User Suggestions View
    private var userSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(userSuggestions, id: \.id) { user in
                Button(action: {
                    insertMention(user: user)
                }) {
                    HStack {
                        AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(user.firstName) \(user.lastName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("@\(!user.exchangeUsername.isEmpty ? user.exchangeUsername : "\(user.firstName)\(user.lastName)".replacingOccurrences(of: " ", with: "").lowercased())")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if user.id != userSuggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 15)
    }
    
    // MARK: - Mention Functions
    private func checkForMentions(in text: String) {
        // Find the last @ symbol and check if we're typing a username
        guard let lastAtIndex = text.lastIndex(of: "@") else {
            showingUserSuggestions = false
            return
        }
        
        let afterAtIndex = text.index(after: lastAtIndex)
        guard afterAtIndex < text.endIndex else {
            showingUserSuggestions = false
            return
        }
        
        let afterAt = text[afterAtIndex...]
        
        // Check if there's a space after the @ (if so, we're not in a mention anymore)
        if afterAt.contains(" ") || afterAt.contains("\n") {
            showingUserSuggestions = false
            return
        }
        
        let currentPrefix = String(afterAt)
        
        // Only search if we have at least 1 character after @
        if currentPrefix.count >= 1 {
            mentionParser.searchUsers(with: currentPrefix) { users in
                DispatchQueue.main.async {
                    self.userSuggestions = users
                    self.showingUserSuggestions = !users.isEmpty
                }
            }
        } else {
            showingUserSuggestions = false
        }
    }
    
    private func insertMention(user: User) {
        // Find the last @ and replace everything after it with the username
        guard let lastAtIndex = text.lastIndex(of: "@") else { return }
        
        let beforeAt = text[..<lastAtIndex]
        
        // Use exchangeUsername if available, otherwise create one from first/last name
        let username: String
        if !user.exchangeUsername.isEmpty {
            username = user.exchangeUsername
        } else {
            // Create username from first and last name (remove spaces, lowercase)
            username = "\(user.firstName)\(user.lastName)".replacingOccurrences(of: " ", with: "").lowercased()
        }
        
        let newText = beforeAt + "@\(username) "
        
        text = String(newText)
        showingUserSuggestions = false
    }
}



