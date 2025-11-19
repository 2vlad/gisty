//
//  gistyApp.swift
//  gisty
//
//  Created by admin on 08.11.2025.
//

import SwiftUI
import SwiftData

@main
struct gistyApp: App {
    // Initialize DataManager
    @StateObject private var dataManager = DataManager.shared
    
    // Initialize TelegramManager
    @StateObject private var telegramManager = TelegramManager.shared
    
    // Initialize UserSettings for theme
    @StateObject private var settings = UserSettings.shared
    
    // Loading state for initial app launch
    @State private var isLoading = true
    @State private var initError: String?
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    LoaderView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .modelContainer(dataManager.modelContainer)
                        .environmentObject(dataManager)
                        .environmentObject(telegramManager)
                        .preferredColorScheme(settings.appTheme.colorScheme)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLoading)
            .task {
                // Register custom fonts programmatically
                FontRegistration.registerFonts()
                
                // Initialize Telegram client
                do {
                    AppLogger.logAppEvent("📱 Initializing Telegram client...")
                    try await telegramManager.initialize()
                    AppLogger.logAppEvent("✅ Telegram client initialized successfully")
                } catch {
                    AppLogger.error("❌ Failed to initialize Telegram", category: AppLogger.app, error: error)
                    initError = error.localizedDescription
                }
                
                // Simulate initial app loading
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                AppLogger.logAppEvent("🚀 App startup complete")
                isLoading = false
            }
        }
    }
}
