//
//  ConnectView.swift
//  Gesso
//
//  Launch-time screen that requires GitHub plus at least one AI provider
//  (Claude or Gemini) to be connected before the rest of the app is
//  reachable. Vercel is shown too, but stays optional.
//

import SwiftUI

struct ConnectView: View {
    @ObservedObject var githubAuth: GitHubAuthManager
    @ObservedObject var claudeAuth: ClaudeAuthManager
    @ObservedObject var geminiAuth: GeminiAuthManager
    @ObservedObject var vercelAuth: VercelAuthManager

    @State private var showingAPIKeySheet = false
    @State private var showingGeminiKeySheet = false
    @State private var showingVercelTokenSheet = false

    var body: some View {
        ZStack {
            BaroqueTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 44))
                        .foregroundColor(BaroqueTheme.gold)

                    FlourishedTitle(text: "Connect Gesso")

                    Text("Connect GitHub and an AI provider so Gesso can read and change your repos.")
                        .font(.body)
                        .foregroundColor(BaroqueTheme.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    if githubAuth.userCode != nil {
                        GitHubDeviceCodeView(githubAuth: githubAuth)
                    } else {
                        connectionRow(
                            title: "GitHub",
                            subtitle: "Access repositories to read and commit changes",
                            systemImage: "chevron.left.forwardslash.chevron.right",
                            isConnected: githubAuth.isConnected,
                            isBusy: githubAuth.isAuthenticating,
                            action: { githubAuth.connect() }
                        )
                    }
                    if let error = githubAuth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(BaroqueTheme.burgundy)
                    }

                    Text("AI Provider -- connect at least one")
                        .font(.caption)
                        .foregroundColor(BaroqueTheme.ink.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    connectionRow(
                        title: "Claude",
                        subtitle: "Send instructions and get responses from Claude",
                        systemImage: "sparkles",
                        isConnected: claudeAuth.isConnected,
                        isBusy: claudeAuth.isValidating,
                        action: { showingAPIKeySheet = true }
                    )
                    if let error = claudeAuth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(BaroqueTheme.burgundy)
                    }

                    connectionRow(
                        title: "Gemini",
                        subtitle: "Send instructions and get responses from Google's free-tier Gemini",
                        systemImage: "diamond.fill",
                        isConnected: geminiAuth.isConnected,
                        isBusy: geminiAuth.isValidating,
                        action: { showingGeminiKeySheet = true }
                    )
                    if let error = geminiAuth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(BaroqueTheme.burgundy)
                    }

                    connectionRow(
                        title: "Vercel (optional)",
                        subtitle: "Auto-discover your linked project's live deployment URL",
                        systemImage: "triangle.fill",
                        isConnected: vercelAuth.isConnected,
                        isBusy: vercelAuth.isValidating,
                        action: { showingVercelTokenSheet = true }
                    )
                    if let error = vercelAuth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(BaroqueTheme.burgundy)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            ClaudeAPIKeySheet(claudeAuth: claudeAuth, isPresented: $showingAPIKeySheet)
        }
        .sheet(isPresented: $showingGeminiKeySheet) {
            GeminiAPIKeySheet(geminiAuth: geminiAuth, isPresented: $showingGeminiKeySheet)
        }
        .sheet(isPresented: $showingVercelTokenSheet) {
            VercelAPIKeySheet(vercelAuth: vercelAuth, isPresented: $showingVercelTokenSheet)
        }
    }

    @ViewBuilder
    private func connectionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isConnected: Bool,
        isBusy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(isConnected ? BaroqueTheme.emerald : BaroqueTheme.sapphire)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.baroqueHeadline).foregroundColor(BaroqueTheme.ink)
                Text(subtitle).font(.caption).foregroundColor(BaroqueTheme.ink.opacity(0.6))
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(BaroqueTheme.emerald)
                    .font(.title2)
            } else if isBusy {
                ProgressView()
            } else {
                Button("Connect", action: action)
                    .buttonStyle(.ornate(BaroqueTheme.sapphire))
            }
        }
        .ornateCard(tint: isConnected ? BaroqueTheme.emerald : BaroqueTheme.gold)
    }
}

#Preview {
    ConnectView(
        githubAuth: GitHubAuthManager(),
        claudeAuth: ClaudeAuthManager(),
        geminiAuth: GeminiAuthManager(),
        vercelAuth: VercelAuthManager()
    )
}
