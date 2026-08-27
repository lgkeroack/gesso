//
//  VercelDeploymentService.swift
//  Gesso
//
//  Looks up the Vercel project linked to the selected GitHub repo and its
//  latest ready deployment for that repo's default branch, so Gesso can
//  offer the live dev/preview URL instead of the user typing one by hand.
//
//  Field names (projects: id, name; deployments: url, readyState, target,
//  created; query params repoUrl, projectId, branch) are taken directly
//  from Vercel's REST API reference (GET /v10/projects, GET /v7/deployments).
//

import Foundation

struct VercelProject {
    let id: String
    let name: String
}

enum VercelDeploymentError: LocalizedError {
    case noProjectFound
    case noReadyDeployment
    case requestFailed(endpoint: String, code: Int, message: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noProjectFound:
            return "No Vercel project is linked to this repository. Link it in the Vercel dashboard first."
        case .noReadyDeployment:
            return "This Vercel project has no ready deployment for this branch yet."
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

    static func latestDeploymentURL(project: VercelProject, branch: String, token: String) async throws -> URL {
        var components = URLComponents(string: "\(apiBase)/v7/deployments")!
        components.queryItems = [
            URLQueryItem(name: "projectId", value: project.id),
            URLQueryItem(name: "branch", value: branch),
            URLQueryItem(name: "target", value: "production"),
            URLQueryItem(name: "limit", value: "10")
        ]

        let (data, response) = try await authorizedRequest(url: components.url!, token: token)
        try validate(response, data: data, endpoint: "deployments")

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deployments = object["deployments"] as? [[String: Any]] else {
            throw VercelDeploymentError.decodingFailed
        }

        let ready = deployments
            .filter { ($0["readyState"] as? String) == "READY" }
            .sorted { (($0["created"] as? Double) ?? 0) > (($1["created"] as? Double) ?? 0) }

        guard let latest = ready.first, let host = publicHost(for: latest) else {
            throw VercelDeploymentError.noReadyDeployment
        }
        guard let url = URL(string: "https://\(host)") else {
            throw VercelDeploymentError.decodingFailed
        }
        return url
    }

    /// Prefers a deployment's stable public alias (the project's assigned
    /// domain, or a custom domain) over its own ephemeral url -- the alias
    /// is what's actually meant to be public-facing; the per-deployment url
    /// can differ deploy to deploy and isn't guaranteed to be the canonical
    /// address people would visit.
    private static func publicHost(for deployment: [String: Any]) -> String? {
        if let aliases = deployment["alias"] as? [String], let first = aliases.first {
            return first
        }
        return deployment["url"] as? String
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
