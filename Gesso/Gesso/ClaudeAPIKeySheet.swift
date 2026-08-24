//
//  ClaudeAPIKeySheet.swift
//  Gesso
//
//  Reusable sheet for entering/validating an Anthropic API key. Used from
//  both the initial ConnectView and the Settings connections screen.
//

import SwiftUI

struct ClaudeAPIKeySheet: View {
    @ObservedObject var claudeAuth: ClaudeAuthManager
    @Binding var isPresented: Bool

    @State private var apiKey = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("sk-ant-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Generate a key at console.anthropic.com and paste it here. It's stored in this device's Keychain and never leaves the device except in requests to Anthropic's API.")
                }

                if let error = claudeAuth.errorMessage {
                    Text(error).foregroundColor(.red)
                }
            }
            .navigationTitle("Connect Claude")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if claudeAuth.isValidating {
                        ProgressView()
                    } else {
                        Button("Connect") {
                            Task {
                                await claudeAuth.connect(apiKey: apiKey)
                                if claudeAuth.isConnected {
                                    apiKey = ""
                                    isPresented = false
                                }
                            }
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
