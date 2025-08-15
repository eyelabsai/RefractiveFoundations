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
    let onPin: (() -> Void)?
    let onUnpin: (() -> Void)?
    let isPinned: Bool?
    let canPin: Bool
    let canDeleteAny: Bool
    let onMute: (() -> Void)?
    let onUnmute: (() -> Void)?
    let isMuted: Bool?
    let size: CGFloat
    
    @State private var showMenu = false
    
    init(isAuthor: Bool, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, onSave: (() -> Void)? = nil, isSaved: Bool? = nil, onPin: (() -> Void)? = nil, onUnpin: (() -> Void)? = nil, isPinned: Bool? = nil, canPin: Bool = false, canDeleteAny: Bool = false, onMute: (() -> Void)? = nil, onUnmute: (() -> Void)? = nil, isMuted: Bool? = nil, size: CGFloat = 14) {
        self.isAuthor = isAuthor
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onSave = onSave
        self.isSaved = isSaved
        self.onPin = onPin
        self.onUnpin = onUnpin
        self.isPinned = isPinned
        self.canPin = canPin
        self.canDeleteAny = canDeleteAny
        self.onMute = onMute
        self.onUnmute = onUnmute
        self.isMuted = isMuted
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
            
            // Mute/Unmute option (if provided)
            if let isMuted = isMuted {
                if isMuted {
                    if let onUnmute = onUnmute {
                        Button(action: onUnmute) {
                            Label("Unmute Notifications", systemImage: "bell")
                        }
                    }
                } else {
                    if let onMute = onMute {
                        Button(action: onMute) {
                            Label("Mute Notifications", systemImage: "bell.slash")
                        }
                    }
                }
            }
            
            // Pin/Unpin options (for admins/moderators)
            if canPin {
                if let isPinned = isPinned, isPinned {
                    if let onUnpin = onUnpin {
                        Button(action: onUnpin) {
                            Label("Unpin Post", systemImage: "pin.slash")
                        }
                    }
                } else {
                    if let onPin = onPin {
                        Button(action: onPin) {
                            Label("Pin Post", systemImage: "pin")
                        }
                    }
                }
                
                Divider()
            }
            
            // Edit option (only for author)
            if isAuthor, let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            // Delete option (for author or admin with deleteAnyPost permission)
            if (isAuthor || canDeleteAny), let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label(isAuthor ? "Delete" : "Delete Post (Admin)", systemImage: "trash")
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
                canDeleteAny: false,
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
                isSaved: true,
                canDeleteAny: false
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
                canDeleteAny: false,
                size: 12
            )
        }
        .padding()
    }
    .background(Color(.systemGray6))
} 