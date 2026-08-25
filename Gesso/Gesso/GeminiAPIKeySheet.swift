//
//  GeminiAPIKeySheet.swift
//  Gesso
//
//  Reusable sheet for entering/validating a Gemini API key. Used from both
//  the initial ConnectView and the Settings connections screen.
//

import SwiftUI

struct GeminiAPIKeySheet: View {
    @ObservedObject var geminiAuth: GeminiAuthManager
    @Binding var isPresented: Bool

    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("AIza...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("Generate a free key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey) and paste it here. It's stored in this device's Keychain and never leaves the device except in requests to Google's API.")
                }

                if let error = geminiAuth.errorMessage {
                    Text(error).foregroundColor(.red)
                }
            }
            .navigationTitle("Connect Gemini")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if geminiAuth.isValidating {
                        ProgressView()
                    } else {
                        Button("Connect") {
                            Task {
                                await geminiAuth.connect(apiKey: apiKey)
                                if geminiAuth.isConnected {
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
