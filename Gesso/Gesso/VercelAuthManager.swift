//
//  VercelAuthManager.swift
//  Gesso
//
//  Optional Vercel connection using a pasted Personal Access Token (created
//  at vercel.com/account/tokens) -- Vercel has no secretless OAuth flow
//  analogous to GitHub's device flow, so a manually-generated token is the
//  no-backend-safe option, same pattern as the Claude API key.
//

import Foundation

@MainActor
final class VercelAuthManager: ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published var isValidating = false
    @Published var errorMessage: String?

    private static let tokenKey = "vercel.accessToken"
    private static let userURL = URL(string: "https://api.vercel.com/v2/user")!

    init() {
        isConnected = KeychainStore.read(for: Self.tokenKey) != nil
    }

    var accessToken: String? {
        KeychainStore.read(for: Self.tokenKey)
    }

    func connect(token: String) async {
        errorMessage = nil
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a token."
            return
        }

        isValidating = true
        defer { isValidating = false }

        var request = URLRequest(url: Self.userURL)
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No response from Vercel."
                return
            }
            if (200...299).contains(http.statusCode) {
                KeychainStore.save(trimmed, for: Self.tokenKey)
                isConnected = true
            } else {
                errorMessage = decodeErrorMessage(from: data) ?? "Vercel rejected this token (HTTP \(http.statusCode))."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        KeychainStore.delete(for: Self.tokenKey)
        isConnected = false
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        struct Envelope: Decodable {
            struct ErrorDetail: Decodable { let message: String }
            let error: ErrorDetail
        }
        return try? JSONDecoder().decode(Envelope.self, from: data).error.message
    }
}
