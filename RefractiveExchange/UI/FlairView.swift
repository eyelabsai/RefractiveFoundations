//
//  FlairView.swift
//  RefractiveExchange
//
//  Created by Assistant
//

import SwiftUI

struct FlairView: View {
    let flair: String
    
    var body: some View {
        Text(flair)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundColor(textColor(for: flair))
            .background(backgroundColor(for: flair))
            .cornerRadius(4)
    }
    
    private func backgroundColor(for flair: String) -> Color {
        switch flair {
        case "Refractive Surgeon":
            return .blue.opacity(0.15)
        case "Resident":
            return .green.opacity(0.15)
        case "Fellow":
            return .purple.opacity(0.15)
        case "Optometrist/APP":
            return .orange.opacity(0.15)
        case "Industry":
            return .gray.opacity(0.2)
        default:
            return .gray.opacity(0.1)
        }
    }
    
    private func textColor(for flair: String) -> Color {
        switch flair {
        case "Refractive Surgeon":
            return .blue
        case "Resident":
            return .green
        case "Fellow":
            return .purple
        case "Optometrist/APP":
            return .orange
        case "Industry":
            return .primary
        default:
            return .secondary
        }
    }
} 