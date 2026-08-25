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
    func send(
        userText: String,
        image: UIImage?,
        history: [[String: Any]],
        onActivity: @escaping (String) -> Void,
        onQuestion: @escaping (_ question: String, _ options: [String]) async -> String
    ) async throws -> (reply: String, history: [[String: Any]])
}

extension ClaudeAgentService: AgentService {}
