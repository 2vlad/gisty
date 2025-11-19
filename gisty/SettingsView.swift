//
//  SettingsView.swift
//  gisty
//
//  User settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = UserSettings.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            settings.appTheme = theme
                        } label: {
                            HStack {
                                Image(systemName: theme.icon)
                                    .foregroundColor(.primary)
                                    .frame(width: 30)
                                
                                Text(theme.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if settings.appTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primary)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L.appearance)
                }
                
                // Language Section
                Section {
                    ForEach(Language.allCases, id: \.self) { language in
                        Button {
                            settings.language = language
                        } label: {
                            HStack {
                                Text(language.icon)
                                    .font(.title3)
                                    .frame(width: 30)
                                
                                Text(language.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if settings.language == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primary)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L.gistLanguage)
                } footer: {
                    Text(L.gistLanguageDescription)
                }
                
                // Message Period Section
                Section {
                    ForEach(MessagePeriod.allCases, id: \.self) { period in
                        Button {
                            settings.messagePeriod = period
                        } label: {
                            HStack {
                                Image(systemName: period.icon)
                                    .foregroundColor(.primary)
                                    .frame(width: 30)
                                
                                Text(period.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if settings.messagePeriod == period {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primary)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L.messageCountPeriod)
                } footer: {
                    Text(L.messageCountPeriodDescription)
                }
                
                // About Section
                Section {
                    HStack {
                        Text(L.version)
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(L.app)
                        Spacer()
                        Text("Gisty")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(L.about)
                }
            }
            .navigationTitle(L.settings)
        }
    }
}

#Preview {
    SettingsView()
}
