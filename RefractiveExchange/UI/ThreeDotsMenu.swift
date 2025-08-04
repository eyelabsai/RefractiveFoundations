//
//  ThreeDotsMenu.swift
//  RefractiveExchange
//
//  Created by AI Assistant on 12/19/24.
//

import SwiftUI

struct ThreeDotsMenu: View {
    let isAuthor: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onSave: (() -> Void)?
    let isSaved: Bool?
    let size: CGFloat
    
    @State private var showMenu = false
    
    init(isAuthor: Bool, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, onSave: (() -> Void)? = nil, isSaved: Bool? = nil, size: CGFloat = 14) {
        self.isAuthor = isAuthor
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onSave = onSave
        self.isSaved = isSaved
        self.size = size
    }
    
    var body: some View {
        Menu {
            // Save option (if provided)
            if let onSave = onSave, let isSaved = isSaved {
                Button(action: onSave) {
                    Label(
                        isSaved ? "Unsave" : "Save",
                        systemImage: isSaved ? "bookmark.slash" : "bookmark"
                    )
                }
            }
            
            // Edit option (only for author)
            if isAuthor, let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            // Delete option (only for author)
            if isAuthor, let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: size + 8, height: size + 8)
                .contentShape(Rectangle())
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        // Author menu with all options (post size)
        HStack {
            Text("Post Menu (Large):")
            Spacer()
            ThreeDotsMenu(
                isAuthor: true,
                onEdit: { print("Edit tapped") },
                onDelete: { print("Delete tapped") },
                onSave: { print("Save tapped") },
                isSaved: false,
                size: 16
            )
        }
        .padding()
        
        // Non-author menu with save only
        HStack {
            Text("Non-Author Menu:")
            Spacer()
            ThreeDotsMenu(
                isAuthor: false,
                onSave: { print("Save tapped") },
                isSaved: true
            )
        }
        .padding()
        
        // Author menu without save (comment size)
        HStack {
            Text("Comment Menu (Small):")
            Spacer()
            ThreeDotsMenu(
                isAuthor: true,
                onEdit: { print("Edit tapped") },
                onDelete: { print("Delete tapped") },
                size: 12
            )
        }
        .padding()
    }
    .background(Color(.systemGray6))
} 