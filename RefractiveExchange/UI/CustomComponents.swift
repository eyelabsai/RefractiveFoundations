import SwiftUI

// Custom Button Component
struct CustomButton: View {
    @Binding var loading: Bool
    @Binding var title: String
    @Binding var width: CGFloat
    var color: Color
    var transpositionMode: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: width, height: 50)
                
                if loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .disabled(loading)
    }
}

// Custom TextField Component
struct CustomTextField: View {
    @Binding var text: String
    let title: String
    var isPassword: Bool = false
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ZStack(alignment: .trailing) {
                if isPassword {
                    HStack {
                        if isPasswordVisible {
                            TextField("", text: $text)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .padding(.trailing, 40) // Space for eye button
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("", text: $text)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .padding(.trailing, 40) // Space for eye button
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .textContentType(.password)
                        }
                        
                        Spacer()
                    }
                    
                    // Eye button positioned on the right
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                    }
                    .padding(.trailing, 12)
                } else {
                    TextField("", text: $text)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(title.lowercased().contains("email") ? .emailAddress : .none)
                        .keyboardType(title.lowercased().contains("email") ? .emailAddress : .default)
                }
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// Custom Autocomplete TextField Component
struct CustomAutocompleteField: View {
    @Binding var text: String
    let title: String
    let suggestions: [String]
    @State private var showSuggestions = false
    @State private var filteredSuggestions: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ZStack(alignment: .topLeading) {
                TextField("", text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .onChange(of: text) { newValue in
                        filterSuggestions()
                    }
                    .onTapGesture {
                        showSuggestions = true
                    }
                
                if showSuggestions && !filteredSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSuggestions.prefix(5), id: \.self) { suggestion in
                            Button(action: {
                                text = suggestion
                                showSuggestions = false
                            }) {
                                HStack {
                                    Text(suggestion)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    Spacer()
                                }
                                .background(Color(.systemBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if suggestion != filteredSuggestions.prefix(5).last {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .offset(y: 50)
                    .zIndex(1)
                }
            }
        }
        .onTapGesture {
            // Hide suggestions when tapping outside
            if showSuggestions {
                showSuggestions = false
            }
        }
    }
    
    private func filterSuggestions() {
        if text.isEmpty {
            filteredSuggestions = []
        } else {
            filteredSuggestions = suggestions.filter { suggestion in
                suggestion.lowercased().contains(text.lowercased())
            }
        }
    }
}

// Custom Tab Bar Component
struct CustomTabBar: View {
    @Binding var selected: Int
    let tabItems: [String]
    let tabBarImages: [String]
    var onTabSelected: ((Int) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabItems.count, id: \.self) { index in
                Button(action: {
                    if let onTabSelected = onTabSelected {
                        onTabSelected(index)
                    } else {
                        selected = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabBarImages[index])
                            .font(.system(size: 20))
                            .foregroundColor(selected == index ? .blue : .gray)
                        
                        Text(tabItems[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selected == index ? .blue : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), radius: 5, x: 0, y: -2)
    }
}

// Custom Alert Component
struct CustomAlert: View {
    @Binding var handle: AlertHandler
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if handle.alert {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        handle.alert = false
                    }
                
                VStack(spacing: 20) {
                    // Error Icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(handle.msg)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .font(.system(size: 16))
                    
                    Button("OK") {
                        handle.alert = false
                    }
                    .frame(minWidth: 100)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.system(size: 16, weight: .medium))
                }
                .padding(30)
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 5)
                .padding(40)
                .scaleEffect(handle.alert ? 1.0 : 0.8)
                .opacity(handle.alert ? 1.0 : 0.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: handle.alert)
            }
            .zIndex(999) // Ensure it's always on top
        }
    }
}

// Custom Loading View
struct CustomLoading: View {
    @Binding var handle: AlertHandler
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if handle.loading {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                    
                    Text("Loading...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(40)
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 10)
            }
        }
    }
}

// Custom Toast View Component
struct CustomToastView: View {
    let text: String
    let opacity: Double
    let textColor: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(opacity))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// Custom Comment TextField Component with autocorrect enabled
struct CustomCommentField: View {
    @Binding var text: String
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            TextField("", text: $text)
                .textFieldStyle(CustomTextFieldStyle())
                .autocapitalization(.sentences) // Enable proper capitalization for comments
                .autocorrectionDisabled(false) // Enable autocorrect for comments
                .textContentType(.none)
                .keyboardType(.default)
        }
    }
}

// Font Extensions
extension Text {
    func poppinsBold(_ size: CGFloat) -> some View {
        self.font(.system(size: size, weight: .bold))
    }
    
    func poppinsMedium(_ size: CGFloat) -> some View {
        self.font(.system(size: size, weight: .medium))
    }
    
    func poppinsRegular(_ size: CGFloat) -> some View {
        self.font(.system(size: size, weight: .regular))
    }
} 