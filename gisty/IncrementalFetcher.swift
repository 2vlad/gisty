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
        guard let client = telegram.client else {
            throw TelegramError.clientNotInitialized
        }
        
        AppLogger.logTelegram("🎯 fetchNewMessages() for chatId: \(chatId), lastSeenMsgId: \(lastSeenMsgId ?? 0)")
        
        // 🚀 OPTIMIZATION: First, quickly check if there are new messages
        let chat = try await client.send(GetChat(chatId: chatId))
        
        guard let lastMessageId = chat.lastMessage?.id else {
            AppLogger.logTelegram("ℹ️ Chat \(chatId) has no messages")
            return []
        }
        
        // If we've already seen this message, nothing new
        if let lastSeen = lastSeenMsgId, lastMessageId <= lastSeen {
            AppLogger.logTelegram("✅ Chat \(chatId) - no new messages (last: \(lastMessageId) <= seen: \(lastSeen))")
            return []
        }
        
        AppLogger.logTelegram("📥 Chat \(chatId) - has new messages (last: \(lastMessageId) > seen: \(lastSeenMsgId ?? 0))")
        
        // Acquire rate limit token
        let rateLimiter = scheduler.getRateLimiter()
        await rateLimiter.acquire(for: chatId)
        
        // Fetch new messages incrementally
        var allMessages: [Message] = []
        var cursor: Int64 = 0 // Start from newest
        let pageSize = 50
        var batchCount = 0
        let maxBatches = 6 // Max 300 messages (6 × 50)
        
        while batchCount < maxBatches {
            batchCount += 1
            
            AppLogger.logTelegram("📥 Batch #\(batchCount) - fetching from messageId: \(cursor)")
            
            // Acquire rate limit token for each batch
            await rateLimiter.acquire(for: chatId)
            
            let history = try await client.send(
                GetChatHistory(
                    chatId: chatId,
                    fromMessageId: cursor,
                    limit: pageSize,
                    offset: 0,
                    onlyLocal: false
                )
            )
            
            guard let messages = history.messages, !messages.isEmpty else {
                AppLogger.logTelegram("⏹️ No more messages in batch #\(batchCount)")
                break
            }
            
            AppLogger.logTelegram("📨 Batch #\(batchCount) - received \(messages.count) messages")
            
            // Filter: only messages NEWER than lastSeenMsgId
            let newMessages = messages.filter { msg in
                if let lastSeen = lastSeenMsgId {
                    return msg.id > lastSeen
                }
                return true // First fetch - take all
            }
            
            AppLogger.logTelegram("🔍 Batch #\(batchCount) - \(newMessages.count) new messages (filtered from \(messages.count))")
            
            allMessages.append(contentsOf: newMessages)
            
            // Move cursor to oldest message in this batch
            if let oldestMsg = messages.last {
                cursor = oldestMsg.id
                
                // If oldest message in batch is <= lastSeenMsgId, we've reached our boundary
                if let lastSeen = lastSeenMsgId, oldestMsg.id <= lastSeen {
                    AppLogger.logTelegram("⏹️ Reached lastSeenMsgId boundary (oldest: \(oldestMsg.id) <= seen: \(lastSeen))")
                    break
                }
            }
            
            // Small delay between batches
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        AppLogger.logTelegram("✅ Fetched \(allMessages.count) new messages for chat \(chatId) in \(batchCount) batches")
        
        return allMessages
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
