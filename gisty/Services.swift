//
//  Services.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation

// MARK: - LLM Service

enum LLMProvider {
    case openrouter
    case openai
}

class LLMService {
    struct Config {
        let provider: LLMProvider
        let model: String
        let apiKey: String
        let maxTokens: Int
        let temperature: Double
    }
    
    let config: Config
    
    init(config: Config) {
        self.config = config
    }
    
    func generate(prompt: String) async throws -> String {
        return "Generated summary stub"
    }
}

// MARK: - Gist Generator

enum GistPeriod {
    case twentyFourHours
    case seventyTwoHours
}

class GistGenerator {
    let messageCollector: MessageCollector
    let llmService: LLMService
    let dataManager: DataManager
    
    init(messageCollector: MessageCollector, llmService: LLMService, dataManager: DataManager) {
        self.messageCollector = messageCollector
        self.llmService = llmService
        self.dataManager = dataManager
    }
    
    func generateGists(period: GistPeriod, locale: String) async throws -> [Gist] {
        // Stub implementation
        return []
    }
}

// MARK: - Rate Limiter

class RateLimiter {
    private var lastRequestTime: [Int64: Date] = [:]
    private let minInterval: TimeInterval = 0.1 // 100ms between requests
    
    func wait() async {
        // No-op
    }
    
    func acquire(for chatId: Int64? = nil) async {
        // Stub: In real implementation, would throttle requests per chat
        if let chatId = chatId, let lastTime = lastRequestTime[chatId] {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minInterval {
                let delay = minInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        if let chatId = chatId {
            lastRequestTime[chatId] = Date()
        }
        
        // General throttle
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
    }
}

