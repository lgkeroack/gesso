//
//  GeminiAgentService.swift
//  Gesso
//
//  Drives the Gemini Interactions API tool-use loop -- the Gemini equivalent
//  of ClaudeAgentService. Gives Gemini tools to list/read/write files in the
//  connected GitHub repo, executes those tool calls locally against
//  GitHubRepoFileService, and keeps looping until Gemini produces a final
//  text reply. Calls go straight from the device to
//  generativelanguage.googleapis.com and api.github.com -- no backend.
//
//  Unlike the old generateContent API, conversation state lives server-side:
//  each call sends only the new turn's input plus `previous_interaction_id`,
//  rather than replaying the full history. `history` (the AgentService
//  protocol's opaque round-trip value) is just [["previous_interaction_id": id]],
//  or [] before the first turn.
//

import Foundation
import UIKit

enum GeminiAgentError: LocalizedError {
    case requestFailed(String)
    case tooManySteps

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message): return message
        case .tooManySteps: return "Gemini took too many steps without finishing; stopped for safety."
        }
    }
}

struct GeminiAgentService: AgentService {
    private static let model = "gemini-3.6-flash"
    private static let interactionsURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!
    private static let maxToolIterations = 12

    let apiKey: String
    let repo: GitHubRepository
    let githubToken: String

    func send(
        userText: String,
        images: [UIImage],
        notesText: String?,
        history initialHistory: [[String: Any]],
        onActivity: @escaping (String) -> Void,
        onQuestion: @escaping (_ question: String, _ options: [String]) async -> String
    ) async throws -> (reply: String, history: [[String: Any]]) {
        var previousInteractionId = initialHistory.first?["previous_interaction_id"] as? String

        var contentItems: [[String: Any]] = [["type": "text", "text": userText]]
        for image in images {
            guard let jpeg = image.jpegData(compressionQuality: 0.7) else { continue }
            contentItems.append([
                "type": "image",
                "mime_type": "image/jpeg",
                "data": jpeg.base64EncodedString()
            ])
        }
        if let notesText, let notesData = notesText.data(using: .utf8) {
            contentItems.append([
                "type": "document",
                "mime_type": "text/plain",
                "data": notesData.base64EncodedString()
            ])
        }
        var input: [[String: Any]] = [["type": "user_input", "content": contentItems]]

        var iterations = 0
        while true {
            iterations += 1
            if iterations > Self.maxToolIterations {
                throw GeminiAgentError.tooManySteps
            }

            let responseBody = try await callInteractions(input: input, previousInteractionId: previousInteractionId)
            guard let interactionId = responseBody["id"] as? String,
                  let steps = responseBody["steps"] as? [[String: Any]] else {
                throw GeminiAgentError.requestFailed("Unexpected response from Gemini.")
            }
            previousInteractionId = interactionId

            let functionCalls = steps.filter { ($0["type"] as? String) == "function_call" }
            if !functionCalls.isEmpty {
                var resultItems: [[String: Any]] = []
                for call in functionCalls {
                    guard let name = call["name"] as? String, let callId = call["id"] as? String else { continue }
                    let args = call["arguments"] as? [String: Any] ?? [:]

                    let result: String
                    if name == "ask_clarifying_question" {
                        let question = args["question"] as? String ?? "Gemini has a question."
                        let options = args["options"] as? [String] ?? []
                        result = await onQuestion(question, options)
                    } else {
                        onActivity(activityDescription(tool: name, input: args))
                        result = await runTool(name: name, input: args)
                    }

                    resultItems.append([
                        "type": "function_result",
                        "name": name,
                        "call_id": callId,
                        "result": [["type": "text", "text": result]]
                    ])
                }
                input = resultItems
                continue
            }

            let reply = steps
                .filter { ($0["type"] as? String) == "model_output" }
                .compactMap { $0["content"] as? [[String: Any]] }
                .flatMap { $0 }
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")

            return (reply, [["previous_interaction_id": interactionId]])
        }
    }

