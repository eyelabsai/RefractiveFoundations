import SwiftUI
import Combine

class DarkModeManager: ObservableObject {
    static let shared = DarkModeManager()
    
    @Published var isDarkMode: Bool {
        didSet {
            saveThemePreference()
            applyTheme()
        }
    }
    
    private init() {
        // Load saved preference or default to system setting
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? false
        applyTheme()
    }
    
    func toggleDarkMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDarkMode.toggle()
        }
    }
    
    private func saveThemePreference() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
    
    func applyTheme() {
        DispatchQueue.main.async {
            // Update all windows in the app
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = self.isDarkMode ? .dark : .light
            }
        }
    }
    
    // Get appropriate colors for current theme
    var primaryBackgroundColor: Color {
        isDarkMode ? Color.black : Color.white
    }
    
    var secondaryBackgroundColor: Color {
        isDarkMode ? Color(.systemGray6) : Color(.systemGray6)
    }
    
    var primaryTextColor: Color {
        isDarkMode ? Color.white : Color.black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? Color(.systemGray) : Color(.systemGray)
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color(.systemGray5) : Color.white
    }
    
    var separatorColor: Color {
        isDarkMode ? Color(.systemGray4) : Color(.separator)
    }
}

// Environment extension for easy access
struct DarkModeKey: EnvironmentKey {
    static let defaultValue = DarkModeManager.shared
}

extension EnvironmentValues {
    var darkModeManager: DarkModeManager {
        get { self[DarkModeKey.self] }
        set { self[DarkModeKey.self] = newValue }
    }
} 