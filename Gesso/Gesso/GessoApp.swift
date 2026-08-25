//
//  GessoApp.swift
//  Gesso
//
//  An app which lets you visually annotate and respond to UI changes in real time
//

import SwiftUI

@main
struct GessoApp: App {
    @StateObject private var githubAuth = GitHubAuthManager()
    @StateObject private var claudeAuth = ClaudeAuthManager()
    @StateObject private var geminiAuth = GeminiAuthManager()
    @StateObject private var vercelAuth = VercelAuthManager()
    @StateObject private var providerStore = AIProviderStore()
    @StateObject private var repoStore = RepoSelectionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if !githubAuth.isConnected || !(claudeAuth.isConnected || geminiAuth.isConnected) {
                    ConnectView(githubAuth: githubAuth, claudeAuth: claudeAuth, geminiAuth: geminiAuth, vercelAuth: vercelAuth)
                } else if repoStore.selectedRepo == nil {
                    RepoPickerView(githubAuth: githubAuth, repoStore: repoStore)
                } else {
                    MainView(
                        repoStore: repoStore,
                        githubAuth: githubAuth,
                        claudeAuth: claudeAuth,
                        geminiAuth: geminiAuth,
                        vercelAuth: vercelAuth,
                        providerStore: providerStore
                    )
                }
            }
            .tint(AppTheme.accent)
        }
    }
}
