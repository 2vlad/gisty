//
//  ChatAvatarLoader.swift
//  gisty
//
//  Helper for loading and caching chat avatars
//

import Foundation
import SwiftUI
import TDLibKit
import Combine

/// In-memory image cache
class AvatarCache {
    static let shared = AvatarCache()
    private var imageCache: [Int: UIImage] = [:]
    private var chatCache: [Int64: Chat] = [:]
    private let queue = DispatchQueue(label: "AvatarCache", attributes: .concurrent)
    
    func getImage(_ fileId: Int) -> UIImage? {
        queue.sync { imageCache[fileId] }
    }
    
    func setImage(_ image: UIImage, for fileId: Int) {
        queue.async(flags: .barrier) { [weak self] in
            self?.imageCache[fileId] = image
        }
    }
    
    func getChat(_ chatId: Int64) -> Chat? {
        queue.sync { chatCache[chatId] }
    }
    
    func setChat(_ chat: Chat, for chatId: Int64) {
        queue.async(flags: .barrier) { [weak self] in
            self?.chatCache[chatId] = chat
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAll()
            self?.chatCache.removeAll()
        }
    }
}

/// Loads and caches chat avatar images
@MainActor
class ChatAvatarLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let telegram: TelegramManager
    private let fileId: Int
    private var loadTask: Task<Void, Never>?
    
    init(telegram: TelegramManager, fileId: Int) {
        self.telegram = telegram
        self.fileId = fileId
        
        // Check memory cache first
        if let cachedImage = AvatarCache.shared.getImage(fileId) {
            self.image = cachedImage
        }
    }
    
    func load() {
        guard !isLoading, image == nil else { return }
        
        loadTask?.cancel()
        loadTask = Task {
            await loadAvatar()
        }
    }
    
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
    
    private func loadAvatar() async {
        guard let client = telegram.client else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get file info
            let file = try await client.getFile(fileId: fileId)
            
            // Check if already downloaded
            if file.local.isDownloadingCompleted, !file.local.path.isEmpty {
                // Load from local path
                if let image = UIImage(contentsOfFile: file.local.path) {
                    self.image = image
                    AvatarCache.shared.setImage(image, for: fileId)
                    return
                }
            }
            
            // Download file
            let downloadedFile = try await client.downloadFile(
                fileId: fileId,
                limit: 0,
                offset: 0,
                priority: 1,
                synchronous: true
            )
            
            // Load image from downloaded file
            if downloadedFile.local.isDownloadingCompleted,
               !downloadedFile.local.path.isEmpty,
               let image = UIImage(contentsOfFile: downloadedFile.local.path) {
                self.image = image
                AvatarCache.shared.setImage(image, for: fileId)
            }
        } catch {
            AppLogger.warning("Failed to load avatar for file \(fileId): \(error)", category: AppLogger.telegram)
        }
    }
}

/// SwiftUI view for displaying chat avatar
struct ChatAvatarView: View {
    let chat: Chat
    let telegram: TelegramManager
    let size: CGFloat
    
    @StateObject private var loader: ChatAvatarLoader
    
    init(chat: Chat, telegram: TelegramManager, size: CGFloat = 50) {
        self.chat = chat
        self.telegram = telegram
        self.size = size
        
        // Initialize loader with small photo if available
        if let photoFileId = chat.photo?.small.id {
            _loader = StateObject(wrappedValue: ChatAvatarLoader(telegram: telegram, fileId: photoFileId))
        } else {
            // Dummy loader for chats without photo
            _loader = StateObject(wrappedValue: ChatAvatarLoader(telegram: telegram, fileId: -1))
        }
    }
    
    var body: some View {
        ZStack {
            if let image = loader.image {
                // Display loaded avatar
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to gradient avatar
                ZStack {
                    LinearGradient(
                        colors: gradientColors(for: chat.title),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    
                    if loader.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: chatIcon)
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            if chat.photo?.small.id != nil {
                loader.load()
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }
    
    private var chatIcon: String {
        switch chat.type {
        case .chatTypeSupergroup(let info):
            return info.isChannel ? "megaphone.fill" : "person.3.fill"
        case .chatTypeBasicGroup:
            return "person.3.fill"
        case .chatTypePrivate, .chatTypeSecret:
            return "person.fill"
        @unknown default:
            return "bubble.left.fill"
        }
    }
    
    private func gradientColors(for title: String) -> [Color] {
        let hash = abs(title.hashValue)
        let brightness1 = 0.3 + (Double(hash % 70) / 100.0) // 0.3 to 1.0
        let brightness2 = 0.2 + (Double((hash / 2) % 80) / 100.0) // 0.2 to 1.0
        
        return [
            Color(white: brightness1),
            Color(white: brightness2)
        ]
    }
}

/// SwiftUI view for displaying source avatar by chatId
struct SourceAvatarView: View {
    let chatId: Int64
    let title: String
    let telegram: TelegramManager
    let size: CGFloat
    
    @State private var chat: Chat?
    @State private var isLoading = false
    
    init(chatId: Int64, title: String, telegram: TelegramManager, size: CGFloat = 40) {
        self.chatId = chatId
        self.title = title
        self.telegram = telegram
        self.size = size
        
        // Check cache first
        if let cachedChat = AvatarCache.shared.getChat(chatId) {
            _chat = State(initialValue: cachedChat)
        }
    }
    
    var body: some View {
        Group {
            if let chat = chat {
                ChatAvatarView(chat: chat, telegram: telegram, size: size)
            } else {
                // Fallback gradient while loading
                ZStack {
                    LinearGradient(
                        colors: gradientColors(for: title),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "message")
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            await loadChat()
        }
    }
    
    private func loadChat() async {
        guard let client = telegram.client, chat == nil else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedChat = try await client.getChat(chatId: chatId)
            AvatarCache.shared.setChat(loadedChat, for: chatId)
            await MainActor.run {
                self.chat = loadedChat
            }
        } catch {
            AppLogger.warning("Failed to load chat \(chatId) for avatar: \(error)", category: AppLogger.telegram)
        }
    }
    
    private func gradientColors(for title: String) -> [Color] {
        let hash = abs(title.hashValue)
        let brightness1 = 0.3 + (Double(hash % 70) / 100.0)
        let brightness2 = 0.2 + (Double((hash / 2) % 80) / 100.0)
        
        return [
            Color(white: brightness1),
            Color(white: brightness2)
        ]
    }
}
