//
//  GistDetailView.swift
//  gisty
//
//  Created by admin on 08.11.2025.
//

import SwiftUI

struct GistDetailView: View {
    let gist: Gist
    let telegram: TelegramManager
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var isRegenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                headerSection
                
                Divider()
                
                // Summary Section
                summarySection
                
                // Bullets Section
                if !gist.bullets.isEmpty {
                    bulletsSection
                }
                
                // Links Section
                if !gist.links.isEmpty {
                    linksSection
                }
                
                Divider()
                
                // Metadata Section
                metadataSection
                
                // Actions Section
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Gist Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isRegenerating {
                RegeneratingOverlay()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: gist.source?.type.icon ?? "message")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading) {
                    Text(gist.source?.title ?? "Unknown Source")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(gist.source?.type.displayName ?? "Source")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Label(periodText, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.primary)
                Text("Summary")
                    .font(.headline)
            }
            
            Text(gist.summary)
                .font(.custom("EB Garamond", size: 18))
                .lineSpacing(4)
        }
    }
    
    private var bulletsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.primary)
                Text("Key Points")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(gist.bullets.enumerated()), id: \.offset) { index, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 24, height: 24)
                            
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Text(bullet)
                            .font(.custom("EB Garamond", size: 17))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
    
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ссылки")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(gist.links, id: \.url) { link in
                    Link(destination: URL(string: link.url) ?? URL(string: "https://google.com")!) {
                        Text(link.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .underline()
                            .lineLimit(1)
                    }
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            
            VStack(spacing: 8) {
                MetadataRow(icon: "message", label: "Messages", value: "\(gist.messagesCount)")
                MetadataRow(icon: "cpu", label: "Model", value: gist.modelUsed)
                MetadataRow(icon: "calendar", label: "Generated", value: gist.createdAt.formatted(.dateTime))
                MetadataRow(icon: "globe", label: "Locale", value: gist.locale.uppercased())
                MetadataRow(icon: "number", label: "Hash", value: String(gist.summaryHash.prefix(8)))
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Open in Telegram Button
            Button(action: openInTelegram) {
                Label("Open in Telegram", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            
            // Regenerate Button
            Button(action: regenerateGist) {
                Label("Regenerate Gist", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .disabled(isRegenerating)
        }
    }
    
    // MARK: - Computed Properties
    
    private var periodText: String {
        guard let source = gist.source else { return "" }
        
        switch source.type {
        case .channel:
            return "Канал"
        case .group, .privateChat:
            return "Чат"
        }
    }
    
    // MARK: - Actions
    
    private func openInTelegram() {
        guard let sourceId = gist.source?.id else { return }
        
        // Construct Telegram deep link (tg://resolve?domain=chat_id)
        // For private chats and groups, use chat_id directly
        let urlString = "tg://openmessage?chat_id=\(sourceId)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func regenerateGist() {
        guard gist.source != nil else {
            errorMessage = "Source not found"
            showError = true
            return
        }
        
        Task {
            isRegenerating = true
            defer { isRegenerating = false }
            
            do {
                // Setup services - Use OpenRouter with Claude 3.5 Haiku
                guard let apiKey = ConfigurationManager.shared.openRouterApiKey, !apiKey.isEmpty else {
                    errorMessage = "OpenRouter API key not configured"
                    showError = true
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
                
                AppLogger.logAI("✅ Regenerating with OpenRouter (Claude Haiku 4.5)")
                
                // Delete old gist
                try dataManager.deleteGist(gist)
                
                // Calculate period from existing gist
                let period = calculatePeriod(from: gist.periodStart, to: gist.periodEnd)
                
                // Get selected language from settings (use existing gist locale as fallback)
                let locale = UserSettings.shared.language.code
                
                // Generate new gist
                _ = try await generator.generateGists(period: period, locale: locale)
                
                // Dismiss detail view
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func calculatePeriod(from start: Date, to end: Date) -> TimePeriod {
        let hours = Int(end.timeIntervalSince(start) / 3600)
        
        switch hours {
        case 0..<12:
            return .sixHours
        case 12..<18:
            return .twelveHours
        case 18..<48:
            return .twentyFourHours
        default:
            return .seventyTwoHours
        }
    }
}

// MARK: - Supporting Views

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct RegeneratingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Regenerating Gist...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                Color(red: 0.953, green: 0.949, blue: 0.941) // #F3F2F0
            )
            .cornerRadius(20)
        }
    }
}
