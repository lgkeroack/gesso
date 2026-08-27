//
//  ConversationStore.swift
//  Gesso
//
//  Owns the running chat + the raw Anthropic message history for the
//  current annotation round. Persists across the chat sheet being
//  dismissed (Back) so a resubmitted annotation continues the same
//  conversation; Forward resets it entirely for a fresh round.
//

import Foundation
import UIKit

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var displayMessages: [ChatMessage] = []
    @Published private(set) var isWaitingForClaude = false
    @Published var errorMessage: String?

    private var apiHistory: [[String: Any]] = []
    private var hasStarted = false
    private var pendingQuestionContinuation: CheckedContinuation<String, Never>?

    func reset() {
        displayMessages = []
        apiHistory = []
        hasStarted = false
        isWaitingForClaude = false
        errorMessage = nil
        pendingQuestionContinuation = nil
    }

    /// Kicks off (or continues) the conversation with a new Image A / Text A round.
    /// The notes are attached as their own file rather than folded into the
    /// instruction text, so word-for-word transcription noise doesn't end up
    /// competing with the actual instruction for the model's attention.
    func send(image: UIImage, notesText: String, agent: any AgentService) async {
        let instruction: String
        if hasStarted {
            instruction = "Here's additional information -- see the attached notes file."
        } else {
            instruction = """
            Please make the changes to this repository's app shown in the attached screenshot and notes file. \
            Use the available tools to read and edit the relevant files, then commit your changes.
            """
        }
        hasStarted = true
        displayMessages.append(ChatMessage(role: .user, text: instruction + "\n\n" + notesText, image: image))
        await runAgent(userText: instruction, image: image, notesText: notesText, agent: agent)
    }

    /// A plain typed follow-up from the user (answering an open-ended question, adding context, etc).
    func sendFollowUp(text: String, agent: any AgentService) async {
        displayMessages.append(ChatMessage(role: .user, text: text, image: nil))
        await runAgent(userText: text, image: nil, notesText: nil, agent: agent)
    }

    /// Called when the user taps one of the option buttons on a `.question` message.
    func answerQuestion(messageID: UUID, option: String) {
        guard let index = displayMessages.firstIndex(where: { $0.id == messageID }) else { return }
        displayMessages[index].selectedOption = option
        pendingQuestionContinuation?.resume(returning: option)
        pendingQuestionContinuation = nil
    }

    private func runAgent(userText: String, image: UIImage?, notesText: String?, agent: any AgentService) async {
        isWaitingForClaude = true
        errorMessage = nil
        do {
            let (reply, updatedHistory) = try await agent.send(
                userText: userText,
                image: image,
                notesText: notesText,
                history: apiHistory,
                onActivity: { [weak self] activity in
                    Task { @MainActor in
                        self?.displayMessages.append(ChatMessage(role: .activity, text: activity, image: nil))
                    }
                },
                onQuestion: { [weak self] question, options in
                    guard let self else { return "" }
                    return await self.presentQuestion(question, options: options)
                }
            )
            apiHistory = updatedHistory
            if !reply.isEmpty {
                displayMessages.append(ChatMessage(role: .assistant, text: reply, image: nil))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isWaitingForClaude = false
    }

    private func presentQuestion(_ question: String, options: [String]) async -> String {
        await withCheckedContinuation { continuation in
            pendingQuestionContinuation = continuation
            displayMessages.append(ChatMessage(role: .question, text: question, image: nil, options: options))
        }
    }
}
