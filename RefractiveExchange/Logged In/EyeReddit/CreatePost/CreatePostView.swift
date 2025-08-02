//
//  CreatePostView.swift
//  RefractiveExchange
//
//  Created by Cole Sherman on 6/6/23.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct CreatePostView: View {
    
    @State private var title = ""
    @State private var text = ""
    @State var subreddit = ""
    @State private var selectedSubredditIndex = 0
    // Curated list of refractive surgery-specific subreddits (without "i/All")
    let subredditsWithoutAll = [
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
    @State private var isLoading = false
    @ObservedObject var data: GetData
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel = CreateViewModel()
    @ObservedObject var feedViewModel = FeedViewModel.shared
    @Binding var tabBarIndex: Int
    
    @State private var selectedImages: [UIImage] = [] // Changed to array for multiple images
    @State private var showErrorToast: Bool = false
    @State private var showSuccessToast: Bool = false

    
    
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
                    createPost()
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



                    

                }

            }
            .gesture(DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            

            Spacer()
            Text("Choose Topic: ")
                .bold()
                .foregroundColor(.primary)
            Picker("ChooseTopic", selection: $selectedSubredditIndex) {
                ForEach(0..<subredditsWithoutAll.count) { index in
                    Text(subredditsWithoutAll[index])
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Divider()
            
            // Multi-image picker section
            VStack(alignment: .leading, spacing: 12) {
                MultiImagePicker(selectedImages: $selectedImages, maxImageCount: 5)
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
            postImageData: postImageData
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
                    self.selectedSubredditIndex = 0
                    
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
}



