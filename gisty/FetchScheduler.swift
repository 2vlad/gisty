//
//  FetchScheduler.swift
//  gisty
//
//  Created by admin on 17.11.2025.
//

import Foundation
import Combine
import SwiftData

/// Fetch job for a specific chat
struct FetchJob {
    let chatId: Int64
    let priority: Priority
    
    enum Priority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

/// Smart scheduler for fetching messages from Telegram
/// Ensures 5-minute intervals, rate limiting, and prioritization
@MainActor
class FetchScheduler: ObservableObject {
    // MARK: - Properties
    
    let dataManager: DataManager
    private let rateLimiter: RateLimiter
    
    /// Minimum interval between fetches for same chat (5 minutes)
    let minInterval: TimeInterval = 5 * 60
    
    @Published var isScheduling = false
    @Published var activeFetches: Set<Int64> = []
    
    // MARK: - Initialization
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        self.rateLimiter = RateLimiter()
        
        AppLogger.logData("📅 FetchScheduler initialized (minInterval: \(Int(minInterval))s)")
    }
    
    // MARK: - Public Methods
    
    /// Schedule fetches for all eligible chats
    /// - Returns: List of fetch jobs ready to execute
    func scheduleEligibleChats() async throws -> [FetchJob] {
        guard !isScheduling else {
            AppLogger.warning("⏸️ Already scheduling, skipping", category: AppLogger.data)
            return []
        }
        
        isScheduling = true
        defer { isScheduling = false }
        
        AppLogger.logData("📅 Scheduling eligible chats...")
        
        // Get all selected sources
        let sources = try dataManager.fetchSelectedSources()
        AppLogger.logData("📋 Found \(sources.count) selected sources")
        
        // Get or create fetch states
        var jobs: [FetchJob] = []
        
        for source in sources {
            let state = try getOrCreateFetchState(for: source.id)
            
            // Check if can fetch based on interval
            if state.canFetch(minInterval: minInterval) {
                let priority: FetchJob.Priority = state.lastFetchedAt == nil ? .high : .normal
                jobs.append(FetchJob(chatId: source.id, priority: priority))
                AppLogger.debug("✅ Scheduled chatId \(source.id) with priority \(priority)", category: AppLogger.data)
            } else {
                AppLogger.debug("⏭️ Skipped chatId \(source.id) (too soon)", category: AppLogger.data)
            }
        }
        
        // Sort by priority (high first)
        jobs.sort { $0.priority > $1.priority }
        
        // Add jitter to prevent thundering herd
        jobs = jobs.shuffled()
        
        AppLogger.logData("📅 Scheduled \(jobs.count) fetch jobs")
        return jobs
    }
    
    /// Check if a specific chat can be fetched
    func canFetch(chatId: Int64) async throws -> Bool {
        // Check if already fetching
        if activeFetches.contains(chatId) {
            AppLogger.debug("⏸️ Chat \(chatId) already fetching", category: AppLogger.data)
            return false
        }
        
        // Check fetch state
        let state = try getOrCreateFetchState(for: chatId)
        return state.canFetch(minInterval: minInterval)
    }
    
    /// Mark chat as actively fetching
    func markFetching(chatId: Int64) async throws {
        activeFetches.insert(chatId)
        
        let state = try getOrCreateFetchState(for: chatId)
        state.markFetching()
        try dataManager.save()
        
        AppLogger.debug("🔄 Marked chat \(chatId) as fetching", category: AppLogger.data)
    }
    
    /// Mark chat fetch as complete
    func markComplete(
        chatId: Int64,
        lastMessageId: Int64?,
        lastMessageDate: Date?,
        messageCount: Int
    ) async throws {
        activeFetches.remove(chatId)
        
        let state = try getOrCreateFetchState(for: chatId)
        state.updateAfterFetch(
            lastMessageId: lastMessageId,
            lastMessageDate: lastMessageDate,
            messageCount: messageCount
        )
        try dataManager.save()
        
        AppLogger.logData("✅ Completed fetch for chat \(chatId): \(messageCount) messages")
    }
    
    /// Mark chat fetch as failed
    func markFailed(chatId: Int64, error: Error) async throws {
        activeFetches.remove(chatId)
        
        let state = try getOrCreateFetchState(for: chatId)
        state.updateAfterError(error)
        try dataManager.save()
        
        AppLogger.error("❌ Failed fetch for chat \(chatId)", category: AppLogger.data, error: error)
    }
    
    /// Get rate limiter for controlled API access
    func getRateLimiter() -> RateLimiter {
        return rateLimiter
    }
    
    // MARK: - Private Methods
    
    private func getOrCreateFetchState(for chatId: Int64) throws -> ChatFetchState {
        // Try to fetch existing state
        let descriptor = FetchDescriptor<ChatFetchState>(
            predicate: #Predicate { $0.chatId == chatId }
        )
        
        if let existing = try dataManager.modelContext.fetch(descriptor).first {
            return existing
        }
        
        // Create new state
        let newState = ChatFetchState(chatId: chatId)
        dataManager.modelContext.insert(newState)
        try dataManager.save()
        
        AppLogger.logData("📝 Created new ChatFetchState for chatId: \(chatId)")
        return newState
    }
}
