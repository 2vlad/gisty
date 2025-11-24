//
//  AppLogger.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation
import OSLog

struct AppLogger {
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gisty", category: "App")
    static let ai = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gisty", category: "AI")
    static let telegram = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gisty", category: "Telegram")
    static let data = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gisty", category: "Data")
    
    static func logAppEvent(_ message: String) {
        app.info("\(message)")
    }
    
    static func logAI(_ message: String) {
        ai.info("\(message)")
    }
    
    static func logTelegram(_ message: String) {
        telegram.info("\(message)")
    }
    
    static func logData(_ message: String) {
        data.info("\(message)")
    }
    
    static func warning(_ message: String, category: Logger) {
        category.warning("\(message)")
    }
    
    static func error(_ message: String, category: Logger, error: Error? = nil) {
        if let error = error {
            category.error("\(message): \(error.localizedDescription)")
        } else {
            category.error("\(message)")
        }
    }
}

