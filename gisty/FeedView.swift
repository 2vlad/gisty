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
            .navigationTitle(L.appName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .onAppear {
                // Make navigation title 20% larger
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                
                // Large title font (20% larger)
                let largeTitleFont = UIFont.systemFont(ofSize: 40.8, weight: .bold) // Default 34 * 1.2 = 40.8
                appearance.largeTitleTextAttributes = [.font: largeTitleFont]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
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
                .cornerRadius(12)
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        
        let collector = MessageCollector(telegram: telegram, dataManager: dataManager)
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
    
    @State private var isExpanded = false
    
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
            
            // Summary
            Text(gist.summary)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
            
            if !isExpanded && gist.summary.count > 150 {
                Button(L.readMore) {
                    withAnimation {
                        isExpanded = true
                    }
                }
                .font(.caption)
                .foregroundColor(.primary)
            }
            
            // Bullets
            if !gist.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(gist.bullets.prefix(isExpanded ? 100 : 3), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(bullet)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.top, 4)
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
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
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

