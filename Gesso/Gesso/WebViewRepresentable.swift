//
//  WebViewRepresentable.swift
//  Gesso
//
//  Thin SwiftUI wrapper around a pre-existing WKWebView (Apple's WebKit
//  engine -- the App-Store-legal browser view on iOS; third-party engines
//  like Chromium aren't available outside a narrow EU-only entitlement).
//

import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
