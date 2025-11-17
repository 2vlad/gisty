//
//  TelegramUpdateRouter.swift
//  gisty
//
//  Created by admin on 17.11.2025.
//
//  Event-driven router for TDLib updates
//  Routes updateChatLastMessage to incremental fetcher
//

import Foundation
import Combine
import TDLibKit

/// Routes TDLib updates to appropriate handlers
/// Filters noise (updateChatPosition, updateUser, etc.)
@MainActor
class TelegramUpdateRouter: ObservableObject {
    // MARK: - Properties
    
    private let dataManager: DataManager
    private weak var scheduler: FetchScheduler?
    private weak var incrementalFetcher: IncrementalFetcher?
    
    // Track last update times to avoid duplicate processing
    private var lastUpdateTimes: [Int64: Foundation.Date] = [:]
    
    @Published var isProcessing = false
    
    // MARK: - Initialization
    
    init(
        dataManager: DataManager,
        scheduler: FetchScheduler,
        incrementalFetcher: IncrementalFetcher
    ) {
        self.dataManager = dataManager
        self.scheduler = scheduler
        self.incrementalFetcher = incrementalFetcher
        
        AppLogger.logTelegram("🎯 TelegramUpdateRouter initialized")
    }
    
    // MARK: - Public Methods
    
    /// Route update to appropriate handler
    func routeUpdate(_ update: Update) async {
        switch update {
        case .updateChatLastMessage(let chatUpdate):
            // 🎯 KEY EVENT: New message in chat
            await handleChatLastMessage(chatUpdate)
            
        case .updateNewMessage(let msgUpdate):
            // Optional: can also trigger on individual messages
            AppLogger.debug("📬 updateNewMessage: \(msgUpdate.message.id) in chat \(msgUpdate.message.chatId)", category: AppLogger.telegram)
            // Note: we primarily rely on updateChatLastMessage for batching
            
        case .updateChatPosition,
             .updateChatAddedToList,
             .updateUser,
             .updateNewChat:
            // 🗑️ NOISE: Ignore metadata updates, don't trigger fetches
            break
            
        case .updateAuthorizationState,
             .updateConnectionState:
            // Handled by TelegramManager directly
            break
            
        default:
            // Unknown/unhandled update - log in debug only
            #if DEBUG
            AppLogger.debug("❓ Unhandled update: \(type(of: update))", category: AppLogger.telegram)
            #endif
            break
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle updateChatLastMessage - the key trigger for incremental fetch
    private func handleChatLastMessage(_ update: UpdateChatLastMessage) async {
        let chatId = update.chatId
        
        // Get last message info
        guard let lastMessage = update.lastMessage else {
            AppLogger.debug("ℹ️ Chat \(chatId): lastMessage is nil", category: AppLogger.telegram)
            return
        }
        
        let tipMessageId = lastMessage.id
        let tipDate = Date(timeIntervalSince1970: TimeInterval(lastMessage.date))
        
        AppLogger.logTelegram("📬 updateChatLastMessage: chat=\(chatId), msgId=\(tipMessageId), date=\(tipDate.formatted())")
        
        // FILTER 1: Is this chat selected for summaries?
        do {
            guard let source = try dataManager.fetchSource(byId: chatId),
                  source.isSelected else {
                AppLogger.debug("⏭️ Chat \(chatId) not selected, skipping", category: AppLogger.telegram)
                return
            }
            
            // FILTER 2: Get fetch state and check 5-minute interval
            guard let scheduler = scheduler else {
                AppLogger.warning("⚠️ Scheduler not available", category: AppLogger.telegram)
                return
            }
            
            let fetchState = try dataManager.getOrCreateFetchState(for: chatId)
            
            // Check 5-minute interval
            guard fetchState.canFetch(minInterval: scheduler.minInterval) else {
                AppLogger.logTelegram("⏰ Chat \(chatId) too soon (last fetch: \(fetchState.lastFetchedAt?.formatted() ?? "never"))")
                return
            }
            
            // FILTER 3: Quick pre-check - is there actually new content?
            if let lastSeenMsgId = fetchState.lastSeenMsgId,
               tipMessageId <= lastSeenMsgId {
                AppLogger.logTelegram("✅ Chat \(chatId) - no new messages (tip: \(tipMessageId) <= seen: \(lastSeenMsgId))")
                return
            }
            
            // 🚀 ALL CHECKS PASSED - Schedule incremental fetch!
            AppLogger.logTelegram("🎯 Chat \(chatId) - has new messages! (tip: \(tipMessageId) > seen: \(fetchState.lastSeenMsgId ?? 0))")
            
            // Debounce: don't process same chat more than once per minute
            if let lastUpdate = lastUpdateTimes[chatId],
               Date().timeIntervalSince(lastUpdate) < 60 {
                AppLogger.debug("⏸️ Chat \(chatId) debounced (updated \(Int(Date().timeIntervalSince(lastUpdate)))s ago)", category: AppLogger.telegram)
                return
            }
            
            lastUpdateTimes[chatId] = Date()
            
            // Trigger incremental fetch in background
            Task.detached { [weak self, chatId, lastSeenMsgId = fetchState.lastSeenMsgId] in
                await self?.triggerIncrementalFetch(
                    chatId: chatId,
                    lastSeenMsgId: lastSeenMsgId
                )
            }
            
        } catch {
            AppLogger.error("❌ Error handling chat last message", category: AppLogger.telegram, error: error)
        }
    }
    
    /// Trigger incremental fetch for a specific chat
    private func triggerIncrementalFetch(chatId: Int64, lastSeenMsgId: Int64?) async {
        guard let fetcher = incrementalFetcher,
              let scheduler = scheduler else {
            return
        }
        
        do {
            // Mark as fetching
            try await scheduler.markFetching(chatId: chatId)
            
            // Fetch only new messages
            let newMessages = try await fetcher.fetchNewMessages(
                for: chatId,
                lastSeenMsgId: lastSeenMsgId
            )
            
            AppLogger.logTelegram("✅ Event-driven fetch: \(newMessages.count) new messages from chat \(chatId)")
            
            // Mark complete
            try await scheduler.markComplete(
                chatId: chatId,
                lastMessageId: newMessages.last?.id,
                lastMessageDate: newMessages.last.map { Date(timeIntervalSince1970: TimeInterval($0.date)) },
                messageCount: newMessages.count
            )
            
        } catch {
            AppLogger.error("❌ Event-driven fetch failed for chat \(chatId)", category: AppLogger.telegram, error: error)
            try? await scheduler.markFailed(chatId: chatId, error: error)
        }
    }
}
