//
//  GitHubAuthManager.swift
//  Gesso
//
//  Handles GitHub's OAuth Device Flow entirely on-device -- unlike the
//  web-based authorize flow, GitHub's device flow token exchange only ever
//  requires client_id, never a client secret, so this needs no backend.
//  The tradeoff is UX: the user has to type a short code at
//  github.com/login/device rather than tapping through a one-tap web sheet.
//

import Foundation
import UIKit

enum GitHubAuthError: LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message): return message
        }
    }
}

@MainActor
final class GitHubAuthManager: ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published var isAuthenticating = false
    @Published private(set) var isVerifying = false
    @Published var errorMessage: String?

    /// Shown to the user while they authorize on github.com/login/device.
    @Published private(set) var userCode: String?
    @Published private(set) var verificationURI: String?

    private static let clientID = "Iv23lisdj7ny7oNODarj"
    private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private static let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    private static let accessTokenKey = "github.accessToken"

    private var pollingTask: Task<Void, Never>?

    init() {
        isConnected = KeychainStore.read(for: Self.accessTokenKey) != nil
    }

    var accessToken: String? {
        KeychainStore.read(for: Self.accessTokenKey)
    }

    func connect() {
        errorMessage = nil
        userCode = nil
        verificationURI = nil
        isAuthenticating = true

        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            await self?.runDeviceFlow()
        }
    }

    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        isAuthenticating = false
        userCode = nil
        verificationURI = nil
    }

    func openVerificationURL() {
        guard let verificationURI, let url = URL(string: verificationURI) else { return }
        UIApplication.shared.open(url)
    }

    func disconnect() {
        KeychainStore.delete(for: Self.accessTokenKey)
        isConnected = false
    }

    /// Re-checks a stored token against GitHub as soon as there's something
    /// to check, instead of waiting for the user to notice via a failed repo
    /// list. Disconnects immediately if GitHub rejects it, so "Connected"
    /// never lags behind reality.
    func verifyConnection() async {
        guard isConnected, let token = accessToken else { return }
        isVerifying = true
        defer { isVerifying = false }
        do {
            try await GitHubReposService.verifyUser(token: token)
        } catch {
            disconnect()
        }
    }

    private func runDeviceFlow() async {
        do {
            let deviceCode = try await requestDeviceCode()
            userCode = deviceCode.userCode
            verificationURI = deviceCode.verificationUri

            let token = try await pollForToken(
                deviceCode: deviceCode.deviceCode,
                initialInterval: deviceCode.interval,
                expiresIn: deviceCode.expiresIn
            )
            // GitHub handing back a token doesn't guarantee it actually
            // authenticates -- confirm it works before reporting success,
            // so "Connected" never lies about a token GitHub will reject.
            try await GitHubReposService.verifyUser(token: token)
            KeychainStore.save(token, for: Self.accessTokenKey)
            isConnected = true
        } catch is CancellationError {
            // Cancelled via cancel(); state already cleared there.
        } catch {
            errorMessage = error.localizedDescription
        }
        isAuthenticating = false
        userCode = nil
        verificationURI = nil
    }

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: Self.deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "client_id", value: Self.clientID)]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let message = (try? JSONDecoder().decode(DeviceTokenResponse.self, from: data))?.errorDescription
            let detail = message.map { ": \($0)" } ?? "."
            throw GitHubAuthError.requestFailed("Couldn't start GitHub device authorization (HTTP \(code))\(detail)")
        }
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForToken(deviceCode: String, initialInterval: Int, expiresIn: Int) async throws -> String {
        var pollInterval = max(initialInterval, 1)
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))

        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            try Task.checkCancellation()

            var request = URLRequest(url: Self.tokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "client_id", value: Self.clientID),
                URLQueryItem(name: "device_code", value: deviceCode),
                URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code")
            ]
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(DeviceTokenResponse.self, from: data)

            if let accessToken = tokenResponse.accessToken {
                return accessToken
            }

            switch tokenResponse.error {
            case "authorization_pending":
                continue
            case "slow_down":
                pollInterval += 5
                continue
            case "expired_token":
                throw GitHubAuthError.requestFailed("The code expired before authorization completed. Try again.")
            case "access_denied":
                throw GitHubAuthError.requestFailed("Authorization was denied.")
            default:
                throw GitHubAuthError.requestFailed(tokenResponse.errorDescription ?? "GitHub authorization failed.")
            }
        }
        throw GitHubAuthError.requestFailed("The code expired before authorization completed. Try again.")
    }
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

private struct DeviceTokenResponse: Decodable {
    let accessToken: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
        case errorDescription = "error_description"
    }
}
