//
//  WebViewStore.swift
//  Gesso
//
//  Owns the single WKWebView instance so it survives SwiftUI view updates.
//  Also watches navigation so a failed page load (bad URL, offline, timeout)
//  surfaces a clear reason instead of just showing a blank page.
//

import Foundation
import WebKit

final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    @Published var loadError: String?

    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadError = nil
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
