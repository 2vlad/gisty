//
//  ContentView.swift
//  gisty
//
//  Created by admin on 08.11.2025.
//

import SwiftUI
import SwiftData
import TDLibKit

struct ContentView: View {
    @EnvironmentObject private var telegram: TelegramManager
    @State private var errorMessage: String?
    
    private let config = ConfigurationManager.shared
    
    var body: some View {
        Group {
            // Show appropriate view based on auth state
            switch telegram.authorizationState {
            case .unauthorized, .waitingForPhoneNumber:
                PhoneNumberView(telegram: telegram)
                
            case .waitingForCode:
                CodeVerificationView(telegram: telegram)
                
            case .waitingForPassword:
                PasswordView(telegram: telegram)
                
            case .authorized:
                MainView(telegram: telegram)
                
            default:
                // Show loading for transitional states
                loadingView
            }
        }
    }
    
    // MARK: - Auto Initialization
    // Note: TelegramManager initialization is now handled in gistyApp.swift
    // This ensures the client is ready before ContentView is shown
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Text("Gisty")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Connecting to Telegram...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Main View (After Authentication)

struct MainView: View {
    @ObservedObject var telegram: TelegramManager
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            FeedView(telegram: telegram)
                .tabItem {
                    Label(L.feed, systemImage: "doc.text")
                }
            
            SourceManagementView(telegram: telegram)
                .tabItem {
                    Label(L.sources, systemImage: "list.bullet")
                }
        }
    }
}

// MARK: - Source Management View

struct SourceManagementView: View {
    @ObservedObject var telegram: TelegramManager
    @EnvironmentObject var dataManager: DataManager
    
    @State private var chats: [Chat] = []
    @State private var selectedChatIds: Set<Int64> = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var filterType: ChatFilterType = .all
    @State private var errorMessage: String?
    @State private var showSettings = false
    
    var filteredChats: [Chat] {
        var filtered = chats
        
        // Apply type filter
        switch filterType {
        case .all:
            break
        case .channels:
            filtered = filtered.filter { chat in
                if case .chatTypeSupergroup(let info) = chat.type, info.isChannel {
                    return true
                }
                return false
            }
        case .groups:
            filtered = filtered.filter { chat in
                if case .chatTypeSupergroup(let info) = chat.type, !info.isChannel {
                    return true
                }
                if case .chatTypeBasicGroup = chat.type {
                    return true
                }
                return false
            }
        case .private:
            filtered = filtered.filter { chat in
                if case .chatTypePrivate = chat.type {
                    return true
                }
                if case .chatTypeSecret = chat.type {
                    return true
                }
                return false
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    searchBarSection
                    
                    // Filter chips
                    filterChipsSection
                    
                    // Stats header
                    if !isLoading && !chats.isEmpty {
                        statsHeader
                    }
                    
                    // Content
                    if isLoading {
                        loadingView
                    } else if chats.isEmpty {
                        emptyStateView
                    } else {
                        chatListView
                    }
                }
            }
            .navigationTitle(L.sources)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await loadChats()
                loadExistingSelections()
            }
            .refreshable {
                await loadChats()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField(L.searchChats, text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Filter Chips
    
    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatFilterType.allCases, id: \.self) { filter in
                    FilterChipButton(
                        title: filter.displayName,
                        icon: filter.icon,
                        isSelected: filterType == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            filterType = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack {
            Text("\(filteredChats.count) \(L.chats)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if selectedChatIds.count > 0 {
                Text("\(selectedChatIds.count) \(L.tracked)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(L.errorLoadingChats)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await loadChats()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(L.retry)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonChatRow()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Text(L.loadingChats)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No chats found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Start a conversation in Telegram")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Chat List
    
    private var chatListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredChats, id: \.id) { chat in
                    ModernChatRow(
                        chat: chat,
                        isSelected: selectedChatIds.contains(chat.id),
                        action: {
                            toggleSelection(chatId: chat.id)
                        },
                        telegram: telegram
                    )
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Actions
    
    private func loadChats() async {
        isLoading = true
        errorMessage = nil
        
        print("🔍 [Sources] Loading chats...")
        
        do {
            let loadedChats = try await telegram.loadChats(limit: 50)
            
            print("✅ [Sources] Loaded \(loadedChats.count) chats")
            
            await MainActor.run {
                self.chats = loadedChats
                isLoading = false
            }
        } catch {
            print("❌ [Sources] Error loading chats: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load chats: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadExistingSelections() {
        do {
            let sources = try dataManager.fetchSelectedSources()
            selectedChatIds = Set(sources.map { $0.id })
        } catch {
            print("Error loading existing selections: \(error)")
        }
    }
    
    private func toggleSelection(chatId: Int64) {
        withAnimation(.spring(response: 0.3)) {
            if selectedChatIds.contains(chatId) {
                selectedChatIds.remove(chatId)
                removeSource(chatId: chatId)
            } else {
                selectedChatIds.insert(chatId)
                addSource(chatId: chatId)
            }
        }
    }
    
    private func addSource(chatId: Int64) {
        guard let chat = chats.first(where: { $0.id == chatId }) else { return }
        
        do {
            let sourceType = mapChatType(chat.type)
            
            // Check if source exists
            if let existing = try dataManager.fetchSource(byId: chatId) {
                existing.isSelected = true
                existing.updatedAt = Foundation.Date()
            } else {
                // Create new source
                let source = Source(
                    id: chatId,
                    type: sourceType,
                    title: chat.title,
                    isSelected: true
                )
                dataManager.mainContext.insert(source)
            }
            
            try dataManager.mainContext.save()
            print("✅ Added source: \(chat.title)")
        } catch {
            print("❌ Error adding source: \(error)")
        }
    }
    
    private func removeSource(chatId: Int64) {
        do {
            if let source = try dataManager.fetchSource(byId: chatId) {
                source.isSelected = false
                try dataManager.mainContext.save()
                print("✅ Removed source: \(source.title)")
            }
        } catch {
            print("❌ Error removing source: \(error)")
        }
    }
    
    private func mapChatType(_ chatType: ChatType) -> SourceType {
        switch chatType {
        case .chatTypeSupergroup(let info):
            return info.isChannel ? .channel : .group
        case .chatTypeBasicGroup:
            return .group
        case .chatTypePrivate, .chatTypeSecret:
            return .privateChat
        @unknown default:
            return .privateChat
        }
    }
}

#Preview {
    ContentView()
}
