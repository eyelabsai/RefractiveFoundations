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
    @State private var showImagePicker = false
    @State var postImageData: Data?
    @State private var isLoading = false
    @ObservedObject var data: GetData
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel = CreateViewModel()
    @ObservedObject var feedViewModel = FeedViewModel.shared
    @Binding var tabBarIndex: Int
    
    @State private var inputImage: UIImage?
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
            .padding(.vertical, 7)
            
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
                            .disableAutocorrection(true)
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
                    if let uiImage = inputImage {
                        let image = Image(uiImage: uiImage)
                        HStack {
                            ZStack {
                                GeometryReader { geometry in
                                    let size = min(geometry.size.width, geometry.size.height)
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: size, height: size)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(7)
                                        .clipped()
                                }
                                .frame(width: 100, height: 100)

                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.gray)
                                    .padding(5)
                                    .clipShape(Circle())
                                    .offset(x: 45, y: -45)
                                    .onTapGesture {
                                        inputImage = nil
                                    }
                            }
                            Spacer()
                        }
                        .padding(.leading, 20)
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
            
            HStack {
                Button {
                    showImagePicker.toggle()
                } label: {
                    Image(systemName: "photo")
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.leading, 20)

            
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(inputImage: self.$inputImage)
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
        
        // Prepare image data if image is selected
        if let uiImage = inputImage {
            postImageData = uiImage.jpegData(compressionQuality: 0.7)
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
                    self.inputImage = nil
                    self.postImageData = nil
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
}



