//
//  SideMenuView.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/7/23.
//

import SwiftUI

struct SideMenuView: View {
    
    @Binding var presentSideMenu: Bool
    @Binding var currentSubreddit: String
    @State var feedModel: FeedViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var darkModeManager: DarkModeManager
    
    var body: some View {
        HStack {
            
            ZStack{
                VStack(alignment: .leading, spacing: 0) {
                    Text("SubForums")
                        .poppinsBold(24)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .padding(.leading, 20)
                    
                    Divider()
                    
                    ForEach(subreddits, id: \.self) { row in
                        RowView(isSelected: currentSubreddit == row, imageName: "", title: row) {
                            withAnimation {
                                presentSideMenu.toggle()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                currentSubreddit = row
                                feedModel.currentSubreddit = row
                                feedModel.refreshPosts()
                            }
                        }
                    }
                    
                    Button(action: {
                        darkModeManager.toggleDarkMode()
                    }) {
                        VStack(alignment: .leading){
                            HStack(spacing: 20){
                                Image(systemName: darkModeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(darkModeManager.isDarkMode ? .yellow : .purple)
                                Text(darkModeManager.isDarkMode ? "Light Mode" : "Dark Mode")
                                    .poppinsRegular(14)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 50)
                    .background(
                        colorScheme == .dark ? Color.black : Color.white
                    )
                    
                    Spacer()
                }
                .padding(.top, 20)
                .frame(width: 270)
                .background(
                    colorScheme == .dark ? Color.black : Color.white
                )
            }
            
            
            Spacer()
        }
        .background(.clear)
    }
    
    func RowView(isSelected: Bool, imageName: String, title: String, hideDivider: Bool = false, action: @escaping (()->())) -> some View{
        Button{
            action()
        } label: {
            VStack(alignment: .leading){
                HStack(spacing: 20){
                    Rectangle()
                        .fill(isSelected ? .blue : colorScheme == .dark ? Color.black : Color.white)
                        .frame(width: 5)
                    .frame(width: 30, height: 30)
                    Text(title)
                        .poppinsRegular(14)
                        .foregroundColor(isSelected ? (colorScheme == .dark ? Color.white : Color.black) : .gray)
                    Spacer()
                }
            }
        }
        .frame(height: 50)
        .background(
            LinearGradient(colors: [isSelected ? .blue.opacity(0.5) : (colorScheme == .dark ? Color.black : Color.white), (colorScheme == .dark ? Color.black : Color.white)], startPoint: .leading, endPoint: .trailing)
        )
    }
    
    // Removed - now using DarkModeManager

    
}

// Curated list of refractive surgery-specific subreddits
let subreddits = [
    "i/All",
    "i/IOLs",
    "i/Surgical Techniques", 
    "i/Complications",
    "i/Refractive Surgery",
    "i/Cataract Surgery",
    "i/Corneal Surgery",
    "i/Residents & Fellows"
]

// Original comprehensive list (commented out for now)
// let subreddits = ["i/All", "i/Anterior Segment, Cataract, & Cornea", "i/Glaucoma", "i/Retina", "i/Neuro-Opthamology", "i/Pediatric Opthamology", "i/Ocular Oncology", "i/Oculoplastic Surgery", "i/Uveitis", "i/Residents & Fellows", "i/Medical Students", "i/Company Representatives"]
