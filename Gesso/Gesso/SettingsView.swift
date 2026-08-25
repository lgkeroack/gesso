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

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if githubAuth.userCode != nil {
                        GitHubDeviceCodeView(githubAuth: githubAuth)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else {
                        connectionRow(isConnected: githubAuth.isConnected)
                        if let error = githubAuth.errorMessage {
                            Text(error).font(.caption).foregroundColor(BaroqueTheme.burgundy)
                        }
                        if githubAuth.isConnected {
                            Button("Disconnect", role: .destructive) {
                                githubAuth.disconnect()
                                repoStore.clear()
                            }
                            .buttonStyle(.ornate(BaroqueTheme.burgundy))
                        } else {
                            Button("Connect") { githubAuth.connect() }
                                .buttonStyle(.ornate(BaroqueTheme.sapphire))
                        }
                    }
                } header: {
                    Text("GitHub").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
                }
                .listRowBackground(BaroqueTheme.cream)

                Section {
                    connectionRow(isConnected: claudeAuth.isConnected)
                    if let error = claudeAuth.errorMessage {
                        Text(error).font(.caption).foregroundColor(BaroqueTheme.burgundy)
                    }
                    if claudeAuth.isConnected {
                        Button("Disconnect", role: .destructive) { claudeAuth.disconnect() }
                            .buttonStyle(.ornate(BaroqueTheme.burgundy))
                    } else {
                        Button("Connect") { showingAPIKeySheet = true }
                            .buttonStyle(.ornate(BaroqueTheme.sapphire))
                    }
                } header: {
                    Text("Claude").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
                }
                .listRowBackground(BaroqueTheme.cream)

                Section {
                    connectionRow(isConnected: geminiAuth.isConnected)
                    if let error = geminiAuth.errorMessage {
                        Text(error).font(.caption).foregroundColor(BaroqueTheme.burgundy)
                    }
                    if geminiAuth.isConnected {
                        Button("Disconnect", role: .destructive) { geminiAuth.disconnect() }
                            .buttonStyle(.ornate(BaroqueTheme.burgundy))
                    } else {
                        Button("Connect") { showingGeminiKeySheet = true }
                            .buttonStyle(.ornate(BaroqueTheme.sapphire))
                    }
                } header: {
                    Text("Gemini").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
                } footer: {
                    Text("Google's Gemini API has a free tier -- an alternative to Claude for the same read/edit/commit agent.")
                }
                .listRowBackground(BaroqueTheme.cream)

                if claudeAuth.isConnected && geminiAuth.isConnected {
                    Section {
                        Picker("Active AI Provider", selection: $providerStore.preferred) {
                            Text("Claude").tag(AIProvider.claude)
                            Text("Gemini").tag(AIProvider.gemini)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("AI Provider").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
                    } footer: {
                        Text("Both are connected -- pick which one Gesso sends your annotations to.")
                    }
                    .listRowBackground(BaroqueTheme.cream)
                }

                if githubAuth.isConnected {
                    Section {
                        connectionRow(isConnected: vercelAuth.isConnected)
                        if let error = vercelAuth.errorMessage {
                            Text(error).font(.caption).foregroundColor(BaroqueTheme.burgundy)
                        }
                        if vercelAuth.isConnected {
                            Button("Disconnect", role: .destructive) { vercelAuth.disconnect() }
                                .buttonStyle(.ornate(BaroqueTheme.burgundy))
                        } else {
                            Button("Connect") { showingVercelTokenSheet = true }
                                .buttonStyle(.ornate(BaroqueTheme.sapphire))
                        }
                    } header: {
                        Text("Vercel (optional)").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
                    } footer: {
                        Text("Lets Gesso find your linked Vercel project's live deployment URL for the current repo.")
                    }
                    .listRowBackground(BaroqueTheme.cream)
                }

                Section {
                    if let repo = repoStore.selectedRepo {
                        Text(repo.fullName).foregroundColor(BaroqueTheme.ink)
                    } else {
                        Text("None selected").foregroundColor(BaroqueTheme.ink.opacity(0.5))
                    }
                    Button("Change Repository") {
                        repoStore.clear()
                        dismiss()
                    }
                    .buttonStyle(.ornate(BaroqueTheme.amethyst))
                    .disabled(!githubAuth.isConnected)
                } header: {
                    Text("Repository").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
                }
                .listRowBackground(BaroqueTheme.cream)
            }
            .scrollContentBackground(.hidden)
            .background(BaroqueTheme.backgroundGradient.ignoresSafeArea())
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
    }

    private func connectionRow(isConnected: Bool) -> some View {
        HStack {
            Text(isConnected ? "Connected" : "Not connected")
                .foregroundColor(BaroqueTheme.ink)
            Spacer()
            Image(systemName: isConnected ? "checkmark.seal.fill" : "xmark.circle")
                .foregroundColor(isConnected ? BaroqueTheme.emerald : BaroqueTheme.ink.opacity(0.4))
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
