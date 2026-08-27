//
//  GitHubRepoFileService.swift
//  Gesso
//
//  Read/write access to files in the connected repository via GitHub's
//  Contents API, used as the backing implementation for Claude's tools.
//  Calls go straight from the device to api.github.com -- no backend.
//

import Foundation

struct GitHubFileEntry {
    let name: String
    let path: String
    let type: String // "file" or "dir"
}

enum GitHubRepoFileError: LocalizedError {
    case notFound
    case requestFailed(operation: String, path: String, code: Int, message: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notFound: return "File not found."
        case .requestFailed(let operation, let path, let code, let message):
            let detail = message.map { ": \($0)" } ?? ""
            return "GitHub \(operation) failed for \(path) (HTTP \(code))\(detail)."
        case .decodingFailed: return "Couldn't decode GitHub's response."
        }
    }
}

enum GitHubRepoFileService {
    static func listFiles(repo: GitHubRepository, token: String, path: String) async throws -> [GitHubFileEntry] {
        let (data, response) = try await request(url: contentsURL(repo: repo, path: path), token: token)
        try validate(response, data: data, operation: "listing files", path: path)

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { entry in
                guard let name = entry["name"] as? String,
                      let entryPath = entry["path"] as? String,
                      let type = entry["type"] as? String else { return nil }
                return GitHubFileEntry(name: name, path: entryPath, type: type)
            }
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = object["name"] as? String,
           let entryPath = object["path"] as? String,
           let type = object["type"] as? String {
            return [GitHubFileEntry(name: name, path: entryPath, type: type)]
        }
        throw GitHubRepoFileError.decodingFailed
    }

    static func readFile(repo: GitHubRepository, token: String, path: String) async throws -> String {
        let (data, response) = try await request(url: contentsURL(repo: repo, path: path), token: token)
        try validate(response, data: data, operation: "reading file", path: path)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64 = (object["content"] as? String)?.replacingOccurrences(of: "\n", with: ""),
              let decoded = Data(base64Encoded: base64),
              let text = String(data: decoded, encoding: .utf8) else {
            throw GitHubRepoFileError.decodingFailed
        }
        return text
    }

    @discardableResult
    static func writeFile(repo: GitHubRepository, token: String, path: String, content: String, commitMessage: String) async throws -> String {
        var existingSha: String?
        if let (data, response) = try? await request(url: contentsURL(repo: repo, path: path), token: token),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            existingSha = object["sha"] as? String
        }

        var body: [String: Any] = [
            "message": commitMessage,
            "content": Data(content.utf8).base64EncodedString(),
            "branch": repo.defaultBranch
        ]
        if let existingSha {
            body["sha"] = existingSha
        }

        var urlRequest = URLRequest(url: rawContentsURL(repo: repo, path: path))
        urlRequest.httpMethod = "PUT"
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        applyHeaders(to: &urlRequest, token: token)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response, data: data, operation: "writing file", path: path)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = object["commit"] as? [String: Any],
              let sha = commit["sha"] as? String else {
            throw GitHubRepoFileError.decodingFailed
        }
        return sha
    }

    private static func encodedPath(_ path: String) -> String {
        path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
    }

    private static func rawContentsURL(repo: GitHubRepository, path: String) -> URL {
        URL(string: "https://api.github.com/repos/\(repo.owner.login)/\(repo.name)/contents/\(encodedPath(path))")!
    }

    private static func contentsURL(repo: GitHubRepository, path: String) -> URL {
        var components = URLComponents(url: rawContentsURL(repo: repo, path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ref", value: repo.defaultBranch)]
        return components.url!
    }

    private static func request(url: URL, token: String) async throws -> (Data, URLResponse) {
        var urlRequest = URLRequest(url: url)
        applyHeaders(to: &urlRequest, token: token)
        return try await URLSession.shared.data(for: urlRequest)
    }

    private static func applyHeaders(to request: inout URLRequest, token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    }

    private static func validate(_ response: URLResponse, data: Data, operation: String, path: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitHubRepoFileError.requestFailed(operation: operation, path: path, code: -1, message: nil)
        }
        if http.statusCode == 404 { throw GitHubRepoFileError.notFound }
        guard (200...299).contains(http.statusCode) else {
            throw GitHubRepoFileError.requestFailed(
                operation: operation, path: path, code: http.statusCode, message: decodeErrorMessage(from: data)
            )
        }
    }

    private static func decodeErrorMessage(from data: Data) -> String? {
        struct Envelope: Decodable { let message: String }
        return try? JSONDecoder().decode(Envelope.self, from: data).message
    }
}
