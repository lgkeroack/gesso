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
    @StateObject private var repoStore = RepoSelectionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if !githubAuth.isConnected || !claudeAuth.isConnected {
                    ConnectView(githubAuth: githubAuth, claudeAuth: claudeAuth)
                } else if repoStore.selectedRepo == nil {
                    RepoPickerView(githubAuth: githubAuth, repoStore: repoStore)
                } else {
                    MainView(repoStore: repoStore, githubAuth: githubAuth, claudeAuth: claudeAuth)
                }
            }
            .onOpenURL { url in
                githubAuth.handleRedirect(url: url)
            }
            .tint(BaroqueTheme.gold)
        }
    }
}
