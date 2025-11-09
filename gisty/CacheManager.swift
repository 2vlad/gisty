//
//  CacheManager.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation
import SwiftData
import CryptoKit
import Combine

/// Three-tier cache manager: L1 (in-memory NSCache) + L2 (SwiftData) + TDLib cache
/// Handles message caching, chunking, and summary caching
@MainActor
class CacheManager: ObservableObject {
    
    // MARK: - Configuration
    
    struct Config {
        /// Chunk interval in seconds (default: 15 minutes)
        var chunkInterval: TimeInterval = 15 * 60
        
        /// Grace period before closing chunk (default: 30 minutes)
        var chunkClosureGracePeriod: TimeInterval = 30 * 60
        
        /// L1 cache size (number of objects)
        var l1CacheSize: Int = 1000
        
        /// Model version for summaries
        var modelVer: String = "gpt-4o-mini"
        
        /// Prompt version for summaries
        var promptVer: String = "v1"
    }
    
    private let config: Config
    private let modelContext: ModelContext
    
    // MARK: - L1 In-Memory Cache
    
    private let messageCache = NSCache<NSString, CachedMessageWrapper>()
    private let chunkCache = NSCache<NSString, MessageChunkWrapper>()
    private let summaryCache = NSCache<NSString, CachedSummaryWrapper>()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, config: Config = Config()) {
        self.modelContext = modelContext
        self.config = config
        
        // Configure L1 caches
        messageCache.countLimit = config.l1CacheSize
        chunkCache.countLimit = 200
        summaryCache.countLimit = 500
        
        print("✅ CacheManager initialized (L1 size: \(config.l1CacheSize))")
    }
    
    // MARK: - Message Cache Operations
    
    /// Get or create cached message
    func getOrCacheMessage(
        chatId: Int64,
        messageId: Int64,
        dateTs: Date,
        text: String,
        mediaRefs: [MediaRef] = []
    ) throws -> CachedMessage {
        let key = "\(chatId):\(messageId)" as NSString
        
        // L1 hit?
        if let wrapper = messageCache.object(forKey: key) {
            return wrapper.message
        }
        
        // L2 hit?
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.chatId == chatId && $0.messageId == messageId }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            // Cache in L1
            messageCache.setObject(CachedMessageWrapper(existing), forKey: key)
            return existing
        }
        
        // Create new
        let message = CachedMessage(
            chatId: chatId,
            messageId: messageId,
            dateTs: dateTs,
            text: text,
            mediaRefs: mediaRefs
        )
        
        modelContext.insert(message)
        try modelContext.save()
        
        // Cache in L1
        messageCache.setObject(CachedMessageWrapper(message), forKey: key)
        
        return message
    }
    
    /// Update message content (on edit)
    func updateMessage(
        chatId: Int64,
        messageId: Int64,
        text: String,
        mediaRefs: [MediaRef],
        editTs: Date
    ) throws -> CachedMessage {
        let message = try getOrCacheMessage(
            chatId: chatId,
            messageId: messageId,
            dateTs: editTs,
            text: text,
            mediaRefs: mediaRefs
        )
        
        message.updateContent(text: text, mediaRefs: mediaRefs, editTs: editTs)
        try modelContext.save()
        
        // Invalidate affected summaries
        try invalidateSummariesForMessage(chatId: chatId, messageId: messageId)
        
        return message
    }
    
    /// Mark message as deleted
    func deleteMessage(chatId: Int64, messageId: Int64) throws {
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.chatId == chatId && $0.messageId == messageId }
        )
        
        if let message = try modelContext.fetch(descriptor).first {
            message.markDeleted()
            try modelContext.save()
            
            // Invalidate affected summaries
            try invalidateSummariesForMessage(chatId: chatId, messageId: messageId)
        }
    }
    
    // MARK: - Chunk Operations
    
    /// Get or create chunk for a message timestamp
    func getOrCreateChunk(chatId: Int64, timestamp: Date) throws -> MessageChunk {
        let chunkKey = MessageChunk.generateChunkKey(for: timestamp, interval: config.chunkInterval)
        let key = "\(chatId):\(chunkKey)" as NSString
        
        // L1 hit?
        if let wrapper = chunkCache.object(forKey: key) {
            return wrapper.chunk
        }
        
        // L2 hit?
        let descriptor = FetchDescriptor<MessageChunk>(
            predicate: #Predicate { $0.chatId == chatId && $0.chunkKey == chunkKey }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            chunkCache.setObject(MessageChunkWrapper(existing), forKey: key)
            return existing
        }
        
        // Create new
        guard let (fromTs, toTs) = MessageChunk.parseChunkKey(chunkKey) else {
            throw CacheError.invalidChunkKey(chunkKey)
        }
        
        let chunk = MessageChunk(
            chatId: chatId,
            chunkKey: chunkKey,
            fromTs: fromTs,
            toTs: toTs
        )
        
        modelContext.insert(chunk)
        try modelContext.save()
        
        chunkCache.setObject(MessageChunkWrapper(chunk), forKey: key)
        
        return chunk
    }
    
    /// Add message to appropriate chunk
    func addMessageToChunk(_ message: CachedMessage) throws {
        let chunk = try getOrCreateChunk(chatId: message.chatId, timestamp: message.dateTs)
        chunk.addMessage(message)
        message.chunk = chunk
        
        try modelContext.save()
    }
    
    /// Recalculate chunk hash and check if should close
    func updateChunk(_ chunk: MessageChunk) throws {
        let chatId = chunk.chatId
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { msg in
                msg.chatId == chatId &&
                !msg.deleted
            }
        )
        
        let allMessages = try modelContext.fetch(descriptor)
        // Filter messages that belong to this chunk
        let chunkMessageIds = chunk.messageIds
        let messages = allMessages.filter { chunkMessageIds.contains($0.messageId) }
        chunk.recalculateHash(messages: messages)
        
        // Auto-close if grace period passed
        if !chunk.closed && chunk.shouldBeClosed(now: Date()) {
            chunk.close()
            print("📦 Closed chunk: \(chunk.chunkKey) (hash: \(chunk.chunkHash.prefix(8))...)")
        }
        
        try modelContext.save()
    }
    
    /// Get chunks for a time range
    func getChunks(chatId: Int64, from: Date, to: Date) throws -> [MessageChunk] {
        let descriptor = FetchDescriptor<MessageChunk>(
            predicate: #Predicate { chunk in
                chunk.chatId == chatId &&
                chunk.fromTs >= from &&
                chunk.toTs <= to
            },
            sortBy: [SortDescriptor(\.fromTs)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Summary Cache Operations
    
    /// Get cached summary or nil if not found/invalid
    func getCachedSummary(
        chatId: Int64,
        chunkKey: String,
        modelVer: String,
        promptVer: String,
        lang: String
    ) throws -> CachedSummary? {
        let summaryKey = CachedSummary.generateKey(
            chatId: chatId,
            chunkKey: chunkKey,
            modelVer: modelVer,
            promptVer: promptVer,
            lang: lang
        )
        
        let key = summaryKey as NSString
        
        // L1 hit?
        if let wrapper = summaryCache.object(forKey: key) {
            return wrapper.summary
        }
        
        // L2 hit?
        let descriptor = FetchDescriptor<CachedSummary>(
            predicate: #Predicate { $0.summaryKey == summaryKey }
        )
        
        guard let summary = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        // Validate against current chunk hash
        let chunkDescriptor = FetchDescriptor<MessageChunk>(
            predicate: #Predicate { $0.chatId == chatId && $0.chunkKey == chunkKey }
        )
        
        guard let chunk = try modelContext.fetch(chunkDescriptor).first else {
            return nil
        }
        
        // Invalid if chunk hash changed
        if !summary.isValid(currentChunkHash: chunk.chunkHash) {
            print("⚠️ Summary cache invalid (chunk changed): \(summaryKey)")
            modelContext.delete(summary)
            try modelContext.save()
            return nil
        }
        
        // Valid - cache in L1
        summaryCache.setObject(CachedSummaryWrapper(summary), forKey: key)
        return summary
    }
    
    /// Save summary to cache
    func saveSummary(
        chatId: Int64,
        chunkKey: String,
        chunkHash: String,
        modelVer: String,
        promptVer: String,
        lang: String,
        text: String,
        bullets: [String],
        links: [GistLink],
        tokensIn: Int,
        tokensOut: Int,
        summaryType: SummaryType,
        messageDependencies: [(messageId: Int64, version: Int)]
    ) throws -> CachedSummary {
        let summaryKey = CachedSummary.generateKey(
            chatId: chatId,
            chunkKey: chunkKey,
            modelVer: modelVer,
            promptVer: promptVer,
            lang: lang
        )
        
        let summary = CachedSummary(
            summaryKey: summaryKey,
            chatId: chatId,
            chunkKey: chunkKey,
            chunkHash: chunkHash,
            modelVer: modelVer,
            promptVer: promptVer,
            lang: lang,
            text: text,
            bullets: bullets,
            links: links,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            summaryType: summaryType
        )
        
        modelContext.insert(summary)
        
        // Add dependencies
        for dep in messageDependencies {
            let dependency = SummaryDependency(
                summaryKey: summaryKey,
                chatId: chatId,
                messageId: dep.messageId,
                messageVer: dep.version
            )
            modelContext.insert(dependency)
        }
        
        try modelContext.save()
        
        // Cache in L1
        summaryCache.setObject(CachedSummaryWrapper(summary), forKey: summaryKey as NSString)
        
        print("💾 Saved summary: \(summaryKey) (\(tokensIn) tok in, \(tokensOut) tok out)")
        
        return summary
    }
    
    // MARK: - Invalidation
    
    /// Invalidate summaries affected by message edit/delete
    private func invalidateSummariesForMessage(chatId: Int64, messageId: Int64) throws {
        let descriptor = FetchDescriptor<SummaryDependency>(
            predicate: #Predicate { $0.chatId == chatId && $0.messageId == messageId }
        )
        
        let deps = try modelContext.fetch(descriptor)
        
        // Collect summary keys to invalidate
        let summaryKeys = deps.map { $0.summaryKey }
        
        // Fetch and delete all affected summaries
        let summaryDescriptor = FetchDescriptor<CachedSummary>()
        let allSummaries = try modelContext.fetch(summaryDescriptor)
        
        for summary in allSummaries {
            if summaryKeys.contains(summary.summaryKey) {
                print("🗑️ Invalidating summary: \(summary.summaryKey)")
                modelContext.delete(summary)
                
                // Remove from L1 cache
                summaryCache.removeObject(forKey: summary.summaryKey as NSString)
            }
        }
        
        // Delete dependencies
        for dep in deps {
            modelContext.delete(dep)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Statistics
    
    func getStats(for chatId: Int64) throws -> CacheStats {
        let msgCount = try modelContext.fetchCount(
            FetchDescriptor<CachedMessage>(
                predicate: #Predicate { $0.chatId == chatId && !$0.deleted }
            )
        )
        
        let chunkCount = try modelContext.fetchCount(
            FetchDescriptor<MessageChunk>(
                predicate: #Predicate { $0.chatId == chatId }
            )
        )
        
        let summaryCount = try modelContext.fetchCount(
            FetchDescriptor<CachedSummary>(
                predicate: #Predicate { $0.chatId == chatId }
            )
        )
        
        return CacheStats(
            messagesCount: msgCount,
            chunksCount: chunkCount,
            summariesCount: summaryCount
        )
    }
}

// MARK: - Wrapper Classes (for NSCache)

private class CachedMessageWrapper {
    let message: CachedMessage
    nonisolated init(_ message: CachedMessage) { self.message = message }
}

private class MessageChunkWrapper {
    let chunk: MessageChunk
    nonisolated init(_ chunk: MessageChunk) { self.chunk = chunk }
}

private class CachedSummaryWrapper {
    let summary: CachedSummary
    nonisolated init(_ summary: CachedSummary) { self.summary = summary }
}

// MARK: - Supporting Types

struct CacheStats {
    let messagesCount: Int
    let chunksCount: Int
    let summariesCount: Int
    
    var description: String {
        """
        Messages: \(messagesCount)
        Chunks: \(chunksCount)
        Summaries: \(summariesCount)
        """
    }
}

enum CacheError: LocalizedError {
    case invalidChunkKey(String)
    case messageNotFound(Int64, Int64)
    
    var errorDescription: String? {
        switch self {
        case .invalidChunkKey(let key):
            return "Invalid chunk key: \(key)"
        case .messageNotFound(let chatId, let msgId):
            return "Message not found: \(chatId):\(msgId)"
        }
    }
}
