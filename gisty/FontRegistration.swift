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
        
        for fontName in fontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: nil, subdirectory: "Resources/Fonts") else {
                print("❌ Font file not found: \(fontName)")
                continue
            }
            
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            
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
