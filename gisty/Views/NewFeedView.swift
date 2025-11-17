//
//  NewFeedView.swift
//  gisty
//
//  Feed view with Gisty design system
//  Created by Claude Code on 09.11.2025.
//

import SwiftUI
import SwiftData

struct NewFeedView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var telegram: TelegramManager
    
    @State private var feedSections: [FeedSection] = []
    @State private var isRefreshing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showMenu = false
    
    // Dependencies for generation
    @State private var messageCollector: MessageCollector?
    @State private var llmService: LLMService?
    @State private var gistGenerator: GistGenerator?
    
    var body: some View {
        ZStack {
            // Dark app background
            GistyTokens.Colors.bgApp
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // App bar
                GistyAppBar(onMenuTap: {
                    showMenu = true
                })
                
                // Feed content
                if feedSections.isEmpty && !isRefreshing {
                    emptyStateView
                } else if isRefreshing && feedSections.isEmpty {
                    loadingView
                } else {
                    feedListView
                }
            }
        }
        .task {
            await onAppear()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showMenu) {
            MenuView(isPresented: $showMenu)
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        EmptyStateView(
            title: "No Gists Yet",
            message: "Tap the refresh button to generate your first digest from Telegram",
            icon: "doc.text.magnifyingglass"
        )
    }
    
    private var loadingView: some View {
        ScrollView {
            VStack(spacing: GistyTokens.Spacing.xl) {
                ForEach(0..<3, id: \.self) { _ in
                    FeedCardSkeleton()
                        .padding(.horizontal, GistyTokens.Spacing.xxl)
                }
            }
            .padding(.vertical, GistyTokens.Spacing.l)
        }
    }
    
    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: GistyTokens.Spacing.xl) {
                ForEach(Array(feedSections.enumerated()), id: \.offset) { index, section in
                    FeedCard(
                        publisher: section.publisher,
                        avatar: section.avatar,
                        unreadCount: section.unreadCount,
                        gists: section.gists.map { gist in
                            (
                                text: gist.text,
                                tone: gist.tone,
                                isRead: gist.isRead
                            )
                        },
                        onGistTap: { gistIndex in
                            handleGistTap(sectionIndex: index, gistIndex: gistIndex)
                        }
                    )
                    .padding(.horizontal, GistyTokens.Spacing.xxl)
                }
            }
            .padding(.vertical, GistyTokens.Spacing.l)
        }
        .refreshable {
            await refreshGists()
        }
    }
    
    // MARK: - Methods
    
    private func onAppear() async {
        await loadFeedSections()
        setupServices()
        
        // Auto-generate gists on first launch if needed
        if feedSections.isEmpty, !isRefreshing {
            await autoGenerateIfNeeded()
        }
    }
    
    private func loadFeedSections() async {
        do {
            let allGists = try dataManager.fetchRecentGists(limit: 50)
            
            // Filter gists by current language setting
            let currentLocale = UserSettings.shared.language.code
            let gists = allGists.filter { $0.locale == currentLocale }
            
            print("📊 Loaded \(allGists.count) total gists, \(gists.count) in \(currentLocale)")
            
            // Group gists by source
            let groupedGists = Dictionary(grouping: gists) { $0.source?.id ?? 0 }
            
            feedSections = groupedGists.compactMap { chatId, gists in
                guard let firstGist = gists.first,
                      let source = firstGist.source else {
                    return nil
                }
                
                return FeedSection(
                    publisher: source.title,
                    avatar: String(source.title.prefix(1)),
                    unreadCount: source.unreadCount,
                    gists: gists.map { gist in
                        FeedGist(
                            text: gist.summary,
                            tone: determineTone(from: gist),
                            isRead: false, // TODO: Track read status
                            gistId: gist.id
                        )
                    }
                )
            }
            .sorted { $0.publisher < $1.publisher }
            
        } catch {
            print("❌ Error loading gists: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func setupServices() {
        // Use OpenRouter with Claude 3.5 Haiku for best quality/speed ratio
        guard let apiKey = ConfigurationManager.shared.openRouterApiKey,
              !apiKey.isEmpty else {
            AppLogger.warning("⚠️ OpenRouter API key not configured", category: AppLogger.ai)
            return
        }
        
        // Create smart architecture dependencies
        let scheduler = FetchScheduler(dataManager: dataManager)
        let incrementalFetcher = IncrementalFetcher(
            telegram: telegram,
            scheduler: scheduler
        )
        
        let collector = MessageCollector(
            telegram: telegram,
            dataManager: dataManager,
            scheduler: scheduler,
            incrementalFetcher: incrementalFetcher
        )
        
        let llm = LLMService(config: LLMService.Config(
            provider: .openrouter,
            model: "anthropic/claude-haiku-4.5",  // ⚠️ HAIKU 4.5!
            apiKey: apiKey,
            maxTokens: 1000,
            temperature: 0.3
        ))
        let generator = GistGenerator(
            messageCollector: collector,
            llmService: llm,
            dataManager: dataManager
        )
        
        AppLogger.logAI("✅ LLM Service configured: OpenRouter (Claude Haiku 4.5)")
        
        messageCollector = collector
        llmService = llm
        gistGenerator = generator
        
        print("✅ LLM services initialized")
    }
    
    private func autoGenerateIfNeeded() async {
        guard let selectedSources = try? dataManager.fetchSelectedSources(),
              !selectedSources.isEmpty else {
            print("ℹ️ No sources selected, skipping auto-generation")
            return
        }
        
        guard ConfigurationManager.shared.hasValidOpenRouterCredentials else {
            errorMessage = "Please configure OpenRouter API key in Settings"
            showError = true
            return
        }
        
        print("🚀 Auto-generating gists for \(selectedSources.count) sources...")
        await refreshGists()
    }
    
    private func refreshGists() async {
        guard !isRefreshing else { return }
        
        guard let selectedSources = try? dataManager.fetchSelectedSources(),
              !selectedSources.isEmpty else {
            errorMessage = "Please select sources in the Sources tab first"
            showError = true
            return
        }
        
        guard ConfigurationManager.shared.hasValidOpenRouterCredentials else {
            errorMessage = "Please configure OpenRouter API key in Settings"
            showError = true
            return
        }
        
        guard let generator = gistGenerator else {
            errorMessage = "LLM service not configured. Please restart the app."
            showError = true
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            print("📝 Generating gists for \(selectedSources.count) sources...")
            
            let generatedGists = try await generator.generateGists(
                period: .twentyFourHours,
                locale: Locale.current.language.languageCode?.identifier ?? "en"
            )
            
            print("✅ Generated \(generatedGists.count) gists")
            
            await loadFeedSections()
        } catch {
            print("❌ Error generating gists: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleGistTap(sectionIndex: Int, gistIndex: Int) {
        guard sectionIndex < feedSections.count,
              gistIndex < feedSections[sectionIndex].gists.count else {
            return
        }
        
        let gistId = feedSections[sectionIndex].gists[gistIndex].gistId
        
        // TODO: Navigate to detail view
        print("📖 Tapped gist: \(gistId)")
    }
    
    private func determineTone(from gist: Gist) -> GistTone {
        // Simple heuristic: check for breaking news keywords
        let breakingKeywords = ["breaking", "urgent", "alert", "critical", "emergency"]
        let lowercasedSummary = gist.summary.lowercased()
        
        if breakingKeywords.contains(where: { lowercasedSummary.contains($0) }) {
            return .breaking
        }
        
        return .default
    }
}

// MARK: - Feed Models

struct FeedSection: Identifiable {
    let id = UUID()
    let publisher: String
    let avatar: String?
    let unreadCount: Int?
    var gists: [FeedGist]
}

struct FeedGist: Identifiable {
    let id = UUID()
    let text: String
    let tone: GistTone
    var isRead: Bool
    let gistId: UUID
}

// MARK: - Menu View

struct MenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var telegram: TelegramManager
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Sources") {
                        SourceSelectionView(telegram: telegram)
                    }
                    
                    NavigationLink("Settings") {
                        SettingsView()
                    }
                }
                
                Section {
                    Button("Logout", role: .destructive) {
                        Task {
                            try? await telegram.logout()
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NewFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NewFeedView(telegram: TelegramManager.shared)
            .environmentObject(DataManager.shared)
    }
}
#endif
