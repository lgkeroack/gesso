//
//  ConnectView.swift
//  Gesso
//
//  Launch-time screen that requires GitHub and Claude to both be connected
//  before the rest of the app is reachable.
//

import SwiftUI

struct ConnectView: View {
    @ObservedObject var githubAuth: GitHubAuthManager
    @ObservedObject var claudeAuth: ClaudeAuthManager

    @State private var showingAPIKeySheet = false

    var body: some View {
        ZStack {
            BaroqueTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 44))
                        .foregroundColor(BaroqueTheme.gold)

                    FlourishedTitle(text: "Connect Gesso")

                    Text("Connect GitHub and Claude so Gesso can read and change your repos.")
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
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            ClaudeAPIKeySheet(claudeAuth: claudeAuth, isPresented: $showingAPIKeySheet)
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
    ConnectView(githubAuth: GitHubAuthManager(), claudeAuth: ClaudeAuthManager())
}
