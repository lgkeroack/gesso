//
//  GitHubReposService.swift
//  Gesso
//
//  Lists repositories the Gesso GitHub App installation can access for the
//  signed-in user, via GitHub's user-to-server REST API. No backend involved
//  -- these calls go straight from the device to api.github.com using the
//  OAuth token obtained by GitHubAuthManager.
//

import Foundation

enum GitHubReposServiceError: LocalizedError {
    case noInstallationFound
    case requestFailed(endpoint: String, code: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .noInstallationFound:
            return "No installation of the Gesso GitHub App was found on your account. Install it from GitHub settings first."
        case .requestFailed(let endpoint, let code, let message):
            let detail = message.map { ": \($0)" } ?? ""
            return "GitHub request failed fetching \(endpoint) (HTTP \(code))\(detail)."
        }
    }
}

enum GitHubReposService {
    private static let apiBase = "https://api.github.com"

    private struct Installation: Decodable {
        let id: Int
    }
    private struct InstallationsResponse: Decodable {
        let installations: [Installation]
    }
    private struct RepositoriesResponse: Decodable {
        let repositories: [GitHubRepository]
    }

    static func fetchAccessibleRepositories(token: String) async throws -> [GitHubRepository] {
        let installations = try await fetchInstallations(token: token)
        guard let installationID = installations.first?.id else {
            throw GitHubReposServiceError.noInstallationFound
        }

        var allRepos: [GitHubRepository] = []
        var page = 1
        while true {
            let pageRepos = try await fetchRepositoriesPage(installationID: installationID, token: token, page: page)
            allRepos.append(contentsOf: pageRepos)
            if pageRepos.count < 100 { break }
            page += 1
        }
        return allRepos
    }

    private static func fetchInstallations(token: String) async throws -> [Installation] {
        let url = URL(string: "\(apiBase)/user/installations")!
        let (data, response) = try await authorizedRequest(url: url, token: token)
        try validate(response, data: data, endpoint: "installations")
        return try JSONDecoder().decode(InstallationsResponse.self, from: data).installations
    }

    private static func fetchRepositoriesPage(installationID: Int, token: String, page: Int) async throws -> [GitHubRepository] {
        var components = URLComponents(string: "\(apiBase)/user/installations/\(installationID)/repositories")!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        let (data, response) = try await authorizedRequest(url: components.url!, token: token)
        try validate(response, data: data, endpoint: "repositories")
        return try JSONDecoder().decode(RepositoriesResponse.self, from: data).repositories
    }

    private static func authorizedRequest(url: URL, token: String) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Gesso-iOS", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request)
    }

    private static func validate(_ response: URLResponse, data: Data, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GitHubReposServiceError.requestFailed(endpoint: endpoint, code: code, message: decodeErrorMessage(from: data))
        }
    }

    private static func decodeErrorMessage(from data: Data) -> String? {
        struct Envelope: Decodable { let message: String }
        return try? JSONDecoder().decode(Envelope.self, from: data).message
    }
}
