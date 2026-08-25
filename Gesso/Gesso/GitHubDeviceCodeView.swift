//
//  GitHubDeviceCodeView.swift
//  Gesso
//
//  Shown while GitHub's device flow is in progress: the code to enter at
//  github.com/login/device (copyable), a button to open that page, and a
//  cancel option.
//

import SwiftUI
import UIKit

struct GitHubDeviceCodeView: View {
    @ObservedObject var githubAuth: GitHubAuthManager

    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Enter this code on GitHub")
                .font(.baroqueHeadline)
                .foregroundColor(BaroqueTheme.ink)

            HStack(spacing: 10) {
                Text(githubAuth.userCode ?? "")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(BaroqueTheme.gold)

                Button(action: copyCode) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .foregroundColor(didCopy ? BaroqueTheme.emerald : BaroqueTheme.sapphire)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(githubAuth.userCode == nil)
                .accessibilityLabel("Copy code")
            }
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

    private func copyCode() {
        guard let code = githubAuth.userCode else { return }
        UIPasteboard.general.string = code
        withAnimation { didCopy = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { didCopy = false }
        }
    }
}
