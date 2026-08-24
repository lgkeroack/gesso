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
    @ObservedObject var repoStore: RepoSelectionStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingAPIKeySheet = false

    var body: some View {
        NavigationView {
            Form {
                Section {
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
    SettingsView(githubAuth: GitHubAuthManager(), claudeAuth: ClaudeAuthManager(), repoStore: RepoSelectionStore())
}
