//
//  UserSettings.swift
//  gisty
//
//  User preferences and settings
//

import Foundation
import SwiftUI
import Combine

/// App theme preference
enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Language for gist summaries
enum Language: String, CaseIterable {
    case english = "English"
    case russian = "Русский"
    
    var code: String {
        switch self {
        case .english: return "en"
        case .russian: return "ru"
        }
    }
    
    var icon: String {
        switch self {
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        }
    }
}

/// Time period for message counting
enum MessagePeriod: String, CaseIterable {
    case hour
    case sixHours
    case twelveHours
    case day
    
    var displayName: String {
        switch self {
        case .hour: return L.oneHour
        case .sixHours: return L.sixHours
        case .twelveHours: return L.twelveHours
        case .day: return L.twentyFourHours
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .hour: return 60 * 60
        case .sixHours: return 6 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .day: return 24 * 60 * 60
        }
    }
    
    var icon: String {
        switch self {
        case .hour: return "clock"
        case .sixHours: return "clock.badge.checkmark"
        case .twelveHours: return "clock.arrow.circlepath"
        case .day: return "clock.fill"
        }
    }
}

/// User settings manager
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var appTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
        }
    }
    
    @Published var language: Language = .english {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "language")
        }
    }
    
    @Published var messagePeriod: MessagePeriod = .day {
        didSet {
            // Save as string key instead of rawValue
            let key: String
            switch messagePeriod {
            case .hour: key = "hour"
            case .sixHours: key = "sixHours"
            case .twelveHours: key = "twelveHours"
            case .day: key = "day"
            }
            UserDefaults.standard.set(key, forKey: "messagePeriod")
        }
    }
    
    /// Get start date for message counting
    var periodStartDate: Date {
        Date().addingTimeInterval(-messagePeriod.seconds)
    }
    
    private init() {
        // Load saved theme
        if let savedRaw = UserDefaults.standard.string(forKey: "appTheme"),
           let saved = AppTheme(rawValue: savedRaw) {
            appTheme = saved
        }
        
        // Load saved language
        if let savedRaw = UserDefaults.standard.string(forKey: "language"),
           let saved = Language(rawValue: savedRaw) {
            language = saved
        }
        
        // Load saved period by string key
        if let savedKey = UserDefaults.standard.string(forKey: "messagePeriod") {
            switch savedKey {
            case "hour": messagePeriod = .hour
            case "sixHours": messagePeriod = .sixHours
            case "twelveHours": messagePeriod = .twelveHours
            case "day": messagePeriod = .day
            default: break
            }
        }
    }
}
