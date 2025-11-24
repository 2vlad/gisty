//
//  ConfigurationManager.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    @Published var openRouterApiKey: String? {
        didSet {
            if let key = openRouterApiKey {
                UserDefaults.standard.set(key, forKey: "OpenRouterApiKey")
            }
        }
    }
    
    var hasValidOpenRouterCredentials: Bool {
        return openRouterApiKey != nil && !openRouterApiKey!.isEmpty
    }
    
    private init() {
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "OpenRouterApiKey")
    }
}

