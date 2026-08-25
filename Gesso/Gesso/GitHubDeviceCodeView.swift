//
//  GitHubDeviceCodeView.swift
//  Gesso
//
//  Shown while GitHub's device flow is in progress: the code to enter at
//  github.com/login/device, a button to open that page, and a cancel option.
//

import SwiftUI

struct GitHubDeviceCodeView: View {
    @ObservedObject var githubAuth: GitHubAuthManager

    var body: some View {
        VStack(spacing: 12) {
            Text("Enter this code on GitHub")
                .font(.baroqueHeadline)
                .foregroundColor(BaroqueTheme.ink)

            Text(githubAuth.userCode ?? "")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundColor(BaroqueTheme.gold)
                .padding(.vertical, 4)

            if let verificationURI = githubAuth.verificationURI {
                Text(verificationURI)
                    .font(.caption)
                    .foregroundColor(BaroqueTheme.ink.opacity(0.6))
            }

            Button("Open GitHub to Enter Code") {
                githubAuth.openVerificationURL()
            }
            .buttonStyle(.ornate(BaroqueTheme.sapphire))

            Button("Cancel") {
                githubAuth.cancel()
            }
            .font(.footnote)
            .foregroundColor(BaroqueTheme.burgundy)
        }
        .padding()
        .ornateCard(tint: BaroqueTheme.gold)
    }
}
