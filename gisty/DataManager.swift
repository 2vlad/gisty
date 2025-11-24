//
//  DataManager.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // Published property to satisfy ObservableObject and notify UI of changes
    @Published var lastUpdated: Date = Date()
    
    let modelContainer: ModelContainer
    var mainContext: ModelContext {
        modelContainer.mainContext
    }
    
    // Alias for consistency with other parts of the app
    var modelContext: ModelContext {
        mainContext
    }
    
    private init() {
        do {
            let schema = Schema([
                Gist.self,
                Source.self,
                ChatFetchState.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    func save() throws {
        try mainContext.save()
        self.lastUpdated = Date()
    }
    
    func fetchRecentGists(limit: Int = 50) throws -> [Gist] {
        let descriptor = FetchDescriptor<Gist>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        var gists = try mainContext.fetch(descriptor)
        if gists.count > limit {
            gists = Array(gists.prefix(limit))
        }
        return gists
    }
    
    func fetchSelectedSources() throws -> [Source] {
        let descriptor = FetchDescriptor<Source>(
            predicate: #Predicate<Source> { $0.isSelected == true },
            sortBy: [SortDescriptor(\.title)]
        )
        return try mainContext.fetch(descriptor)
    }
    
    func fetchSource(byId id: Int64) throws -> Source? {
        let descriptor = FetchDescriptor<Source>(
            predicate: #Predicate<Source> { $0.id == id }
        )
        return try mainContext.fetch(descriptor).first
    }
    
    // MARK: - Fetch State Logic
    
    func getOrCreateFetchState(for chatId: Int64) throws -> ChatFetchState {
        let descriptor = FetchDescriptor<ChatFetchState>(
            predicate: #Predicate<ChatFetchState> { $0.chatId == chatId }
        )
        
        if let existing = try mainContext.fetch(descriptor).first {
            return existing
        }
        
        let newState = ChatFetchState(chatId: chatId)
        mainContext.insert(newState)
        // Auto-save for creation is usually good to ensure ID persistence
        try save()
        return newState
    }
}
