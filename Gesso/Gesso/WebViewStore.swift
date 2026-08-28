//
//  WebViewStore.swift
//  Gesso
//
//  Owns the single WKWebView instance so it survives SwiftUI view updates.
//  Also watches navigation so a failed page load (bad URL, offline, timeout)
//  surfaces a clear reason instead of just showing a blank page, publishes
//  scroll position so DrawingCanvas can keep markup pinned to the page
//  content instead of the viewport, and publishes the current URL plus a
//  pending-navigation prompt so MainView can offer to keep or discard markup
//  before a new page replaces the current one.
//

import Foundation
import WebKit

final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate, UIScrollViewDelegate {
    let webView: WKWebView
    @Published var loadError: String?
    @Published var scrollOffset: CGPoint = .zero
    @Published private(set) var currentURL: URL?
    @Published private(set) var pendingNavigationURL: URL?

    /// Set by MainView whenever the current page's markup changes -- decides
    /// whether decidePolicyFor needs to prompt at all before letting a
    /// navigation through.
    var currentPageHasMarkup = false

    private var pendingDecisionHandler: ((WKNavigationActionPolicy) -> Void)?

    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollOffset = scrollView.contentOffset
    }

    /// Lets the held-up navigation through. Called once the user has
    /// answered the keep/discard prompt (and, for "keep", once that page's
    /// screenshot has been captured).
    func allowPendingNavigation() {
        pendingDecisionHandler?(.allow)
        pendingDecisionHandler = nil
        pendingNavigationURL = nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame?.isMainFrame == true,
              navigationAction.navigationType != .reload,
              navigationAction.request.url != webView.url,
              currentPageHasMarkup else {
            decisionHandler(.allow)
            return
        }
        // Hold the decision open -- both prompt choices ultimately allow the
        // navigation, but we need the current page to stay loaded long
        // enough to capture its screenshot if the user chooses to keep it.
        pendingDecisionHandler = decisionHandler
        pendingNavigationURL = navigationAction.request.url
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadError = nil
        currentURL = webView.url
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recordFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recordFailure(error)
    }

    /// Ignores NSURLErrorCancelled (-999) -- that's just "a newer navigation
    /// started before this one finished" (e.g. typing a fresh URL quickly),
    /// not a real failure worth showing the user.
    private func recordFailure(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        loadError = error.localizedDescription
    }
}
