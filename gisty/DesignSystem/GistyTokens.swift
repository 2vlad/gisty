//
//  GistyTokens.swift
//  gisty
//
//  Design tokens for Gisty brand
//  Created by Claude Code on 09.11.2025.
//

import SwiftUI

// MARK: - Design Tokens

/// Core design tokens for the Gisty app
/// Based on the "Airy Agenda" aesthetic
enum GistyTokens {
    
    // MARK: - Colors
    
    enum Colors {
        // Base
        static let bgApp = Color.white
        static let textPrimary = Color(hex: 0x1A1A1A)    // Soft Black
        static let textSecondary = Color(hex: 0x8E8E93)  // Neutral Gray
        static let divider = Color(hex: 0xF2F2F7)        // Very subtle divider
        
        // Heatmap / Volume Indication
        // Used to indicate summary depth based on message count
        static let heatLow = Color(hex: 0x8E8E93)        // Cold (Low activity)
        static let heatMedium = Color(hex: 0xE0A82E)     // Warm (Medium activity)
        static let heatHigh = Color(hex: 0xFF453A)       // Hot (High activity/Breaking)
        
        // Functional
        static let accent = Color(hex: 0x007AFF)         // Standard interactive
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Single friendly font family: PP Neue Montreal
        // We use weights to create rhythm
        
        static let fontName = "PPNeueMontreal-Medium"
        static let fontNameBold = "PPNeueMontreal-Bold"
        static let fontNameBook = "PPNeueMontreal-Book"
        
        // Date Headers (e.g., "24")
        static let dateBig = Font.custom(fontNameBold, size: 48)
        
        // Day Names (e.g., "Tomorrow")
        static let dateLabel = Font.custom(fontName, size: 24)
        
        // Time (e.g., "10:00 AM")
        static let time = Font.custom(fontName, size: 15)
        
        // Source Title
        static let sourceTitle = Font.custom(fontName, size: 17)
        
        // Summary Body
        static let summary = Font.custom(fontNameBook, size: 16)
        
        // Meta/Badge
        static let meta = Font.custom(fontName, size: 12)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48 // "Breathing" space
    }
}

// MARK: - Color Extension (Hex Support)

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
