//
//  RepoPickerView.swift
//  Gesso
//
//  Lists repositories the Gesso GitHub App can access and lets the user
//  pick one to work on.
//

import SwiftUI

struct RepoPickerView: View {
    @ObservedObject var githubAuth: GitHubAuthManager
    @ObservedObject var repoStore: RepoSelectionStore

    @State private var repos: [GitHubRepository] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filteredRepos: [GitHubRepository] {
        guard !searchText.isEmpty else { return repos }
        return repos.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading repositories…")
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundColor(AppTheme.danger)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") { Task { await loadRepos() } }
                            .buttonStyle(.flat(AppTheme.accent))
                    }
                } else if repos.isEmpty {
                    Text("No repositories found. Make sure the Gesso GitHub App has access to at least one repository.")
                        .foregroundColor(AppTheme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(filteredRepos) { repo in
                        Button {
                            repoStore.select(repo)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(repo.fullName).font(.sectionHeadline)
                                Text(repo.isPrivate ? "Private" : "Public")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.ink.opacity(0.5))
                            }
                        }
                        .foregroundColor(AppTheme.ink)
                        .listRowBackground(AppTheme.surface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                    .searchable(text: $searchText, prompt: "Search repositories")
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Pick a Repository")
        }
        .task {
            await loadRepos()
        }
    }

    private func loadRepos() async {
        guard let token = githubAuth.accessToken else {
            errorMessage = "Not connected to GitHub."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            repos = try await GitHubReposService.fetchAccessibleRepositories(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RepoPickerView(githubAuth: GitHubAuthManager(), repoStore: RepoSelectionStore())
}
