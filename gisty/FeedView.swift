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
                    ProgressView("Generating gists...")
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .navigationTitle("Gists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
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
            
            Text("No Gists Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Generate summaries from your Telegram chats")
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
                    Text("Generate Gists")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isRefreshing)
        }
    }
    
    private var gistListView: some View {
        List {
            ForEach(gists) { gist in
                NavigationLink(destination: GistDetailView(gist: gist, telegram: telegram)) {
                    GistCard(gist: gist, telegram: telegram)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshGists()
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
            gists = try dataManager.fetchRecentGists(limit: 50)
        } catch {
            print("Error loading gists: \(error)")
        }
    }
    
    private func setupServices() {
        guard let apiKey = ConfigurationManager.shared.openAIApiKey,
              !apiKey.isEmpty else {
            print("⚠️ OpenAI API key not configured")
            return
        }
        
        let collector = MessageCollector(telegram: telegram, dataManager: dataManager)
        let llm = LLMService(config: LLMService.Config(
            provider: .openai,
            model: "gpt-4o-mini",
            apiKey: apiKey
        ))
        let generator = GistGenerator(
            messageCollector: collector,
            llmService: llm,
            dataManager: dataManager
        )
        
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
        guard ConfigurationManager.shared.hasValidOpenAICredentials else {
            errorMessage = "Please configure OpenAI API key in Settings"
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
            errorMessage = "Please select sources in the Sources tab first"
            showError = true
            return
        }
        
        // Check if OpenAI API key is configured
        guard ConfigurationManager.shared.hasValidOpenAICredentials else {
            errorMessage = "Please configure OpenAI API key in Settings"
            showError = true
            return
        }
        
        // Check if generator is ready
        guard let generator = gistGenerator else {
            errorMessage = "LLM service not configured. Please restart the app."
            showError = true
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            print("📝 Generating gists for \(selectedSources.count) sources...")
            
            // Generate gists for default period (24 hours)
            let generatedGists = try await generator.generateGists(period: .twentyFourHours, locale: "en")
            
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
            HStack {
                Image(systemName: gist.source?.type.icon ?? "message")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gist.source?.title ?? "Unknown Source")
                        .font(.headline)
                    
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
                Button("Read more") {
                    withAnimation {
                        isExpanded = true
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Bullets
            if !gist.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(gist.bullets.prefix(isExpanded ? 100 : 3), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.blue)
                            Text(bullet)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            // Links
            if !gist.links.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(gist.links.prefix(isExpanded ? 100 : 2), id: \.url) { link in
                        Link(destination: URL(string: link.url) ?? URL(string: "https://google.com")!) {
                            HStack {
                                Image(systemName: "link")
                                    .font(.caption)
                                Text(link.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.blue)
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
                
                Text(gist.modelUsed)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var periodText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: gist.periodStart)) - \(formatter.string(from: gist.periodEnd))"
    }
}

