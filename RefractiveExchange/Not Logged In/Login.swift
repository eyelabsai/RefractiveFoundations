//
//  LoginScreen.swift
//  IOL CON
//
//  Created by Husnain on 27/09/2022.
//

import SwiftUI
import Firebase

struct LoginScreen: View {
    @ObservedObject var model: NotLoggedInViewModel
    @State private var animateIcon: Bool = false
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon - nicely styled
                Image("RF Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .scaleEffect(model.handle.loading ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: model.handle.loading)
                    .padding(.bottom, 40)
                
                CustomTextField(text: $model.user.email, title: "Email")
                
                if !model.resetPassword {
                    CustomTextField(text: $model.password, title: "Password", isPassword: true)
                        .padding(.top, 25)
                }
                
                HStack {
                    Button {
                        withAnimation {
                            if model.resetPassword {
                                model.resetButtonText = "Log in"
                            } else {
                                model.resetButtonText = "Reset Password"
                            }
                            model.resetPassword.toggle()
                        }
                    } label: {
                        Text(model.resetPassword ? "Cancel" : "Forgot Password?")
                            .foregroundColor(.black)
                            .poppinsMedium(16)
                    }
                    Spacer()
                }
                .padding(.top, 20)
                
                CustomButton(loading: $model.handle.loading, title: $model.resetButtonText, width: .constant(UIScreen.main.bounds.width - 50), color: .black, transpositionMode: false) {
                    
                    if model.resetPassword {
                        model.sendResetEmail()
                    } else {                            model.loginUser()
                    }
                }
                .padding(.top, 25)
                
                HStack(spacing: 5) {
                    Spacer()
                    Text("New user?")
                        .foregroundColor(.black)
                        .poppinsMedium(16)
                    
                    NavigationLink {
                        SignupScreen()
                    } label: {
                        Text("Sign up")
                            .foregroundColor(.black)
                            .underline()
                            .poppinsMedium(16)
                    }
                    Spacer()
                }
                .padding(.top, 30)
                
                Spacer()
                
                /*CustomSecondaryLogo()
                 .padding(.bottom, 17) */
            }
            .padding(.horizontal, 25)
            .zIndex(0)
            
            CustomAlert(handle: $model.handle)
                .zIndex(1)
           
                // Subtle loading overlay
                if model.handle.loading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .zIndex(2)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Signing in...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .zIndex(3)
                }
            }
            .navigationBarHidden(true)
        }
    }


//Error popup
struct ErrorView: View {
    
    @State var color = Color.black.opacity(0.7)
    @Binding var alert: Bool
    @Binding var error: String
    var body: some View{
        GeometryReader { _ in
            VStack{
                HStack{
                    Text(self.error == "RESET" ? "Message":"Error")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(self.color)
                    Spacer()
                } //HSTACK
                .padding(.horizontal,25)
                Text(self.error == "RESET" ? "Password Reset Link Has been send to your email" : self.error)
                    .foregroundColor(self.color)
                    .padding(.top)
                    .padding(.horizontal,25)
                Button(action:{
                    self.alert.toggle()
                }){
                    Text(self.error == "RESET" ?  "Ok":"Cancel")
                        .foregroundColor(.white)
                        .padding(.vertical)
                        .frame(width: UIScreen.main.bounds.width - 120)
                } // BUTTON
                .background(Color.red)
                .cornerRadius(10)
                .padding(.top,25)
            }//VSTACK
            .padding(.vertical, 25)
            .frame(width: UIScreen.main.bounds.width - 70)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.top,25)
            .position(x: 190, y: 280)
        }//GEOMETRYREADER
        .background(Color.black.opacity(0.35)
            .edgesIgnoringSafeArea(.all))
    }
}