    private func callInteractions(input: [[String: Any]], previousInteractionId: String?) async throws -> [String: Any] {
        var request = URLRequest(url: Self.interactionsURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": Self.model,
            "system_instruction": Self.systemPrompt,
            "tools": Self.toolDefinitions,
            "input": input
        ]
        if let previousInteractionId {
            body["previous_interaction_id"] = previousInteractionId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiAgentError.requestFailed("Couldn't parse Gemini's response.")
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? "Gemini request failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1))."
            throw GeminiAgentError.requestFailed(message)
        }
        return json
    }

    private func runTool(name: String, input: [String: Any]) async -> String {
        do {
            switch name {
            case "list_repository_files":
                let path = input["path"] as? String ?? ""
                let entries = try await GitHubRepoFileService.listFiles(repo: repo, token: githubToken, path: path)
                if entries.isEmpty { return "(empty directory)" }
                return entries.map { "\($0.type): \($0.path)" }.joined(separator: "\n")
            case "read_file":
                guard let path = input["path"] as? String else { return "Error: missing path." }
                return try await GitHubRepoFileService.readFile(repo: repo, token: githubToken, path: path)
            case "write_file":
                guard let path = input["path"] as? String,
                      let content = input["content"] as? String,
                      let message = input["commit_message"] as? String else {
                    return "Error: missing path, content, or commit_message."
                }
                let sha = try await GitHubRepoFileService.writeFile(
                    repo: repo, token: githubToken, path: path, content: content, commitMessage: message
                )
                return "Committed \(path) to \(repo.defaultBranch) (commit \(sha))."
            default:
                return "Error: unknown tool \(name)."
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private func activityDescription(tool: String, input: [String: Any]) -> String {
        let path = input["path"] as? String
        switch tool {
        case "list_repository_files":
            return "Listing files in \(path?.isEmpty == false ? path! : "repository root")…"
        case "read_file":
            return "Reading \(path ?? "a file")…"
        case "write_file":
            return "Updating \(path ?? "a file")…"
        default:
            return "Running \(tool)…"
        }
    }

    private static let systemPrompt = """
    You are helping a developer edit a web app's source code, working from a screenshot of the app with visual \
    annotations (circles, highlights, freehand marks) plus notes transcribed from their handwriting. Use the \
    available tools to inspect the repository and read the relevant files before editing anything. When you're \
    confident about what to change, edit the file(s) and commit with a clear commit message. If you need the \
    user to pick between a small number of specific options before you can proceed, call ask_clarifying_question \
    rather than guessing. For open-ended questions, just ask in your normal reply text.
    """

    private static let toolDefinitions: [[String: Any]] = [
        [
            "type": "function",
            "name": "ask_clarifying_question",
            "description": "Ask the user a clarifying question with a fixed set of short answer choices, when you need them to pick between specific options before continuing. Only use this for genuine multiple-choice decisions, not open-ended questions -- for those, just ask in your normal reply text.",
            "parameters": [
                "type": "object",
                "properties": [
                    "question": ["type": "string"],
                    "options": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "2 to 6 short answer choices."
                    ]
                ],
                "required": ["question", "options"]
            ]
        ],
        [
            "type": "function",
            "name": "list_repository_files",
            "description": "List files and subdirectories at a path in the connected GitHub repository.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Directory path; empty string for the repository root."]
                ],
                "required": [String]()
            ]
        ],
        [
            "type": "function",
            "name": "read_file",
            "description": "Read the full text contents of a file in the connected GitHub repository.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "File path relative to the repository root."]
                ],
                "required": ["path"]
            ]
        ],
        [
            "type": "function",
            "name": "write_file",
            "description": "Create or update a file in the connected GitHub repository and commit the change to the repository's default branch.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": ["type": "string"],
                    "content": ["type": "string", "description": "The complete new contents of the file."],
                    "commit_message": ["type": "string"]
                ],
                "required": ["path", "content", "commit_message"]
            ]
        ]
    ]
}
