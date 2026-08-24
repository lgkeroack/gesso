//
//  WebViewStore.swift
//  Gesso
//
//  Owns the single WKWebView instance so it survives SwiftUI view updates.
//

import Foundation
import WebKit

final class WebViewStore: ObservableObject {
    let webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
}
