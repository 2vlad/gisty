//
//  FeedView.swift
//  gisty
//
//  Created by admin on 08.11.2025.
//

import SwiftUI
import SwiftData

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
                if gists.isEmpty && !isRefreshing {
                    emptyStateView
                } else {
                    gistListView
                }
                
                if isRefreshing {
                    ProgressView(L.generatingGists)
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 112)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                await onAppear()
            }
            .alert(L.error, isPresented: $showError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
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
            
            Text(L.generateSummariesDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
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
                .frame(maxWidth: 200)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(isRefreshing)
        }
    }
    
    private var gistListView: some View {
        List {
            ForEach(gists) { gist in
                GistCard(gist: gist, telegram: telegram)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedGist = gist
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshGists()
        }
        .sheet(item: $selectedGist) { gist in
            GistDetailView(gist: gist, telegram: telegram)
        }
    }
    
    // MARK: - Methods
    
    private func onAppear() async {
        // DEBUG: Print all available fonts
        print("=== Available Font Families ===")
        for family in UIFont.familyNames.sorted() {
            print("\nFamily: \(family)")
            for font in UIFont.fontNames(forFamilyName: family) {
                print("  - \(font)")
            }
        }
        print("=== End of Fonts ===")
        
        loadGists()
        setupServices()
        
        // Auto-generate gists on first launch if database is empty and sources are selected
        if gists.isEmpty, !isRefreshing {
            await autoGenerateIfNeeded()
        }
    }
    
    private func loadGists() {
        do {
            let allGists = try dataManager.fetchRecentGists(limit: 50)
            
            // Filter gists by current language setting
            let currentLocale = UserSettings.shared.language.code
            gists = allGists.filter { $0.locale == currentLocale }
            
            print("📊 Loaded \(allGists.count) total gists, \(gists.count) in \(currentLocale)")
        } catch {
            print("Error loading gists: \(error)")
        }
    }
    
    private func setupServices() {
        // Use OpenRouter with Claude 3.5 Haiku for best quality/speed ratio
        guard let apiKey = ConfigurationManager.shared.openRouterApiKey,
              !apiKey.isEmpty else {
            AppLogger.warning("⚠️ OpenRouter API key not configured", category: AppLogger.ai)
            return
        }
        
        // 🚀 ETAP 2: Smart Architecture
        // Create scheduler for 5-minute intervals and prioritization
        let scheduler = FetchScheduler(dataManager: dataManager)
        fetchScheduler = scheduler
        
        // Create incremental fetcher (only new messages!)
        let fetcher = IncrementalFetcher(
            telegram: telegram,
            scheduler: scheduler
        )
        incrementalFetcher = fetcher
        
        // 🎯 EVENT-DRIVEN: Create update router to handle TDLib events
        let router = TelegramUpdateRouter(
            dataManager: dataManager,
            scheduler: scheduler,
            incrementalFetcher: fetcher
        )
        updateRouter = router
        
        // Connect router to TelegramManager for event handling
        telegram.updateRouter = router
        
        AppLogger.logTelegram("✅ Event-driven router connected to TelegramManager")
        
        // Create message collector with smart dependencies
        let collector = MessageCollector(
            telegram: telegram,
            dataManager: dataManager,
            scheduler: scheduler,
            incrementalFetcher: fetcher
        )
        messageCollector = collector
        
        AppLogger.logData("✅ Smart architecture initialized: FetchScheduler + IncrementalFetcher + UpdateRouter")
        
        // LLM setup (unchanged)
        let llm = LLMService(config: LLMService.Config(
            provider: .openrouter,
            model: "anthropic/claude-haiku-4.5",  // ⚠️ HAIKU 4.5!
            apiKey: apiKey,
            maxTokens: 1000,
            temperature: 0.3
        ))
        llmService = llm
        
        let generator = GistGenerator(
            messageCollector: collector,
            llmService: llm,
            dataManager: dataManager
        )
        gistGenerator = generator
        
        AppLogger.logAI("✅ LLM Service configured: OpenRouter (Claude Haiku 4.5)")
        
        print("✅ Services initialized with smart architecture v2")
    }
    
    private func autoGenerateIfNeeded() async {
        // Check if we have selected sources
        guard let selectedSources = try? dataManager.fetchSelectedSources(),
              !selectedSources.isEmpty else {
            print("ℹ️ No sources selected, skipping auto-generation")
            return
        }
        
        // Check if OpenAI key is configured
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
        
        // Check if sources are selected
        guard let selectedSources = try? dataManager.fetchSelectedSources(),
              !selectedSources.isEmpty else {
            errorMessage = L.pleaseSelectSources
            showError = true
            return
        }
        
        // Check if OpenAI API key is configured
        guard ConfigurationManager.shared.hasValidOpenRouterCredentials else {
            errorMessage = L.pleaseConfigureAPIKey
            showError = true
            return
        }
        
        // Check if generator is ready
        guard let generator = gistGenerator else {
            errorMessage = L.llmServiceNotConfigured
            showError = true
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Get selected language from settings
        let locale = UserSettings.shared.language.code
        
        do {
            print("📝 Generating gists for \(selectedSources.count) sources in \(locale)...")
            
            // Generate gists for default period (72 hours)
            let generatedGists = try await generator.generateGists(period: .seventyTwoHours, locale: locale)
            
            print("✅ Generated \(generatedGists.count) gists")
            
            // Reload gists
            loadGists()
        } catch {
            print("❌ Error generating gists: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Gist Card

struct GistCard: View {
    let gist: Gist
    let telegram: TelegramManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                if let source = gist.source {
                    SourceAvatarView(
                        chatId: source.id,
                        title: source.title,
                        telegram: telegram,
                        size: 40
                    )
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 2.67) {
                    Text(gist.source?.title ?? "Unknown Source")
                        .font(.headline)
                        .lineSpacing(-3.6) // 20% reduction from default line height
                    
                    Text(periodText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(gist.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Bullets (main content)
            if !gist.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(gist.bullets.prefix(5), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.custom("EB Garamond", size: 16))
                                .foregroundColor(.primary)
                            Text(bullet)
                                .font(.custom("EB Garamond", size: 16))
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Label("\(gist.messagesCount)", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(14)
        .background(
            Color(red: 0.953, green: 0.949, blue: 0.941) // #F3F2F0
        )
        .cornerRadius(20)
    }
    
    private var periodText: String {
        guard let source = gist.source else { return "" }
        
        switch source.type {
        case .channel:
            return "Канал"
        case .group, .privateChat:
            return "Чат"
        }
    }
}

