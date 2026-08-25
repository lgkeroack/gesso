//
//  GeminiAuthManager.swift
//  Gesso
//
//  Stores the user's own Gemini API key in the Keychain. Validated with a
//  GET to the models list endpoint rather than a generateContent call, since
//  that's free even on Gemini's free tier (no tokens billed against quota).
//

import Foundation

@MainActor
final class GeminiAuthManager: ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published var isValidating = false
    @Published var errorMessage: String?

    private static let apiKeyKey = "gemini.apiKey"
    private static let modelsURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!

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

        var request = URLRequest(url: Self.modelsURL)
        request.setValue(trimmed, forHTTPHeaderField: "x-goog-api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No response from Gemini."
                return
            }
            if (200...299).contains(http.statusCode) {
                KeychainStore.save(trimmed, for: Self.apiKeyKey)
                isConnected = true
            } else {
                errorMessage = decodeErrorMessage(from: data) ?? "Gemini rejected this API key (HTTP \(http.statusCode))."
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
