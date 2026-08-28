//
//  VercelDeploymentService.swift
//  Gesso
//
//  Looks up the Vercel project linked to the selected GitHub repo and every
//  production-scoped URL associated with it -- its configured custom
//  domains plus the latest production deployment's aliases -- so the user
//  can pick a known-public one themselves rather than the app guessing and
//  possibly landing on a Vercel-Authentication-gated preview URL.
//
//  Field names (projects: id, name; project domains: name, verified;
//  deployments: url, alias, readyState, target, created; query params
//  repoUrl, projectId, branch, production) are taken directly from
//  Vercel's REST API reference (GET /v10/projects, GET /v9/projects/{id}/domains,
//  GET /v7/deployments).
//

import Foundation

struct VercelProject {
    let id: String
    let name: String
}

enum VercelDeploymentError: LocalizedError {
    case noProjectFound
    case noURLsFound
    case requestFailed(endpoint: String, code: Int, message: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noProjectFound:
            return "No Vercel project is linked to this repository. Link it in the Vercel dashboard first."
        case .noURLsFound:
            return "This Vercel project has no production URLs yet."
        case .requestFailed(let endpoint, let code, let message):
            let detail = message.map { ": \($0)" } ?? ""
            return "Vercel request failed fetching \(endpoint) (HTTP \(code))\(detail)."
        case .decodingFailed:
            return "Couldn't understand Vercel's response."
        }
    }
}

enum VercelDeploymentService {
    private static let apiBase = "https://api.vercel.com"

    static func findProject(forRepo repo: GitHubRepository, token: String) async throws -> VercelProject {
        var components = URLComponents(string: "\(apiBase)/v10/projects")!
        components.queryItems = [
            URLQueryItem(name: "repoUrl", value: repo.htmlURL),
            URLQueryItem(name: "limit", value: "5")
        ]

        let (data, response) = try await authorizedRequest(url: components.url!, token: token)
        try validate(response, data: data, endpoint: "projects")

        let parsed = try JSONSerialization.jsonObject(with: data)
        let projects: [Any]
        if let array = parsed as? [Any] {
            projects = array
        } else if let object = parsed as? [String: Any], let array = object["projects"] as? [Any] {
            projects = array
        } else {
            throw VercelDeploymentError.decodingFailed
        }

        guard let first = projects.first as? [String: Any],
              let id = first["id"] as? String,
              let name = first["name"] as? String else {
            throw VercelDeploymentError.noProjectFound
        }
        return VercelProject(id: id, name: name)
    }

    /// All production-scoped URLs for the project: its configured custom
    /// domains (including the default `<name>.vercel.app`) plus the latest
    /// ready production deployment's aliases, deduplicated and sorted.
    static func listURLs(project: VercelProject, token: String) async throws -> [URL] {
        async let domainHosts = fetchProjectDomains(project: project, token: token)
        async let aliasHosts = fetchLatestProductionAliases(project: project, token: token)

        var hosts = try await Set(domainHosts)
        hosts.formUnion(try await aliasHosts)

        guard !hosts.isEmpty else { throw VercelDeploymentError.noURLsFound }
        return hosts.sorted().compactMap { URL(string: "https://\($0)") }
    }

    private static func fetchProjectDomains(project: VercelProject, token: String) async throws -> [String] {
        var components = URLComponents(string: "\(apiBase)/v9/projects/\(project.id)/domains")!
        components.queryItems = [URLQueryItem(name: "production", value: "true")]

        let (data, response) = try await authorizedRequest(url: components.url!, token: token)
        try validate(response, data: data, endpoint: "project domains")

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let domains = object["domains"] as? [[String: Any]] else {
            throw VercelDeploymentError.decodingFailed
        }
        return domains.compactMap { $0["name"] as? String }
    }

    private static func fetchLatestProductionAliases(project: VercelProject, token: String) async throws -> [String] {
        var components = URLComponents(string: "\(apiBase)/v7/deployments")!
        components.queryItems = [
            URLQueryItem(name: "projectId", value: project.id),
            URLQueryItem(name: "target", value: "production"),
            URLQueryItem(name: "limit", value: "1")
        ]

        let (data, response) = try await authorizedRequest(url: components.url!, token: token)
        try validate(response, data: data, endpoint: "deployments")

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deployments = object["deployments"] as? [[String: Any]] else {
            throw VercelDeploymentError.decodingFailed
        }
        guard let deployment = deployments.first(where: { ($0["readyState"] as? String) == "READY" }) else {
            return []
        }

        if let alias = deployment["alias"] as? [String], !alias.isEmpty {
            return alias
        }
        if let url = deployment["url"] as? String {
            return [url]
        }
        return []
    }

    private static func authorizedRequest(url: URL, token: String) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await URLSession.shared.data(for: request)
    }

    private static func validate(_ response: URLResponse, data: Data, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw VercelDeploymentError.requestFailed(endpoint: endpoint, code: code, message: decodeErrorMessage(from: data))
        }
    }

    private static func decodeErrorMessage(from data: Data) -> String? {
        struct Envelope: Decodable {
            struct ErrorDetail: Decodable { let message: String }
            let error: ErrorDetail
        }
        return try? JSONDecoder().decode(Envelope.self, from: data).error.message
    }
}
