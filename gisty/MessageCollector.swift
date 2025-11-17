//
//  MessageCollector_v2.swift
//  gisty
//
//  Created by admin on 17.11.2025.
//  
//  Smart MessageCollector with incremental fetching
//  Replace MessageCollector.swift with this file after testing
//

import Foundation
import TDLibKit
import Combine

/// Handles incremental message collection from Telegram sources
/// Version 2: Uses IncrementalFetcher for smart updates
@MainActor
class MessageCollector: ObservableObject {
    // MARK: - Properties
    
    private let telegram: TelegramManager
    private let dataManager: DataManager
    private let scheduler: FetchScheduler
    private let incrementalFetcher: IncrementalFetcher
    
    @Published var isCollecting = false
    @Published var progress: CollectionProgress?
    
    // MARK: - Initialization
    
    init(
        telegram: TelegramManager,
        dataManager: DataManager,
        scheduler: FetchScheduler,
        incrementalFetcher: IncrementalFetcher
    ) {
        self.telegram = telegram
        self.dataManager = dataManager
        self.scheduler = scheduler
        self.incrementalFetcher = incrementalFetcher
        
        AppLogger.logData("📦 MessageCollector v2 initialized (smart incremental)")
    }
    
    // MARK: - Public Methods
    
    /// Collect messages from all selected sources
    /// Uses smart incremental fetching - only new messages!
    func collectFromAllSources(period: TimePeriod) async throws -> [SourceMessages] {
        AppLogger.logData("🎯 collectFromAllSources() - period: \(period.rawValue) (smart mode)")
        isCollecting = true
        defer { isCollecting = false }
        
        // 🚀 OPTIMIZATION: Fetch only new messages incrementally
        let newMessagesDict = try await incrementalFetcher.fetchAllEligibleChats()
        
        AppLogger.logData("✅ Fetched from \(newMessagesDict.count) chats with new messages")
        
        // Get all selected sources
        let sources = try dataManager.fetchSelectedSources()
        
        // Build SourceMessages for each source
        var allMessages: [SourceMessages] = []
        progress = CollectionProgress(total: sources.count, current: 0)
        
        for (index, source) in sources.enumerated() {
            progress?.current = index + 1
            progress?.currentSource = source.title
            
            // Get new messages for this source
            guard let messages = newMessagesDict[source.id], !messages.isEmpty else {
                AppLogger.logData("ℹ️ No new messages for \(source.title)")
                continue
            }
            
            AppLogger.logData("📥 Processing \(messages.count) new messages from \(source.title)")
            
            // Normalize messages
            let normalized = normalizeMessages(messages)
            
            // Filter by period (for UI - last 72 hours)
            let endDate = Date()
            let startDate = period.startDate(from: endDate)
            let filtered = normalized.filter { msg in
                msg.date >= startDate && msg.date <= endDate
            }
            
            AppLogger.logData("🔍 Filtered: \(filtered.count)/\(normalized.count) messages in period")
            
            if !filtered.isEmpty {
                let sourceMessages = SourceMessages(
                    source: source,
                    messages: filtered,
                    period: period,
                    collectedAt: Date()
                )
                allMessages.append(sourceMessages)
            }
        }
        
        progress = nil
        AppLogger.logData("🎉 Collection complete: \(allMessages.count) sources with messages")
        return allMessages
    }
    
    /// Collect messages from a specific source (legacy method)
    /// Kept for compatibility, but uses smart fetching internally
    func collectMessages(from source: Source, period: TimePeriod) async throws -> SourceMessages {
        AppLogger.logData("🔨 collectMessages() for source: \(source.title) (ID: \(source.id))")
        
        // Get or create fetch state
        let fetchState = try dataManager.getOrCreateFetchState(for: source.id)
        
        // Check if can fetch
        guard fetchState.canFetch(minInterval: scheduler.minInterval) else {
            AppLogger.logData("⏰ Too soon to fetch \(source.title), using cached data")
            // Return empty for now - in production, load from local DB
            return SourceMessages(
                source: source,
                messages: [],
                period: period,
                collectedAt: Date()
            )
        }
        
        // Fetch new messages
        let messages = try await incrementalFetcher.fetchNewMessages(
            for: source.id,
            lastSeenMsgId: fetchState.lastSeenMsgId
        )
        
        AppLogger.logData("📨 Fetched \(messages.count) new messages from \(source.title)")
        
        // Normalize and filter
        let normalized = normalizeMessages(messages)
        let endDate = Date()
        let startDate = period.startDate(from: endDate)
        let filtered = normalized.filter { $0.date >= startDate && $0.date <= endDate }
        
        // Update fetch state
        try await scheduler.markComplete(
            chatId: source.id,
            lastMessageId: messages.last?.id,
            lastMessageDate: messages.last.map { Date(timeIntervalSince1970: TimeInterval($0.date)) },
            messageCount: messages.count
        )
        
        return SourceMessages(
            source: source,
            messages: filtered,
            period: period,
            collectedAt: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func normalizeMessages(_ messages: [Message]) -> [NormalizedMessage] {
        let normalized: [NormalizedMessage] = messages.compactMap { message -> NormalizedMessage? in
            guard let content = extractTextContent(from: message.content) else {
                return nil
            }
            
            return NormalizedMessage(
                id: message.id,
                chatId: message.chatId,
                date: Foundation.Date(timeIntervalSince1970: TimeInterval(message.date)),
                content: content,
                senderId: message.senderId
            )
        }
        
        // 🔒 PRIVACY: Log only metadata, not actual message content
        if !normalized.isEmpty {
            let avgLength = normalized.map(\.content.count).reduce(0, +) / normalized.count
            AppLogger.logData("🔄 Normalized \(normalized.count) messages (avg length: \(avgLength) chars)")
        }
        
        return normalized
    }
    
    private func extractTextContent(from content: MessageContent) -> String? {
        switch content {
        case .messageText(let textMsg):
            return textMsg.text.text
            
        case .messagePhoto(let photo):
            return photo.caption.text.isEmpty ? nil : photo.caption.text
            
        case .messageVideo(let video):
            return video.caption.text.isEmpty ? nil : video.caption.text
            
        case .messageDocument(let doc):
            return doc.caption.text.isEmpty ? nil : doc.caption.text
            
        default:
            return nil // Filter out service messages
        }
    }
}

// MARK: - Data Models

struct SourceMessages {
    let source: Source
    let messages: [NormalizedMessage]
    let period: TimePeriod
    let collectedAt: Foundation.Date
}

struct NormalizedMessage: Identifiable {
    let id: Int64
    let chatId: Int64
    let date: Foundation.Date
    let content: String
    let senderId: MessageSender
}

struct CollectionProgress {
    let total: Int
    var current: Int
    var currentSource: String?
}

enum TimePeriod: Int, CaseIterable {
    case sixHours = 6
    case twelveHours = 12
    case twentyFourHours = 24
    case seventyTwoHours = 72
    
    var displayName: String {
        switch self {
        case .sixHours: return "6 hours"
        case .twelveHours: return "12 hours"
        case .twentyFourHours: return "24 hours"
        case .seventyTwoHours: return "72 hours"
        }
    }
    
    func startDate(from endDate: Foundation.Date) -> Foundation.Date {
        Calendar.current.date(byAdding: .hour, value: -rawValue, to: endDate) ?? endDate
    }
}

enum MessageCollectorError: LocalizedError {
    case clientNotAvailable
    case noMessagesFound
    
    var errorDescription: String? {
        switch self {
        case .clientNotAvailable:
            return "Telegram client not available"
        case .noMessagesFound:
            return "No messages found in the specified period"
        }
    }
}
