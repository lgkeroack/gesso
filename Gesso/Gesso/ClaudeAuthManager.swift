//
//  ClaudeAuthManager.swift
//  Gesso
//
//  Stores the user's own Anthropic API key in the Keychain and validates it
//  with a live, minimal call before marking the connection as established.
//  There's no third-party OAuth for claude.ai accounts, so an API key
//  (generated at console.anthropic.com) is the supported way for a
//  third-party app to call Claude on the user's behalf.
//

import Foundation

@MainActor
final class ClaudeAuthManager: ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published var isValidating = false
    @Published var errorMessage: String?

    private static let apiKeyKey = "anthropic.apiKey"
    private static let messagesURL = "https://api.anthropic.com/v1/messages"
    private static let apiVersion = "2023-06-01"
    /// Cheapest current model, used only to validate the key with a 1-token ping.
    private static let validationModel = "claude-haiku-4-5-20251001"

    init() {
        isConnected = KeychainStore.read(for: Self.apiKeyKey) != nil
    }

    var apiKey: String? {
        KeychainStore.read(for: Self.apiKeyKey)
    }

    func connect(apiKey: String) async {
        errorMessage = nil
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter an API key."
            return
        }

        isValidating = true
        defer { isValidating = false }

        var request = URLRequest(url: URL(string: Self.messagesURL)!)
        request.httpMethod = "POST"
        request.setValue(trimmed, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": Self.validationModel,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ping"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No response from Anthropic."
                return
            }
            if (200...299).contains(http.statusCode) {
                KeychainStore.save(trimmed, for: Self.apiKeyKey)
                isConnected = true
            } else {
                errorMessage = decodeErrorMessage(from: data) ?? "Anthropic rejected this API key (HTTP \(http.statusCode))."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        KeychainStore.delete(for: Self.apiKeyKey)
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
