//
//  TelegramManager.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation
import Combine
import TDLibKit

enum AuthState {
    case unauthorized
    case waitingForPhoneNumber
    case waitingForCode
    case waitingForPassword
    case authorized
    case closing
    case closed
}

enum TelegramError: Error {
    case clientNotInitialized
    case authenticationFailed
    case networkError
    case unknown(String)
}

class TelegramManager: ObservableObject {
    static let shared = TelegramManager()
    
    @Published var authorizationState: AuthState = .unauthorized
    var updateRouter: TelegramUpdateRouter?
    
    // Make client accessible for IncrementalFetcher
    var client: TdClient? {
        _client
    }
    
    private var _client: TdClient?
    
    init() {
        // Stub
    }
    
    func initialize() async throws {
        // Mock initialization
        // In a real app, this would set up TDLib
        self.authorizationState = .authorized // Auto-authorize for demo if no creds
    }
    
    func logout() async throws {
        self.authorizationState = .unauthorized
    }
    
    func loadChats(limit: Int) async throws -> [Chat] {
        // Stub returning empty list or mock data
        return []
    }
}
