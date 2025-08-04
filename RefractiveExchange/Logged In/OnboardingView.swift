//
//  OnboardingView.swift
//  RefractiveExchange
//
//  Created by Assistant on 1/26/2025.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentSlide = 0
    @Environment(\.colorScheme) var colorScheme
    let onComplete: () -> Void
    
    private let slides = [
        OnboardingSlide(
            title: "Welcome to Refractive Exchange",
            subtitle: "Connect with fellow eye care professionals",
            description: "Join the community to share insights, cases, and expertise in refractive surgery.",
            systemIcon: "eye.fill",
            iconColor: .blue
        ),
        OnboardingSlide(
            title: "Share & Discover",
            subtitle: "Post cases, ask questions, get answers",
            description: "Share your interesting cases, learn from others' experiences, and discover the latest techniques and technologies.",
            systemIcon: "bubble.left.and.bubble.right.fill",
            iconColor: .green,
            showPostCreationMockup: true
        ),
        OnboardingSlide(
            title: "Images and Comments",
            subtitle: "Engage with posts and share visuals",
            description: "Add images to your posts, comment on others' cases, and engage with the community through rich media and discussions.",
            systemIcon: "photo.on.rectangle.angled",
            iconColor: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with logo
            VStack(spacing: 16) {
                Image("RF Icon")
                    .renderingMode(colorScheme == .dark ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                
                Text("Refractive Exchange")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // Slide content
            TabView(selection: $currentSlide) {
                ForEach(0..<slides.count, id: \.self) { index in
                    OnboardingSlideView(slide: slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.5), value: currentSlide)
            
            Spacer()
            
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(index == currentSlide ? .blue : .gray.opacity(0.3))
                        .animation(.easeInOut(duration: 0.3), value: currentSlide)
                }
            }
            .padding(.bottom, 40)
            
            // Navigation buttons
            HStack(spacing: 20) {
                if currentSlide > 0 {
                    Button("Previous") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSlide -= 1
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                } else {
                    Spacer()
                        .frame(width: 80) // Maintain layout balance
                }
                
                Spacer()
                
                Button(currentSlide == slides.count - 1 ? "Get Started!" : "Next") {
                    if currentSlide == slides.count - 1 {
                        onComplete()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSlide += 1
                        }
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && currentSlide > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSlide -= 1
                        }
                    } else if value.translation.width < -threshold && currentSlide < slides.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSlide += 1
                        }
                    }
                }
        )
    }
}

struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon, custom image, or mockup
            if slide.showPostCreationMockup {
                // Post creation interface mockup - COMMENTED OUT FOR MIDDLE SLIDE
                // PostCreationMockup()
                //     .frame(maxWidth: 280, maxHeight: 200)
                //     .padding(.top, 20)
            } else if let customImage = slide.customImage {
                // Custom image (screenshot)
                Image(customImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.top, 20)
            } else {
                // System icon with animated background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    slide.iconColor.opacity(0.1),
                                    slide.iconColor.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: slide.systemIcon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(slide.iconColor)
                }
                .padding(.top, 20)
            }
            
            VStack(spacing: 16) {
                Text(slide.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(slide.subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(slide.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

struct OnboardingSlide {
    let title: String
    let subtitle: String
    let description: String
    let systemIcon: String
    let iconColor: Color
    let customImage: String?
    let showPostCreationMockup: Bool
    
    init(title: String, subtitle: String, description: String, systemIcon: String, iconColor: Color, customImage: String? = nil, showPostCreationMockup: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.systemIcon = systemIcon
        self.iconColor = iconColor
        self.customImage = customImage
        self.showPostCreationMockup = showPostCreationMockup
    }
}

struct PostCreationMockup: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("REFRACTIVE FOUNDATIONS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Post") {
                    // Mock action
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Content area
            VStack(alignment: .leading, spacing: 16) {
                // Title field
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 40)
                    .overlay(
                        HStack {
                            Text("Title")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                    )
                
                // Body text field
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 80)
                    .overlay(
                        HStack {
                            Text("body text (optional)")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    )
                
                Spacer()
                
                // Topic selection
                VStack(spacing: 8) {
                    Text("Choose Topic:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("i/IOLs")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Image selection button
                HStack {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    Text("Select Images")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

#Preview {
    OnboardingView(onComplete: {})
}