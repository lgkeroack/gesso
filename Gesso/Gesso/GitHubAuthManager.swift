//
//  GitHubAuthManager.swift
//  Gesso
//
//  Handles the GitHub App user-to-server OAuth flow entirely on-device using
//  PKCE, so no client secret or backend is required. Whatever sign-in method
//  the user picks on GitHub's own login page (including a linked Google
//  account) happens inside that standard web flow.
//

import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class GitHubAuthManager: NSObject, ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    private static let clientID = "Iv23lisdj7ny7oNODarj"
    private static let redirectURI = "gesso://oauth/github/callback"
    private static let callbackScheme = "gesso"
    private static let authorizeURL = "https://github.com/login/oauth/authorize"
    private static let tokenURL = "https://github.com/login/oauth/access_token"
    private static let accessTokenKey = "github.accessToken"
    private static let refreshTokenKey = "github.refreshToken"

    private var codeVerifier: String?
    private var pendingState: String?
    private var authSession: ASWebAuthenticationSession?

    override init() {
        isConnected = KeychainStore.read(for: Self.accessTokenKey) != nil
        super.init()
    }

    var accessToken: String? {
        KeychainStore.read(for: Self.accessTokenKey)
    }

    func connect() {
        errorMessage = nil

        let verifier = PKCE.generateCodeVerifier()
        let challenge = PKCE.codeChallenge(for: verifier)
        let state = UUID().uuidString
        codeVerifier = verifier
        pendingState = state

        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            errorMessage = "Could not build GitHub authorization URL."
            return
        }

        isAuthenticating = true
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: Self.callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.handleCallback(url: callbackURL, error: error)
            }
        }
        session.presentationContextProvider = self
        authSession = session
        session.start()
    }

    /// Safety net in case the system routes the redirect through onOpenURL
    /// instead of the ASWebAuthenticationSession completion handler.
    func handleRedirect(url: URL) {
        handleCallback(url: url, error: nil)
    }

    func disconnect() {
        KeychainStore.delete(for: Self.accessTokenKey)
        KeychainStore.delete(for: Self.refreshTokenKey)
        isConnected = false
    }

    private func handleCallback(url: URL?, error: Error?) {
        isAuthenticating = false

        if let authError = error as? ASWebAuthenticationSessionError,
           authError.code == .canceledLogin {
            return
        }
        if let error {
            errorMessage = error.localizedDescription
            return
        }
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == pendingState else {
            errorMessage = "GitHub sign-in did not return a valid authorization code."
            return
        }

        Task {
            await exchangeCodeForToken(code: code)
        }
    }

    private func exchangeCodeForToken(code: String) async {
        guard let verifier = codeVerifier else { return }

        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                errorMessage = "GitHub token exchange failed."
                return
            }
            let decoded = try JSONDecoder().decode(GitHubTokenResponse.self, from: data)
            if let error = decoded.error {
                errorMessage = decoded.errorDescription ?? error
                return
            }
            guard let token = decoded.accessToken else {
                errorMessage = "GitHub did not return an access token."
                return
            }
            KeychainStore.save(token, for: Self.accessTokenKey)
            if let refreshToken = decoded.refreshToken {
                KeychainStore.save(refreshToken, for: Self.refreshTokenKey)
            }
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension GitHubAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

private struct GitHubTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case error
        case errorDescription = "error_description"
    }
}
