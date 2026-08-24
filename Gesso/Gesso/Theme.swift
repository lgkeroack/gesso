//
//  Theme.swift
//  Gesso
//
//  Shared Baroque design system: cream/gold base with jewel-tone accents,
//  applied to chrome and containers (not the WebView content area itself).
//

import SwiftUI

enum BaroqueTheme {
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.90)
    static let creamDeep = Color(red: 0.96, green: 0.90, blue: 0.81)
    static let ink = Color(red: 0.19, green: 0.13, blue: 0.09)
    static let gold = Color(red: 0.79, green: 0.64, blue: 0.15)
    static let goldLight = Color(red: 0.87, green: 0.74, blue: 0.35)
    static let burgundy = Color(red: 0.48, green: 0.12, blue: 0.22)
    static let emerald = Color(red: 0.05, green: 0.43, blue: 0.31)
    static let sapphire = Color(red: 0.11, green: 0.23, blue: 0.43)
    static let amethyst = Color(red: 0.36, green: 0.16, blue: 0.42)

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [cream, creamDeep], startPoint: .top, endPoint: .bottom)
    }
}

extension Font {
    static func baroqueTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static var baroqueHeadline: Font {
        .system(.headline, design: .serif)
    }
}

// MARK: - Ornate card

struct OrnateCardModifier: ViewModifier {
    var tint: Color = BaroqueTheme.gold
    var fillColors: [Color] = [BaroqueTheme.cream, BaroqueTheme.creamDeep]

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                LinearGradient(colors: fillColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(0.9), lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                    .padding(-3)
            )
            .shadow(color: BaroqueTheme.ink.opacity(0.18), radius: 8, x: 0, y: 4)
            .shadow(color: tint.opacity(0.15), radius: 3, x: 0, y: 0)
    }
}

extension View {
    func ornateCard(tint: Color = BaroqueTheme.gold, fillColors: [Color]? = nil) -> some View {
        modifier(OrnateCardModifier(tint: tint, fillColors: fillColors ?? [BaroqueTheme.cream, BaroqueTheme.creamDeep]))
    }
}

// MARK: - Ornate button

struct OrnateButtonStyle: ButtonStyle {
    var tint: Color = BaroqueTheme.sapphire

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(BaroqueTheme.gold.opacity(0.85), lineWidth: 1.5)
            )
            .shadow(
                color: tint.opacity(0.35),
                radius: configuration.isPressed ? 1 : 5,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == OrnateButtonStyle {
    static func ornate(_ tint: Color = BaroqueTheme.sapphire) -> OrnateButtonStyle {
        OrnateButtonStyle(tint: tint)
    }
}

// MARK: - Ornamental accents

struct FlourishDivider: View {
    var tint: Color = BaroqueTheme.gold

    var body: some View {
        HStack(spacing: 8) {
            line
            Image(systemName: "diamond.fill")
                .font(.system(size: 6))
                .foregroundColor(tint)
            line
        }
    }

    private var line: some View {
        LinearGradient(
            colors: [tint.opacity(0), tint.opacity(0.8), tint.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

struct FlourishedTitle: View {
    let text: String
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "laurel.leading")
            Text(text)
                .font(.baroqueTitle(size))
            Image(systemName: "laurel.trailing")
        }
        .foregroundColor(BaroqueTheme.gold)
    }
}
