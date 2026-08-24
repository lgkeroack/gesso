//
//  RepoSelectionStore.swift
//  Gesso
//
//  Holds the repository the user picked to work on, persisted locally.
//

import Foundation

@MainActor
final class RepoSelectionStore: ObservableObject {
    @Published private(set) var selectedRepo: GitHubRepository?

    private static let storageKey = "selectedRepository"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let repo = try? JSONDecoder().decode(GitHubRepository.self, from: data) {
            selectedRepo = repo
        }
    }

    func select(_ repo: GitHubRepository) {
        selectedRepo = repo
        if let data = try? JSONEncoder().encode(repo) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func clear() {
        selectedRepo = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
