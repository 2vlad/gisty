//
//  SettingsView.swift
//  gisty
//
//  User settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = UserSettings.shared
    @State private var openAIApiKey: String = ""
    @State private var showApiKeyInput = false
    @State private var saveMessage: String?
    @State private var showSaveMessage = false
    
    var body: some View {
        NavigationStack {
            List {
                // API Configuration Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenAI API Key")
                                .font(.body)
                            if ConfigurationManager.shared.hasValidOpenAICredentials {
                                Text("Configured ✓")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not configured")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            openAIApiKey = ConfigurationManager.shared.openAIApiKey ?? ""
                            showApiKeyInput = true
                        }) {
                            Text(ConfigurationManager.shared.hasValidOpenAICredentials ? "Update" : "Add")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("OpenAI API key is required for generating gist summaries. Get your key from platform.openai.com")
                }
                
                // Message Period Section
                Section {
                    ForEach(MessagePeriod.allCases, id: \.self) { period in
                        Button {
                            settings.messagePeriod = period
                        } label: {
                            HStack {
                                Image(systemName: period.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                Text(period.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if settings.messagePeriod == period {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Message Count Period")
                } footer: {
                    Text("Show unread message count for the selected time period on the source selection screen")
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Gisty")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showApiKeyInput) {
                apiKeyInputSheet
            }
            .alert("Success", isPresented: $showSaveMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = saveMessage {
                    Text(message)
                }
            }
        }
    }
    
    // MARK: - API Key Input Sheet
    
    private var apiKeyInputSheet: some View {
        NavigationView {
            Form {
                Section {
                    Text("Enter your OpenAI API key to enable gist generation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("API Key")) {
                    SecureField("sk-proj-...", text: $openAIApiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get your API key:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("1. Go to platform.openai.com")
                        Text("2. Sign up or log in")
                        Text("3. Navigate to API Keys section")
                        Text("4. Create a new secret key")
                        Text("5. Copy and paste it here")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("OpenAI API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showApiKeyInput = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveApiKey()
                    }
                    .disabled(openAIApiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func saveApiKey() {
        let trimmedKey = openAIApiKey.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedKey.isEmpty else { return }
        
        ConfigurationManager.shared.openAIApiKey = trimmedKey
        
        saveMessage = "OpenAI API key saved successfully"
        showSaveMessage = true
        showApiKeyInput = false
        
        print("✅ OpenAI API key saved")
    }
}

#Preview {
    SettingsView()
}
