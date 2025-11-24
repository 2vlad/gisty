//
//  DataManager.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    let modelContainer: ModelContainer
    var mainContext: ModelContext {
        modelContainer.mainContext
    }
    
    private init() {
        do {
            let schema = Schema([
                Gist.self,
                Source.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
}

