//
//  MainView.swift
//  Gesso
//
//  The main screen once a repo is picked: a full-screen WebView you can
//  annotate, with a small draggable toolbar (pen / eraser / gear) floating
//  on top, confined to Gesso's own window. Tapping Done runs handwriting
//  recognition on the pen strokes and produces Image A / Text A in memory.
//
//  Markup is kept per-page (keyed by full URL): navigating away from a page
//  that has markup prompts to keep or discard it, and a screenshot is
//  captured for a kept page right before it unloads (rather than by
//  silently re-visiting old pages later, which could show different
//  content than what was actually marked up). Submitting sends one
//  screenshot per page that has markup -- the current page plus any saved
//  ones -- in a single round.
//

import SwiftUI
import WebKit

enum AnnotationCaptureError: LocalizedError {
    case screenshotFailed

    var errorDescription: String? {
        switch self {
        case .screenshotFailed: return "Couldn't capture a screenshot of the page."
        }
    }
}

/// A page's saved markup plus the full-page screenshot captured at the
/// moment the user chose to keep it (not re-captured later, since
/// re-visiting the live page could show different content than what was
/// actually marked up).
private struct PageAnnotation {
    var strokes: [Stroke]
    var screenshot: UIImage
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

    /// Pages other than the current one that have markup saved on them,
    /// keyed by full URL.
    @State private var savedPages: [String: PageAnnotation] = [:]
    @State private var currentPageKey: String?

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
                    DrawingCanvas(
                        strokes: $strokes,
                        activeTool: $activeTool,
                        annotationStyle: annotationStyle,
                        scrollOffset: webViewStore.scrollOffset
                    )
                    .allowsHitTesting(activeTool != .none)
                }
            }

            FloatingToolbar(
                activeTool: $activeTool,
                annotationStyle: $annotationStyle,
                hasMarkup: !strokes.isEmpty || !savedPages.isEmpty,
                onSubmit: finishAnnotating,
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
        .onChange(of: repoStore.selectedRepo) { _, _ in
            startFreshRound()
        }
        .onChange(of: strokes) { _, newValue in
            webViewStore.currentPageHasMarkup = !newValue.isEmpty
        }
        .onChange(of: webViewStore.currentURL) { _, newURL in
            handlePageChange(to: newURL)
        }
        .alert(
            "Keep markup on this page?",
            isPresented: Binding(get: { webViewStore.pendingNavigationURL != nil }, set: { _ in })
        ) {
            Button("Keep") { Task { await keepCurrentPageAndProceed() } }
            Button("Discard", role: .destructive) { discardCurrentPageAndProceed() }
        } message: {
            Text("You've marked up this page. Keep it so it's still here if you come back, or discard it?")
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
            if let loadError = webViewStore.loadError {
                Text("Couldn't load page: \(loadError)")
                    .font(.caption)
                    .foregroundColor(AppTheme.danger)
            }
        }
        .padding(8)
        .background(AppTheme.chrome)
        .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.ink.opacity(0.15)), alignment: .bottom)
        .shadow(color: AppTheme.ink.opacity(0.12), radius: 4, x: 0, y: 2)
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

    /// Sends one screenshot per marked-up page in a single round -- the
    /// current page (captured fresh) plus any pages saved earlier via the
    /// keep/discard prompt.
    private func finishAnnotating() {
        activeTool = .none
        let currentStrokesSnapshot = strokes
        let currentLabel = currentPageKey ?? "current page"
        let otherPages = savedPages

        Task {
            isProcessingAnnotations = true

            var images: [UIImage] = []
            var notesSections: [String] = []

            if !currentStrokesSnapshot.isEmpty {
                do {
                    let currentScreenshot = try await captureScreenshot()
                    let (image, notes) = await composePage(
                        strokes: currentStrokesSnapshot, screenshot: currentScreenshot, label: currentLabel
                    )
                    images.append(image)
                    notesSections.append(notes)
                } catch {
                    captureError = error.localizedDescription
                    isProcessingAnnotations = false
                    return
                }
            }

            for (label, page) in otherPages {
                let (image, notes) = await composePage(strokes: page.strokes, screenshot: page.screenshot, label: label)
                images.append(image)
                notesSections.append(notes)
            }

            isProcessingAnnotations = false

            guard !images.isEmpty else {
                captureError = "No markup to submit."
                return
            }
            guard let repo = repoStore.selectedRepo else {
                captureError = "No repository selected."
                return
            }
            guard let githubToken = githubAuth.accessToken else {
                captureError = "Not connected to GitHub."
                return
            }
            guard let agent = buildAgent(repo: repo, githubToken: githubToken) else {
                captureError = "No AI provider connected. Connect Claude or Gemini in Settings."
                return
            }
            showingChat = true
            await conversation.send(images: images, notesText: notesSections.joined(separator: "\n\n"), agent: agent)
        }
    }

    /// Runs handwriting recognition for one page's strokes and composites
    /// its markup onto that page's screenshot, returning the finished image
    /// plus a labeled notes section identifying which page it's from.
    private func composePage(strokes: [Stroke], screenshot: UIImage, label: String) async -> (image: UIImage, notes: String) {
        let recognition = await HandwritingRecognizer.process(strokes: strokes)
        let image = AnnotationCompositor.composeImage(
            base: screenshot,
            markupStrokes: recognition.markupStrokes,
            textPlacements: recognition.textPlacements
        )
        let notes = AnnotationCompositor.composeNotesText(recognition.recognizedNotes)
        return (image, "=== Page: \(label) ===\n\(notes)")
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
        savedPages = [:]
        activeTool = .none
        webViewStore.webView.reload()
    }

    /// A navigation just finished -- swap in whatever markup was saved for
    /// this page, or start blank if it's never been visited/kept.
    private func handlePageChange(to url: URL?) {
        currentPageKey = url?.absoluteString
        strokes = currentPageKey.flatMap { savedPages[$0]?.strokes } ?? []
    }

    /// Discards the departing page's markup (including anything saved for
    /// it from an earlier visit) and lets the held-up navigation proceed.
    private func discardCurrentPageAndProceed() {
        if let currentPageKey {
            savedPages.removeValue(forKey: currentPageKey)
        }
        webViewStore.allowPendingNavigation()
    }

    /// Captures the departing page's screenshot while it's still loaded,
    /// saves it alongside its strokes, then lets the held-up navigation
    /// proceed.
    private func keepCurrentPageAndProceed() async {
        guard let currentPageKey else {
            webViewStore.allowPendingNavigation()
            return
        }
        do {
            let screenshot = try await captureScreenshot()
            savedPages[currentPageKey] = PageAnnotation(strokes: strokes, screenshot: screenshot)
        } catch {
            captureError = error.localizedDescription
        }
        webViewStore.allowPendingNavigation()
    }

    /// Captures the whole scrollable page, not just the visible viewport, so
    /// markup drawn anywhere on the page (which stays pinned to its content
    /// position when scrolling) lines up correctly against the full image.
    private func captureScreenshot() async throws -> UIImage {
        let webView = webViewStore.webView
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: webView.scrollView.contentSize)
        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: config) { image, error in
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
