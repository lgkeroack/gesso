//
//  AIProviderStore.swift
//  Gesso
//
//  Which AI provider (Claude or Gemini) actually powers the agent, when the
//  user has more than one connected. Persists the user's preference; falls
//  back to whichever provider is actually connected if the preferred one
//  isn't (e.g. they disconnected it).
//

import Foundation

enum AIProvider: String {
    case claude
    case gemini
}

final class AIProviderStore: ObservableObject {
    private static let preferenceKey = "ai.preferredProvider"

    @Published var preferred: AIProvider {
        didSet {
            UserDefaults.standard.set(preferred.rawValue, forKey: Self.preferenceKey)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.preferenceKey),
           let saved = AIProvider(rawValue: raw) {
            preferred = saved
        } else {
            preferred = .claude
        }
    }

    /// The provider to actually use, given which are connected. Prefers the
    /// stored preference, but falls back to whichever is connected if the
    /// preferred one isn't; nil if neither is connected.
    func activeProvider(claudeConnected: Bool, geminiConnected: Bool) -> AIProvider? {
        switch preferred {
        case .claude where claudeConnected:
            return .claude
        case .gemini where geminiConnected:
            return .gemini
        default:
            if claudeConnected { return .claude }
            if geminiConnected { return .gemini }
            return nil
        }
    }
}
