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
    @State private var showSettings = false
    @State private var selectedGist: Gist?
    
    // Dependencies
    @State private var messageCollector: MessageCollector?
    @State private var llmService: LLMService?
    @State private var gistGenerator: GistGenerator?
    
    // Smart architecture dependencies
    @State private var fetchScheduler: FetchScheduler?
    @State private var incrementalFetcher: IncrementalFetcher?
    @State private var updateRouter: TelegramUpdateRouter?
    
    var body: some View {
        NavigationStack {
            ZStack {
                GistyTokens.Colors.bgApp.ignoresSafeArea()
                
                if gists.isEmpty && !isRefreshing {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Global Header
                            headerView
                            
                            // Grouped Items by Date
                            ForEach(groupedGists, id: \.date) { section in
                                DaySectionView(date: section.date, gists: section.gists) { gist in
                                    selectedGist = gist
                                }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .refreshable {
                        await refreshGists()
                    }
                }
            }
            .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button(action: { showSettings = true }) {
                         Image(systemName: "gearshape")
                             .foregroundColor(GistyTokens.Colors.textPrimary)
                     }
                 }
            }
            .task { await onAppear() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $selectedGist) { gist in
                GistDetailView(gist: gist, telegram: telegram)
            }
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundColor(GistyTokens.Colors.heatHigh)
            Text("Agenda")
                .font(.custom(GistyTokens.Typography.fontNameBold, size: 32))
                .foregroundColor(GistyTokens.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, GistyTokens.Spacing.l)
        .padding(.top, GistyTokens.Spacing.m)
        .padding(.bottom, GistyTokens.Spacing.xl)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(GistyTokens.Colors.textSecondary)
            
            Text(L.noGistsYet)
                .font(.custom(GistyTokens.Typography.fontName, size: 20))
            
            Button(action: { Task { await refreshGists() } }) {
                Text(L.generateGists)
                    .font(.custom(GistyTokens.Typography.fontName, size: 16))
                    .padding()
                    .background(GistyTokens.Colors.textPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Logic
    
    private var groupedGists: [(date: Date, gists: [Gist])] {
        let grouped = Dictionary(grouping: gists) { gist in
            Calendar.current.startOfDay(for: gist.generatedAt)
        }
        return grouped.map { (date: $0.key, gists: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private func onAppear() async {
        loadGists()
        setupServices()
        if gists.isEmpty, !isRefreshing { await autoGenerateIfNeeded() }
    }
    
    private func loadGists() {
        do {
            let allGists = try dataManager.fetchRecentGists(limit: 50)
            gists = allGists.sorted { $0.generatedAt < $1.generatedAt }
        } catch { print("Error: \(error)") }
    }
    
    private func setupServices() {
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
    
    private func autoGenerateIfNeeded() async { await refreshGists() }
    
    private func refreshGists() async {
        guard !isRefreshing, let generator = gistGenerator else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            _ = try await generator.generateGists(period: .seventyTwoHours, locale: UserSettings.shared.language.code)
            loadGists()
        } catch { print(error) }
    }
}

// MARK: - Day Section

struct DaySectionView: View {
    let date: Date
    let gists: [Gist]
    let onTap: (Gist) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date Header (Sticky-like feel but static for now)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(dayNumber)
                    .font(GistyTokens.Typography.dateBig)
                    .foregroundColor(GistyTokens.Colors.textPrimary)
                
                Text(dayName)
                    .font(GistyTokens.Typography.dateLabel)
                    .foregroundColor(GistyTokens.Colors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, GistyTokens.Spacing.l)
            .padding(.bottom, GistyTokens.Spacing.l)
            
            // List of Items
            VStack(spacing: GistyTokens.Spacing.xxl) { // Big breathing space between items
                ForEach(gists) { gist in
                    AgendaRow(gist: gist)
                        .onTapGesture { onTap(gist) }
                }
            }
            .padding(.bottom, GistyTokens.Spacing.xxl) // Space after section
        }
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var dayName: String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Agenda Row (The Core UI)

struct AgendaRow: View {
    let gist: Gist
    
    // Heat logic based on message count
    private var heatColor: Color {
        let count = gist.messagesCount
        if count < 10 { return GistyTokens.Colors.heatLow }
        if count < 50 { return GistyTokens.Colors.heatMedium }
        return GistyTokens.Colors.heatHigh
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            
            // 1. Left Column: Time & Heat
            VStack(alignment: .leading, spacing: 6) {
                Text(timeString)
                    .font(GistyTokens.Typography.time)
                    .foregroundColor(heatColor) // Time is colored by heat
                
                // Visual bar indicating "volume"
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatColor.opacity(0.3))
                    .frame(width: 4, height: 24)
            }
            .frame(width: 80, alignment: .leading)
            .padding(.leading, GistyTokens.Spacing.l)
            
            // 2. Right Column: Content
            VStack(alignment: .leading, spacing: GistyTokens.Spacing.s) {
                
                // Title Row: Icon + Name
                HStack(spacing: 8) {
                    sourceIcon
                        .frame(width: 18, height: 18)
                        .foregroundColor(GistyTokens.Colors.textPrimary)
                    
                    Text(gist.source?.title ?? "Source")
                        .font(GistyTokens.Typography.sourceTitle)
                        .foregroundColor(GistyTokens.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Message Count Badge
                    Text("\(gist.messagesCount)")
                        .font(GistyTokens.Typography.meta)
                        .foregroundColor(heatColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(heatColor.opacity(0.1))
                        .cornerRadius(6)
                }
                
                // Summary Text
                Text(gist.summary)
                    .font(GistyTokens.Typography.summary)
                    .foregroundColor(GistyTokens.Colors.textSecondary)
                    .lineLimit(3) // Allow a bit more text
                    .lineSpacing(4) // More air between lines
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.trailing, GistyTokens.Spacing.l)
        }
        .contentShape(Rectangle())
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: gist.generatedAt)
    }
    
    // Custom Icon Selection
    @ViewBuilder
    private var sourceIcon: some View {
        if let type = gist.source?.type {
            switch type {
            case .channel:
                IconShapes.Megaphone()
            case .group:
                IconShapes.BubbleDouble()
            case .privateChat:
                IconShapes.Person()
            }
        } else {
            IconShapes.Megaphone() // Default
        }
    }
}

// MARK: - Custom Shapes (Iconography)

struct IconShapes {
    
    // Channel Icon (Broadcast/Megaphone style)
    struct Megaphone: View {
        var body: some View {
            Image(systemName: "megaphone") // System for reliability, refined size
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    // Group Icon (Chat Bubbles)
    struct BubbleDouble: View {
        var body: some View {
            Image(systemName: "bubble.left.and.bubble.right")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    // Private Chat Icon (Person)
    struct Person: View {
        var body: some View {
            Image(systemName: "person")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
