//
//  MainView.swift
//  Gesso
//
//  The main screen once a repo is picked: a full-screen WebView you can
//  annotate, with a small draggable toolbar (pen / eraser / gear) floating
//  on top, confined to Gesso's own window. Tapping Done runs handwriting
//  recognition on the pen strokes and produces Image A / Text A in memory.
//

import SwiftUI

enum AnnotationCaptureError: Error {
    case screenshotFailed
}

struct MainView: View {
    @ObservedObject var repoStore: RepoSelectionStore
    @ObservedObject var githubAuth: GitHubAuthManager
    @ObservedObject var claudeAuth: ClaudeAuthManager

    @StateObject private var webViewStore = WebViewStore()
    @State private var urlText = ""
    @State private var activeTool: ToolMode = .none
    @State private var annotationStyle: AnnotationStyle = .pen
    @State private var strokes: [Stroke] = []
    @State private var showingSettings = false

    @State private var isProcessingAnnotations = false
    @State private var captureError: String?
    @State private var showingChat = false

    @StateObject private var conversation = ConversationStore()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                addressBar
                ZStack {
                    WebViewRepresentable(webView: webViewStore.webView)
                    DrawingCanvas(strokes: $strokes, activeTool: $activeTool, annotationStyle: annotationStyle)
                        .allowsHitTesting(activeTool != .none)
                }
            }

            FloatingToolbar(
                activeTool: $activeTool,
                annotationStyle: $annotationStyle,
                onDone: finishAnnotating,
                onGear: { showingSettings = true }
            )
            .padding(.top, 60)
            .padding(.trailing, 16)

            if isProcessingAnnotations {
                processingOverlay
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(githubAuth: githubAuth, claudeAuth: claudeAuth, repoStore: repoStore)
        }
        .sheet(isPresented: $showingChat) {
            if let repo = repoStore.selectedRepo, let token = githubAuth.accessToken, let apiKey = claudeAuth.apiKey {
                ChatView(
                    conversation: conversation,
                    agent: ClaudeAgentService(apiKey: apiKey, repo: repo, githubToken: token),
                    onBack: goBackToCanvas,
                    onForward: startFreshRound
                )
            }
        }
        .alert("Couldn't process annotations", isPresented: .constant(captureError != nil), presenting: captureError) { _ in
            Button("OK") { captureError = nil }
        } message: { message in
            Text(message)
        }
    }

    private var addressBar: some View {
        HStack {
            TextField("Enter URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(loadURL)
            Button("Go", action: loadURL)
                .buttonStyle(.ornate(BaroqueTheme.sapphire))
        }
        .padding(8)
        .background(BaroqueTheme.backgroundGradient)
        .overlay(Rectangle().frame(height: 1).foregroundColor(BaroqueTheme.gold.opacity(0.5)), alignment: .bottom)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(BaroqueTheme.gold)
                Text("Processing annotations…")
                    .font(.baroqueHeadline)
                    .foregroundColor(BaroqueTheme.ink.opacity(0.7))
            }
            .padding(24)
            .background(BaroqueTheme.backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(BaroqueTheme.gold, lineWidth: 1.5)
            )
            .shadow(color: BaroqueTheme.ink.opacity(0.3), radius: 12, x: 0, y: 6)
        }
    }

    private func loadURL() {
        var text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            text = "https://\(text)"
        }
        guard let url = URL(string: text) else { return }
        webViewStore.webView.load(URLRequest(url: url))
    }

    private func finishAnnotating() {
        activeTool = .none
        let strokesSnapshot = strokes

        Task {
            isProcessingAnnotations = true
            let screenshot: UIImage
            let recognition: AnnotationRecognitionResult
            do {
                screenshot = try await captureScreenshot()
                recognition = await HandwritingRecognizer.process(strokes: strokesSnapshot)
            } catch {
                captureError = error.localizedDescription
                isProcessingAnnotations = false
                return
            }
            let imageA = AnnotationCompositor.composeImage(
                base: screenshot,
                markupStrokes: recognition.markupStrokes,
                textPlacements: recognition.textPlacements
            )
            let textA = AnnotationCompositor.composeNotesText(recognition.recognizedNotes)
            isProcessingAnnotations = false

            guard let repo = repoStore.selectedRepo,
                  let githubToken = githubAuth.accessToken,
                  let apiKey = claudeAuth.apiKey else {
                captureError = "Missing connection details."
                return
            }
            let agent = ClaudeAgentService(apiKey: apiKey, repo: repo, githubToken: githubToken)
            showingChat = true
            await conversation.send(image: imageA, notesText: textA, agent: agent)
        }
    }

    /// Back: dismiss the chat, keep everything (marks, conversation) so the
    /// user can add more markup and resubmit as additional information.
    private func goBackToCanvas() {
        showingChat = false
        activeTool = .draw
    }

    /// Forward: clear marks and the conversation, reload the page to show
    /// whatever changes Claude made, and start a fresh round.
    private func startFreshRound() {
        showingChat = false
        conversation.reset()
        strokes = []
        activeTool = .none
        webViewStore.webView.reload()
    }

    private func captureScreenshot() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            webViewStore.webView.takeSnapshot(with: nil) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? AnnotationCaptureError.screenshotFailed)
                }
            }
        }
    }
}

#Preview {
    MainView(repoStore: RepoSelectionStore(), githubAuth: GitHubAuthManager(), claudeAuth: ClaudeAuthManager())
}
