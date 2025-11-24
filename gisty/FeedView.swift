//
//  FeedView.swift
//  gisty
//
//  Created by admin on 08.11.2025.
//

import SwiftUI
import SwiftData
import OSLog

struct FeedView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var telegram: TelegramManager
    
    @State private var gists: [Gist] = []
    @State private var isRefreshing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSettings = false
    @State private var selectedGist: Gist?
    
    // Dependencies for generation
    @State private var messageCollector: MessageCollector?
    @State private var llmService: LLMService?
    @State private var gistGenerator: GistGenerator?
    
    // Smart architecture dependencies (Etap 2)
    @State private var fetchScheduler: FetchScheduler?
    @State private var incrementalFetcher: IncrementalFetcher?
    @State private var updateRouter: TelegramUpdateRouter?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // White background
                Color.white.ignoresSafeArea()
                
                if gists.isEmpty && !isRefreshing {
                    emptyStateView
                } else {
                    // Custom List Layout
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Header "Upcoming"
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Upcoming")
                                    .font(.custom("PPNeueMontreal-Bold", size: 24))
                                    .foregroundColor(.black)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            
                            // Grouped Items
                            ForEach(groupedGists, id: \.date) { section in
                                DaySectionView(date: section.date, gists: section.gists) { gist in
                                    selectedGist = gist
                                }
                            }
                        }
                        .padding(.bottom, 80) // Space for bottom bar
                    }
                }
            }
            .toolbar {
                 // Minimal toolbar or hidden if implementing custom bottom bar
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button(action: { showSettings = true }) {
                         Image(systemName: "gearshape")
                             .foregroundColor(.black)
                     }
                 }
            }
            .task {
                await onAppear()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $selectedGist) { gist in
                GistDetailView(gist: gist, telegram: telegram)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var groupedGists: [(date: Date, gists: [Gist])] {
        let grouped = Dictionary(grouping: gists) { gist in
            Calendar.current.startOfDay(for: gist.generatedAt)
        }
        return grouped.map { (date: $0.key, gists: $0.value) }
            .sorted { $0.date < $1.date } // Sorted ascending (Upcoming)
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text(L.noGistsYet)
                .font(.title2)
                .fontWeight(.semibold)
            
            Button(action: {
                Task {
                    await refreshGists()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(L.generateGists)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(isRefreshing)
        }
    }
    
    // MARK: - Methods
    
    private func onAppear() async {
        loadGists()
        setupServices()
        if gists.isEmpty, !isRefreshing {
            await autoGenerateIfNeeded()
        }
    }
    
    private func loadGists() {
        do {
            let allGists = try dataManager.fetchRecentGists(limit: 50)
            // Filter and sort logic...
            // For now, just simple sorting for the demo
            gists = allGists.sorted { $0.generatedAt < $1.generatedAt }
        } catch {
            print("Error loading gists: \(error)")
        }
    }
    
    private func setupServices() {
        // ... (Keep existing service setup code) ...
        // Re-implementing briefly for context or assume it's there.
        // For the sake of the edit, I'll reuse the existing logic structure from previous file content.
        guard let apiKey = ConfigurationManager.shared.openRouterApiKey, !apiKey.isEmpty else { return }
        
        let scheduler = FetchScheduler(dataManager: dataManager)
        fetchScheduler = scheduler
        let fetcher = IncrementalFetcher(telegram: telegram, scheduler: scheduler)
        incrementalFetcher = fetcher
        let router = TelegramUpdateRouter(dataManager: dataManager, scheduler: scheduler, incrementalFetcher: fetcher)
        updateRouter = router
        telegram.updateRouter = router
        
        let collector = MessageCollector(telegram: telegram, dataManager: dataManager, scheduler: scheduler, incrementalFetcher: fetcher)
        messageCollector = collector
        
        let llm = LLMService(config: LLMService.Config(provider: .openrouter, model: "anthropic/claude-haiku-4.5", apiKey: apiKey, maxTokens: 1000, temperature: 0.3))
        llmService = llm
        gistGenerator = GistGenerator(messageCollector: collector, llmService: llm, dataManager: dataManager)
    }
    
    private func autoGenerateIfNeeded() async {
        await refreshGists()
    }
    
    private func refreshGists() async {
        guard !isRefreshing else { return }
        guard let generator = gistGenerator else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let locale = UserSettings.shared.language.code
            _ = try await generator.generateGists(period: .seventyTwoHours, locale: locale)
            loadGists()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Day Section View

struct DaySectionView: View {
    let date: Date
    let gists: [Gist]
    let onTap: (Gist) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date Header
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayNumber)
                    .font(.custom("EBGaramond-Regular", size: 42)) // Large serif number
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                
                Text(dayName)
                    .font(.custom("EBGaramond-Regular", size: 24)) // Serif day name
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.leading, 24)
                .opacity(0.5)
            
            // Items
            VStack(spacing: 0) {
                ForEach(gists) { gist in
                    AgendaRow(gist: gist)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(gist)
                        }
                }
            }
            .padding(.top, 16)
        }
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var dayName: String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Agenda Row

struct AgendaRow: View {
    let gist: Gist
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            Text(timeString)
                .font(.custom("PPNeueMontreal-Medium", size: 16))
                .foregroundColor(GistyTokens.Colors.textGold) // Gold color
                .frame(width: 80, alignment: .leading)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(gist.source?.title ?? "Event")
                        .font(.custom("PPNeueMontreal-Medium", size: 16))
                        .foregroundColor(.black)
                    
                    // Optional: Icons based on content
                    if isUrgent {
                         Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text(gist.summary.prefix(50) + "...")
                     .font(.custom("PPNeueMontreal-Book", size: 14))
                     .foregroundColor(.gray)
                     .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: gist.generatedAt)
    }
    
    private var isUrgent: Bool {
        // Simple check for demo
        return gist.summary.lowercased().contains("urgent")
    }
}
