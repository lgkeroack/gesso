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

    /// Requires confirming the connect screen once per launch, even if
    /// everything's already connected -- resets to false on every cold start
    /// since it's plain @State, so a fresh launch always shows it again.
    @State private var hasConfirmedSession = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasConfirmedSession || !githubAuth.isConnected || !(claudeAuth.isConnected || geminiAuth.isConnected) || repoStore.selectedRepo == nil {
                    ConnectView(
                        githubAuth: githubAuth,
                        claudeAuth: claudeAuth,
                        geminiAuth: geminiAuth,
                        vercelAuth: vercelAuth,
                        repoStore: repoStore,
                        onContinue: { hasConfirmedSession = true }
                    )
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
