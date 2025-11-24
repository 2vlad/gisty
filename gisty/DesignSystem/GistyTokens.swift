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
/// Based on the "newspaper article in a card" aesthetic
enum GistyTokens {
    
    // MARK: - Colors
    
    enum Colors {
        // Brand accents
        static let accentRed = Color(hex: 0xFD6457)      // Breaking/important
        static let accentYellow = Color(hex: 0xD4AF37)   // Time/Gold (darker for readability on white)
        static let accentGreen = Color(hex: 0x2F7A45)    // Positive/success
        
        // Surface
        static let surfaceCard = Color.white             // Clean white surface
        static let bgApp = Color.white                   // White app background
        
        // Text
        static let textPrimary = Color(hex: 0x000000)    // Deep black
        static let textSecondary = Color(hex: 0x8E8E93)  // Standard gray
        static let textGold = Color(hex: 0xC5A028)       // Gold text for times
        
        // UI elements
        static let divider = Color(hex: 0xE5E5EA)        // Light gray divider
        static let badgeBg = Color.black.opacity(0.06)
        static let badgeText = Color(hex: 0x6B6B6B)
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Brand: "Gisty ✱" in app bar
        static let brand = Font.custom("PPNeueMontreal-Bold", size: 32)
        static let brandWeight: Font.Weight = .heavy
        static let brandLineHeight: CGFloat = 38
        
        // Section title: publisher names
        static let sectionTitle = Font.custom("PPNeueMontreal-Medium", size: 20)
        static let sectionTitleWeight: Font.Weight = .semibold
        static let sectionTitleLineHeight: CGFloat = 26
        
        // Body XL: main gist text (EB Garamond)
        static let bodyXL = Font.custom("EB Garamond", size: 20)
        static let bodyXLWeight: Font.Weight = .regular
        static let bodyXLLineHeight: CGFloat = 28
        
        // Meta: badge text, small labels
        static let meta = Font.custom("PPNeueMontreal-Medium", size: 13)
        static let metaWeight: Font.Weight = .semibold
        static let metaLineHeight: CGFloat = 16
        
        // Menu: navigation items
        static let menu = Font.custom("PPNeueMontreal-Medium", size: 16)
        static let menuWeight: Font.Weight = .semibold
        static let menuLineHeight: CGFloat = 20
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Radius
    
    enum Radius {
        static let card: CGFloat = 24
        static let chip: CGFloat = 16
        static let icon: CGFloat = 12
    }
    
    // MARK: - Elevation (shadows)
    
    enum Elevation {
        static let card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: .black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
        
        static let cardPressed: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: .black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        static let marker: CGFloat = 18      // ✱ marker
        static let avatar: CGFloat = 24      // Publisher avatar
        static let hamburger: CGFloat = 24   // Menu icon
        static let badge: CGFloat = 24       // Unread count circle
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

// MARK: - Typography Extensions

extension View {
    /// Apply line height to text
    func lineHeight(_ height: CGFloat, font: Font) -> some View {
        self.font(font)
            .lineSpacing(height - UIFont.preferredFont(forTextStyle: .body).lineHeight)
    }
}

// MARK: - Custom Text Styles

struct GistyTextStyle: ViewModifier {
    enum Style {
        case brand
        case sectionTitle
        case bodyXL
        case meta
        case menu
    }
    
    let style: Style
    let color: Color
    
    func body(content: Content) -> some View {
        switch style {
        case .brand:
            content
                .font(GistyTokens.Typography.brand)
                .lineSpacing(lineSpacing(for: .brand))
                .foregroundColor(color)
            
        case .sectionTitle:
            content
                .font(GistyTokens.Typography.sectionTitle)
                .lineSpacing(lineSpacing(for: .sectionTitle))
                .foregroundColor(color)
            
        case .bodyXL:
            content
                .font(GistyTokens.Typography.bodyXL)
                .lineSpacing(lineSpacing(for: .bodyXL))
                .foregroundColor(color)
            
        case .meta:
            content
                .font(GistyTokens.Typography.meta)
                .lineSpacing(lineSpacing(for: .meta))
                .foregroundColor(color)
            
        case .menu:
            content
                .font(GistyTokens.Typography.menu)
                .lineSpacing(lineSpacing(for: .menu))
                .foregroundColor(color)
        }
    }
    
    private func lineSpacing(for style: Style) -> CGFloat {
        let baseLineHeight: CGFloat
        let fontSize: CGFloat
        
        switch style {
        case .brand:
            baseLineHeight = GistyTokens.Typography.brandLineHeight
            fontSize = 32
        case .sectionTitle:
            baseLineHeight = GistyTokens.Typography.sectionTitleLineHeight
            fontSize = 20
        case .bodyXL:
            baseLineHeight = GistyTokens.Typography.bodyXLLineHeight
            fontSize = 20
        case .meta:
            baseLineHeight = GistyTokens.Typography.metaLineHeight
            fontSize = 13
        case .menu:
            baseLineHeight = GistyTokens.Typography.menuLineHeight
            fontSize = 16
        }
        
        return baseLineHeight - fontSize
    }
}

extension View {
    func gistyTextStyle(_ style: GistyTextStyle.Style, color: Color = GistyTokens.Colors.textPrimary) -> some View {
        self.modifier(GistyTextStyle(style: style, color: color))
    }
}
