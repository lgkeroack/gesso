//
//  VercelAPIKeySheet.swift
//  Gesso
//
//  Sheet for entering/validating a Vercel Personal Access Token.
//

import SwiftUI

struct VercelAPIKeySheet: View {
    @ObservedObject var vercelAuth: VercelAuthManager
    @Binding var isPresented: Bool

    @State private var token = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Personal Access Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Vercel Access Token")
                } footer: {
                    Text("Generate a token at vercel.com/account/tokens and paste it here. It's stored in this device's Keychain and never leaves the device except in requests to Vercel's API.")
                }

                if let error = vercelAuth.errorMessage {
                    Text(error).foregroundColor(AppTheme.danger)
                }
            }
            .navigationTitle("Connect Vercel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vercelAuth.isValidating {
                        ProgressView()
                    } else {
                        Button("Connect") {
                            Task {
                                await vercelAuth.connect(token: token)
                                if vercelAuth.isConnected {
                                    token = ""
                                    isPresented = false
                                }
                            }
                        }
                        .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
