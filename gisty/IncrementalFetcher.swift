//
//  IncrementalFetcher.swift
//  gisty
//
//  Created by admin on 17.11.2025.
//

import Foundation
import Combine
import TDLibKit
import SwiftData

/// Incrementally fetches only new messages from Telegram
/// Uses last_message.id to avoid re-downloading old messages
@MainActor
class IncrementalFetcher: ObservableObject {
    // MARK: - Properties
    
    private let telegram: TelegramManager
    private let scheduler: FetchScheduler
    
    @Published var isFetching = false
    @Published var progress: FetchProgress?
    
    // MARK: - Initialization
    
    init(telegram: TelegramManager, scheduler: FetchScheduler) {
        self.telegram = telegram
        self.scheduler = scheduler
        
        AppLogger.logTelegram("🔄 IncrementalFetcher initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetch new messages for a specific chat
    /// - Parameters:
    ///   - chatId: Chat ID to fetch from
    ///   - lastSeenMsgId: Last message ID we've seen (nil = first fetch)
    /// - Returns: Array of new messages
    func fetchNewMessages(
        for chatId: Int64,
        lastSeenMsgId: Int64?
    ) async throws -> [Message] {
        guard telegram.client != nil else {
            throw NSError(domain: "TelegramError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Client not initialized"])
        }
        
        AppLogger.logTelegram("🎯 fetchNewMessages() for chatId: \(chatId), lastSeenMsgId: \(lastSeenMsgId ?? 0)")
        
        // STUB: In real implementation, would fetch from TDLib
        // For now, return empty array to allow compilation
        AppLogger.logTelegram("⚠️ STUB: IncrementalFetcher.fetchNewMessages() - returning empty array")
        
        // Acquire rate limit token
        let rateLimiter = scheduler.getRateLimiter()
        await rateLimiter.acquire(for: chatId)
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        AppLogger.logTelegram("✅ Fetched 0 new messages for chat \(chatId) (stub)")
        
        return []
    }
    
    /// Fetch new messages for all eligible chats
    /// - Returns: Dictionary of chatId -> messages
    func fetchAllEligibleChats() async throws -> [Int64: [Message]] {
        guard !isFetching else {
            AppLogger.warning("⏸️ Already fetching, skipping", category: AppLogger.telegram)
            return [:]
        }
        
        isFetching = true
        defer { isFetching = false }
        
        AppLogger.logTelegram("📅 Fetching all eligible chats...")
        
        // Get scheduled jobs
        let jobs = try await scheduler.scheduleEligibleChats()
        
        guard !jobs.isEmpty else {
            AppLogger.logTelegram("ℹ️ No eligible chats to fetch")
            return [:]
        }
        
        progress = FetchProgress(total: jobs.count, current: 0)
        
        var results: [Int64: [Message]] = [:]
        
        for (index, job) in jobs.enumerated() {
            progress?.current = index + 1
            progress?.currentChatId = job.chatId
            
            do {
                // Mark as fetching
                try await scheduler.markFetching(chatId: job.chatId)
                
                // Get last seen message ID from state
                let chatId = job.chatId
                let state = try scheduler.dataManager.modelContext.fetch(
                    FetchDescriptor<ChatFetchState>(
                        predicate: #Predicate { $0.chatId == chatId }
                    )
                ).first
                
                let lastSeenMsgId = state?.lastSeenMsgId
                
                // Fetch new messages
                let messages = try await fetchNewMessages(
                    for: job.chatId,
                    lastSeenMsgId: lastSeenMsgId
                )
                
                if !messages.isEmpty {
                    results[job.chatId] = messages
                }
                
                // Mark as complete
                try await scheduler.markComplete(
                    chatId: job.chatId,
                    lastMessageId: messages.last?.id,
                    lastMessageDate: messages.last.map { Date(timeIntervalSince1970: TimeInterval($0.date)) },
                    messageCount: messages.count
                )
                
            } catch {
                AppLogger.error("❌ Error fetching chat \(job.chatId)", category: AppLogger.telegram, error: error)
                try? await scheduler.markFailed(chatId: job.chatId, error: error)
            }
            
            // Small delay between chats
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
        }
        
        progress = nil
        AppLogger.logTelegram("✅ Fetched from \(results.count)/\(jobs.count) chats")
        
        return results
    }
}

// MARK: - Supporting Types

struct FetchProgress {
    let total: Int
    var current: Int
    var currentChatId: Int64?
}
