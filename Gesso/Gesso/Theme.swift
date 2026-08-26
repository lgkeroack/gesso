//
//  Theme.swift
//  Gesso
//
//  Flat, minimal design system: a neutral background/surface, ink text, and
//  three semantic colors (accent / success / danger). Titles and section
//  headers use Futura, one of Apple's built-in system fonts -- no font file
//  or Info.plist registration needed.
//

import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let surface = Color.white
    /// Deliberately darker than `background` -- for bars that sit directly
    /// above content that can itself be blank white (e.g. an unloaded
    /// WebView), where `background` alone reads as indistinguishable white.
    static let chrome = Color(red: 0.90, green: 0.90, blue: 0.92)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let accent = Color(red: 0.15, green: 0.42, blue: 0.86)
    static let success = Color(red: 0.16, green: 0.55, blue: 0.32)
    static let danger = Color(red: 0.80, green: 0.20, blue: 0.20)
}

extension Font {
    static func displayTitle(_ size: CGFloat = 28) -> Font {
        .custom("Futura-Medium", size: size)
    }

    static var sectionHeadline: Font {
        .custom("Futura-Medium", size: 17)
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var fill: Color = AppTheme.surface

    func body(content: Content) -> some View {
        content
            .padding()
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func card(fill: Color = AppTheme.surface) -> some View {
        modifier(CardModifier(fill: fill))
    }
}

// MARK: - Button

struct FlatButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == FlatButtonStyle {
    static func flat(_ tint: Color = AppTheme.accent) -> FlatButtonStyle {
        FlatButtonStyle(tint: tint)
    }
}
