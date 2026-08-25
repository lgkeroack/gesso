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
    @ObservedObject var geminiAuth: GeminiAuthManager
    @ObservedObject var vercelAuth: VercelAuthManager
    @ObservedObject var providerStore: AIProviderStore

    @StateObject private var webViewStore = WebViewStore()
    @State private var urlText = ""
    @State private var isLoadingVercelDeployment = false
    @State private var vercelError: String?
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
            SettingsView(
                githubAuth: githubAuth,
                claudeAuth: claudeAuth,
                geminiAuth: geminiAuth,
                vercelAuth: vercelAuth,
                providerStore: providerStore,
                repoStore: repoStore
            )
        }
        .sheet(isPresented: $showingChat) {
            if let repo = repoStore.selectedRepo, let token = githubAuth.accessToken,
               let agent = buildAgent(repo: repo, githubToken: token) {
                ChatView(
                    conversation: conversation,
                    agent: agent,
                    providerName: providerDisplayName,
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
        VStack(spacing: 4) {
            HStack {
                TextField("Enter URL", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(loadURL)

                if vercelAuth.isConnected {
                    Button {
                        Task { await loadVercelDeployment() }
                    } label: {
                        if isLoadingVercelDeployment {
                            ProgressView()
                        } else {
                            Image(systemName: "triangle.fill")
                        }
                    }
                    .buttonStyle(.flat(AppTheme.accent))
                    .disabled(isLoadingVercelDeployment)
                }

                Button("Go", action: loadURL)
                    .buttonStyle(.flat(AppTheme.accent))
            }
            if let vercelError {
                Text(vercelError)
                    .font(.caption)
                    .foregroundColor(AppTheme.danger)
            }
        }
        .padding(8)
        .background(AppTheme.background)
        .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.ink.opacity(0.1)), alignment: .bottom)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(AppTheme.accent)
                Text("Processing annotations…")
                    .font(.sectionHeadline)
                    .foregroundColor(AppTheme.ink.opacity(0.7))
            }
            .padding(24)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.ink.opacity(0.2), radius: 12, x: 0, y: 6)
        }
    }

    private func loadVercelDeployment() async {
        guard let repo = repoStore.selectedRepo, let token = vercelAuth.accessToken else { return }
        vercelError = nil
        isLoadingVercelDeployment = true
        defer { isLoadingVercelDeployment = false }
        do {
            let project = try await VercelDeploymentService.findProject(forRepo: repo, token: token)
            let url = try await VercelDeploymentService.latestDeploymentURL(
                project: project, branch: repo.defaultBranch, token: token
            )
            urlText = url.absoluteString
            webViewStore.webView.load(URLRequest(url: url))
        } catch {
            vercelError = error.localizedDescription
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
                  let agent = buildAgent(repo: repo, githubToken: githubToken) else {
                captureError = "Missing connection details."
                return
            }
            showingChat = true
            await conversation.send(image: imageA, notesText: textA, agent: agent)
        }
    }

    private var providerDisplayName: String {
        switch providerStore.activeProvider(claudeConnected: claudeAuth.isConnected, geminiConnected: geminiAuth.isConnected) {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case nil: return "AI"
        }
    }

    private func buildAgent(repo: GitHubRepository, githubToken: String) -> (any AgentService)? {
        switch providerStore.activeProvider(claudeConnected: claudeAuth.isConnected, geminiConnected: geminiAuth.isConnected) {
        case .claude:
            guard let apiKey = claudeAuth.apiKey else { return nil }
            return ClaudeAgentService(apiKey: apiKey, repo: repo, githubToken: githubToken)
        case .gemini:
            guard let apiKey = geminiAuth.apiKey else { return nil }
            return GeminiAgentService(apiKey: apiKey, repo: repo, githubToken: githubToken)
        case nil:
            return nil
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
    MainView(
        repoStore: RepoSelectionStore(),
        githubAuth: GitHubAuthManager(),
        claudeAuth: ClaudeAuthManager(),
        geminiAuth: GeminiAuthManager(),
        vercelAuth: VercelAuthManager(),
        providerStore: AIProviderStore()
    )
}
