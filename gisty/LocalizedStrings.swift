//
//  LocalizedStrings.swift
//  gisty
//
//  Centralized localization for the app
//

import Foundation

/// Centralized localization based on UserSettings language
struct L {
    
    /// Current language code
    private static var locale: String {
        UserSettings.shared.language.code
    }
    
    /// Check if current language is Russian
    private static var isRu: Bool {
        locale == "ru"
    }
    
    // MARK: - Navigation Titles
    
    // App name - never translate
    static var appName: String {
        "Gisty"
    }
    
    static var sources: String {
        isRu ? "Источники" : "Sources"
    }
    
    static var feed: String {
        isRu ? "Лента" : "Feed"
    }
    
    static var settings: String {
        isRu ? "Настройки" : "Settings"
    }
    
    // MARK: - Common Actions
    
    static var readMore: String {
        isRu ? "Читать далее" : "Read more"
    }
    
    static var cancel: String {
        isRu ? "Отмена" : "Cancel"
    }
    
    static var ok: String {
        isRu ? "OK" : "OK"
    }
    
    static var save: String {
        isRu ? "Сохранить" : "Save"
    }
    
    static var delete: String {
        isRu ? "Удалить" : "Delete"
    }
    
    static var close: String {
        isRu ? "Закрыть" : "Close"
    }
    
    // MARK: - Feed View
    
    static var noGistsYet: String {
        isRu ? "Пока нет дайджестов" : "No Gists Yet"
    }
    
    static var generateSummariesDescription: String {
        isRu ? "Создавайте суммаризации из ваших Telegram чатов" : "Generate summaries from your Telegram chats"
    }
    
    static var generateGists: String {
        isRu ? "Создать дайджесты" : "Generate Gists"
    }
    
    static var generatingGists: String {
        isRu ? "Создание дайджестов..." : "Generating gists..."
    }
    
    static var error: String {
        isRu ? "Ошибка" : "Error"
    }
    
    static var success: String {
        isRu ? "Успешно" : "Success"
    }
    
    static var now: String {
        isRu ? "сейчас" : "now"
    }
    
    static var minutesAgo: String {
        isRu ? "минут назад" : "minutes ago"
    }
    
    static var hoursAgo: String {
        isRu ? "часов назад" : "hours ago"
    }
    
    static var daysAgo: String {
        isRu ? "дней назад" : "days ago"
    }
    
    // MARK: - Settings View
    
    static var gistLanguage: String {
        isRu ? "Язык дайджестов" : "Gist Language"
    }
    
    static var gistLanguageDescription: String {
        isRu ? "Суммаризации будут создаваться на выбранном языке" : "Summaries will be generated in the selected language"
    }
    
    static var messageCountPeriod: String {
        isRu ? "Период подсчёта сообщений" : "Message Count Period"
    }
    
    static var messageCountPeriodDescription: String {
        isRu ? "Показывать количество непрочитанных сообщений за выбранный период на экране выбора источников" 
            : "Show unread message count for the selected time period on the source selection screen"
    }
    
    static var about: String {
        isRu ? "О приложении" : "About"
    }
    
    static var version: String {
        isRu ? "Версия" : "Version"
    }
    
    static var app: String {
        isRu ? "Приложение" : "App"
    }
    
    // MARK: - Source Selection
    
    static var searchChats: String {
        isRu ? "Поиск чатов..." : "Search chats..."
    }
    
    static var allChats: String {
        isRu ? "Все" : "All"
    }
    
    static var channels: String {
        isRu ? "Каналы" : "Channels"
    }
    
    static var groups: String {
        isRu ? "Группы" : "Groups"
    }
    
    static var privateChats: String {
        isRu ? "Личные" : "Private"
    }
    
    static var chats: String {
        isRu ? "чатов" : "chats"
    }
    
    static var tracked: String {
        isRu ? "отслеживается" : "tracked"
    }
    
    static var loadingChats: String {
        isRu ? "Загрузка чатов..." : "Loading chats..."
    }
    
    static var errorLoadingChats: String {
        isRu ? "Ошибка загрузки чатов" : "Error Loading Chats"
    }
    
    static var retry: String {
        isRu ? "Повторить" : "Retry"
    }
    
    static var noChatsFound: String {
        isRu ? "Чаты не найдены" : "No Chats Found"
    }
    
    static var noChatsMatchFilter: String {
        isRu ? "Нет чатов, соответствующих фильтру" : "No chats match your filter"
    }
    
    static var tryDifferentFilter: String {
        isRu ? "Попробуйте другой фильтр или очистите поиск" : "Try a different filter or clear the search"
    }
    
    // MARK: - Chat Types
    
    static var channel: String {
        isRu ? "Канал" : "Channel"
    }
    
    static var group: String {
        isRu ? "Группа" : "Group"
    }
    
    static var privateChat: String {
        isRu ? "Личный чат" : "Private"
    }
    
    static var chat: String {
        isRu ? "Чат" : "Chat"
    }
    
    // MARK: - Errors
    
    static var pleaseConfigureAPIKey: String {
        isRu ? "Пожалуйста, настройте OpenRouter API ключ в Настройках" : "Please configure OpenRouter API key in Settings"
    }
    
    static var pleaseSelectSources: String {
        isRu ? "Пожалуйста, выберите источники во вкладке Источники" : "Please select sources in the Sources tab first"
    }
    
    static var llmServiceNotConfigured: String {
        isRu ? "LLM сервис не настроен. Пожалуйста, перезапустите приложение." : "LLM service not configured. Please restart the app."
    }
    
    // MARK: - Time Periods
    
    static var oneHour: String {
        isRu ? "1 час" : "1 hour"
    }
    
    static var sixHours: String {
        isRu ? "6 часов" : "6 hours"
    }
    
    static var twelveHours: String {
        isRu ? "12 часов" : "12 hours"
    }
    
    static var twentyFourHours: String {
        isRu ? "24 часа" : "24 hours"
    }
    
    // MARK: - Gist Detail
    
    static var regenerate: String {
        isRu ? "Пересоздать" : "Regenerate"
    }
    
    static var regenerateGist: String {
        isRu ? "Пересоздать дайджест" : "Regenerate Gist"
    }
    
    static var regenerateConfirmation: String {
        isRu ? "Это создаст новый дайджест для данного источника и периода. Продолжить?" 
            : "This will create a new gist for this source and period. Continue?"
    }
    
    static var messagesCount: (Int) -> String {
        { count in
            if isRu {
                let lastDigit = count % 10
                let lastTwoDigits = count % 100
                
                if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
                    return "\(count) сообщений"
                }
                
                switch lastDigit {
                case 1: return "\(count) сообщение"
                case 2, 3, 4: return "\(count) сообщения"
                default: return "\(count) сообщений"
                }
            } else {
                return count == 1 ? "\(count) message" : "\(count) messages"
            }
        }
    }
}
