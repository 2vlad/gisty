//
//  Models.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation
import SwiftData

enum GistTone: String, Codable, CaseIterable {
    case `default`
    case breaking
    case positive
    case negative
    case neutral
}

enum SourceType: String, Codable {
    case channel
    case group
    case privateChat
    
    var icon: String {
        switch self {
        case .channel: return "megaphone"
        case .group: return "person.3"
        case .privateChat: return "person"
        }
    }
}

@Model
final class Source {
    @Attribute(.unique) var id: Int64
    var type: SourceType
    var title: String
    var isSelected: Bool
    var unreadCount: Int
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade) var gists: [Gist] = []
    
    init(id: Int64, type: SourceType, title: String, isSelected: Bool = false, unreadCount: Int = 0) {
        self.id = id
        self.type = type
        self.title = title
        self.isSelected = isSelected
        self.unreadCount = unreadCount
        self.updatedAt = Date()
    }
}

@Model
final class Gist: Identifiable {
    @Attribute(.unique) var id: UUID
    var generatedAt: Date
    var summary: String
    var text: String // Full text if needed
    var bullets: [String]
    var locale: String
    var messagesCount: Int
    var links: [String] // URLs extracted from content
    var modelUsed: String? // LLM model used for generation
    var createdAt: Date // When the gist was created
    
    var sourceId: Int64? // Foreign key fallback
    
    @Relationship var source: Source?
    
    init(id: UUID = UUID(), generatedAt: Date = Date(), summary: String, bullets: [String] = [], locale: String = "en", messagesCount: Int = 0, links: [String] = [], modelUsed: String? = nil, source: Source? = nil) {
        self.id = id
        self.generatedAt = generatedAt
        self.summary = summary
        self.text = summary
        self.bullets = bullets
        self.locale = locale
        self.messagesCount = messagesCount
        self.links = links
        self.modelUsed = modelUsed
        self.createdAt = Date()
        self.source = source
        self.sourceId = source?.id
    }
}

@Model
final class ChatFetchState {
    @Attribute(.unique) var chatId: Int64
    var lastFetchedAt: Date?
    var lastSeenMsgId: Int64?
    var isFetching: Bool
    var lastError: String?
    
    init(chatId: Int64) {
        self.chatId = chatId
        self.isFetching = false
    }
    
    func canFetch(minInterval: TimeInterval) -> Bool {
        if isFetching { return false }
        guard let lastFetched = lastFetchedAt else { return true }
        return Date().timeIntervalSince(lastFetched) >= minInterval
    }
    
    func markFetching() {
        self.isFetching = true
        self.lastError = nil
    }
    
    func updateAfterFetch(lastMessageId: Int64?, lastMessageDate: Date?, messageCount: Int) {
        self.isFetching = false
        self.lastFetchedAt = Date()
        if let id = lastMessageId {
            self.lastSeenMsgId = id
        }
    }
    
    func updateAfterError(_ error: Error) {
        self.isFetching = false
        self.lastError = error.localizedDescription
    }
}

// For CacheManager and others
struct MediaRef: Codable {
    let id: String
    let type: String
}

struct CachedMessage: Codable, Identifiable {
    let id: Int64
    let chatId: Int64
    let date: Date
    let text: String
    let senderName: String?
}

struct MessageChunk: Codable {
    let text: String
    let count: Int
}

struct CachedSummary: Codable {
    let id: String
    let text: String
}

struct GistLink: Codable {
    let url: String
    let title: String
}

enum SummaryType: String, Codable {
    case daily
    case weekly
}

enum ChatFilterType: CaseIterable {
    case all
    case channels
    case groups
    case `private`
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .channels: return "Channels"
        case .groups: return "Groups"
        case .private: return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .channels: return "megaphone"
        case .groups: return "person.3"
        case .private: return "person"
        }
    }
}
