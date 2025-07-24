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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            if isPassword {
                SecureField("", text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
            } else {
                TextField("", text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
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
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        handle.alert = false
                    }
                
                VStack(spacing: 20) {
                    Text("Alert")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(handle.msg)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    Button("OK") {
                        handle.alert = false
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(30)
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding(40)
            }
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