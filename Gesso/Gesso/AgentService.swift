//
//  AgentService.swift
//  Gesso
//
//  Common interface implemented by ClaudeAgentService and GeminiAgentService
//  so the rest of the app (ConversationStore, ChatView) can drive a tool-use
//  loop without caring which provider is behind it. `history` is opaque --
//  each provider owns its own wire format and just round-trips whatever it
//  handed back last time.
//

import Foundation
import UIKit

protocol AgentService {
    /// `images` is one screenshot per marked-up page, in the same order the
    /// per-page headers appear in `notesText`. `notesText`, when present, is
    /// attached as a separate plain-text file rather than embedded in
    /// `userText` -- it's transcribed handwriting, not part of the
    /// instruction itself.
    func send(
        userText: String,
        images: [UIImage],
        notesText: String?,
        history: [[String: Any]],
        onActivity: @escaping (String) -> Void,
        onQuestion: @escaping (_ question: String, _ options: [String]) async -> String
    ) async throws -> (reply: String, history: [[String: Any]])
}

extension ClaudeAgentService: AgentService {}
