//
//  ContentView.swift
//  Gesso
//
//  Empty scaffold. The only capability present is stylus input.
//

import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        StylusInputView()
            .ignoresSafeArea()
    }
}

/// Full-screen surface that receives Apple Pencil input.
struct StylusInputView: UIViewRepresentable {
    func makeUIView(context: Context) -> StylusInputSurface {
        StylusInputSurface()
    }

    func updateUIView(_ uiView: StylusInputSurface, context: Context) {}
}

final class StylusInputSurface: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        isMultipleTouchEnabled = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        receive(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        receive(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        receive(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        receive(touches, with: event)
    }

    /// Entry point for stylus input. Coalesced touches are used so the full
    /// Pencil sample rate is available rather than one point per frame.
    /// Nothing consumes the samples yet.
    private func receive(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch.type == .pencil {
            _ = event?.coalescedTouches(for: touch) ?? [touch]
        }
    }
}

#Preview {
    ContentView()
}
