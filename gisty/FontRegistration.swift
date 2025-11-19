//
//  FontRegistration.swift
//  gisty
//
//  Created by admin on 17.11.2025.
//

import Foundation
import UIKit
import CoreText

/// Registers custom fonts programmatically since Xcode GENERATE_INFOPLIST_FILE
/// doesn't properly create UIAppFonts array
struct FontRegistration {
    static func registerFonts() {
        let fontNames = [
            "EBGaramond-Regular.ttf",
            "EBGaramond-Medium.ttf",
            "PPNeueMontreal-Bold.otf",
            "PPNeueMontreal-Medium.otf",
            "PPNeueMontreal-Book.otf",
            "PPNeueMontreal-Thin.otf",
            "PPNeueMontreal-Italic.otf",
            "PPNeueMontreal-SemiBolditalic.otf"
        ]
        
        print("🔤 Registering custom fonts...")
        print("📁 Bundle path: \(Bundle.main.bundlePath)")
        
        for fontName in fontNames {
            // Try multiple search strategies
            var fontURL: URL?
            
            // Strategy 1: With subdirectory "Resources/Fonts"
            fontURL = Bundle.main.url(forResource: fontName, withExtension: nil, subdirectory: "Resources/Fonts")
            
            // Strategy 2: Without extension, trying to strip it first
            if fontURL == nil {
                let nameWithoutExt = (fontName as NSString).deletingPathExtension
                let ext = (fontName as NSString).pathExtension
                fontURL = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext, subdirectory: "Resources/Fonts")
            }
            
            // Strategy 3: Without subdirectory
            if fontURL == nil {
                fontURL = Bundle.main.url(forResource: fontName, withExtension: nil)
            }
            
            // Strategy 4: Search in all bundle resources
            if fontURL == nil, let resourcePath = Bundle.main.resourcePath {
                let fontPath = (resourcePath as NSString).appendingPathComponent("Resources/Fonts/\(fontName)")
                if FileManager.default.fileExists(atPath: fontPath) {
                    fontURL = URL(fileURLWithPath: fontPath)
                }
            }
            
            guard let url = fontURL else {
                print("❌ Font file not found: \(fontName)")
                print("   Tried Resources/Fonts, root, and resource path")
                continue
            }
            
            print("📍 Found: \(fontName) at \(url.path)")
            
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            
            if success {
                print("✅ Registered: \(fontName)")
            } else if let error = error?.takeRetainedValue() {
                print("❌ Failed to register \(fontName): \(error)")
            }
        }
        
        print("🔤 Font registration complete!")
        print("")
    }
}
