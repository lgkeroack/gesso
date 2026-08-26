//
//  SettingsView.swift
//  Gesso
//
//  Connection management: see what's connected, relink or disconnect
//  GitHub/Claude, and change the selected repository. General app
//  preferences will be built later.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var githubAuth: GitHubAuthManager
    @ObservedObject var claudeAuth: ClaudeAuthManager
    @ObservedObject var geminiAuth: GeminiAuthManager
    @ObservedObject var vercelAuth: VercelAuthManager
    @ObservedObject var providerStore: AIProviderStore
    @ObservedObject var repoStore: RepoSelectionStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingAPIKeySheet = false
    @State private var showingGeminiKeySheet = false
    @State private var showingVercelTokenSheet = false
    @State private var showingRepoPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if githubAuth.userCode != nil {
                        GitHubDeviceCodeView(githubAuth: githubAuth)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else {
                        connectionRow(isConnected: githubAuth.isConnected)
                        if let error = githubAuth.errorMessage {
                            Text(error).font(.caption).foregroundColor(AppTheme.danger)
                        }
                        if githubAuth.isConnected {
                            Button("Disconnect", role: .destructive) {
                                githubAuth.disconnect()
                                repoStore.clear()
                            }
                            .buttonStyle(.flat(AppTheme.danger))
                        } else {
                            Button("Connect") { githubAuth.connect() }
                                .buttonStyle(.flat(AppTheme.accent))
                        }
                    }
                } header: {
                    Text("GitHub").font(.sectionHeadline).foregroundColor(AppTheme.ink)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    connectionRow(isConnected: claudeAuth.isConnected)
                    if let error = claudeAuth.errorMessage {
                        Text(error).font(.caption).foregroundColor(AppTheme.danger)
                    }
                    if claudeAuth.isConnected {
                        Button("Disconnect", role: .destructive) { claudeAuth.disconnect() }
                            .buttonStyle(.flat(AppTheme.danger))
                    } else {
                        Button("Connect") { showingAPIKeySheet = true }
                            .buttonStyle(.flat(AppTheme.accent))
                    }
                } header: {
                    Text("Claude").font(.sectionHeadline).foregroundColor(AppTheme.ink)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    connectionRow(isConnected: geminiAuth.isConnected)
                    if let error = geminiAuth.errorMessage {
                        Text(error).font(.caption).foregroundColor(AppTheme.danger)
                    }
                    if geminiAuth.isConnected {
                        Button("Disconnect", role: .destructive) { geminiAuth.disconnect() }
                            .buttonStyle(.flat(AppTheme.danger))
                    } else {
                        Button("Connect") { showingGeminiKeySheet = true }
                            .buttonStyle(.flat(AppTheme.accent))
                    }
                } header: {
                    Text("Gemini").font(.sectionHeadline).foregroundColor(AppTheme.ink)
                } footer: {
                    Text("Google's Gemini API has a free tier -- an alternative to Claude for the same read/edit/commit agent.")
                }
                .listRowBackground(AppTheme.surface)

                if claudeAuth.isConnected && geminiAuth.isConnected {
                    Section {
                        Picker("Active AI Provider", selection: $providerStore.preferred) {
                            Text("Claude").tag(AIProvider.claude)
                            Text("Gemini").tag(AIProvider.gemini)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("AI Provider").font(.sectionHeadline).foregroundColor(AppTheme.ink)
                    } footer: {
                        Text("Both are connected -- pick which one Gesso sends your annotations to.")
                    }
                    .listRowBackground(AppTheme.surface)
                }

                if githubAuth.isConnected {
                    Section {
                        connectionRow(isConnected: vercelAuth.isConnected)
                        if let error = vercelAuth.errorMessage {
                            Text(error).font(.caption).foregroundColor(AppTheme.danger)
                        }
                        if vercelAuth.isConnected {
                            Button("Disconnect", role: .destructive) { vercelAuth.disconnect() }
                                .buttonStyle(.flat(AppTheme.danger))
                        } else {
                            Button("Connect") { showingVercelTokenSheet = true }
                                .buttonStyle(.flat(AppTheme.accent))
                        }
                    } header: {
                        Text("Vercel (optional)").font(.sectionHeadline).foregroundColor(AppTheme.ink)
                    } footer: {
                        Text("Lets Gesso find your linked Vercel project's live deployment URL for the current repo.")
                    }
                    .listRowBackground(AppTheme.surface)
                }

                Section {
                    if let repo = repoStore.selectedRepo {
                        Text(repo.fullName).foregroundColor(AppTheme.ink)
                    } else {
                        Text("None selected").foregroundColor(AppTheme.ink.opacity(0.5))
                    }
                    Button("Change Repository") {
                        showingRepoPicker = true
                    }
                    .buttonStyle(.flat(AppTheme.accent))
                    .disabled(!githubAuth.isConnected)
                } header: {
                    Text("Repository").font(.sectionHeadline).foregroundColor(AppTheme.ink)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            ClaudeAPIKeySheet(claudeAuth: claudeAuth, isPresented: $showingAPIKeySheet)
        }
        .sheet(isPresented: $showingGeminiKeySheet) {
            GeminiAPIKeySheet(geminiAuth: geminiAuth, isPresented: $showingGeminiKeySheet)
        }
        .sheet(isPresented: $showingVercelTokenSheet) {
            VercelAPIKeySheet(vercelAuth: vercelAuth, isPresented: $showingVercelTokenSheet)
        }
        .sheet(isPresented: $showingRepoPicker) {
            RepoPickerView(githubAuth: githubAuth, repoStore: repoStore, isPresented: $showingRepoPicker)
        }
    }

    private func connectionRow(isConnected: Bool) -> some View {
        HStack {
            Text(isConnected ? "Connected" : "Not connected")
                .foregroundColor(AppTheme.ink)
            Spacer()
            Image(systemName: isConnected ? "checkmark.seal.fill" : "xmark.circle")
                .foregroundColor(isConnected ? AppTheme.success : AppTheme.ink.opacity(0.4))
        }
    }
}

#Preview {
    SettingsView(
        githubAuth: GitHubAuthManager(),
        claudeAuth: ClaudeAuthManager(),
        geminiAuth: GeminiAuthManager(),
        vercelAuth: VercelAuthManager(),
        providerStore: AIProviderStore(),
        repoStore: RepoSelectionStore()
    )
}
