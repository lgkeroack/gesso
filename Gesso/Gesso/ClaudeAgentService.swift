//
//  ClaudeAgentService.swift
//  Gesso
//
//  Drives the Anthropic Messages API tool-use loop: gives Claude tools to
//  list/read/write files in the connected GitHub repo, executes those tool
//  calls locally against GitHubRepoFileService, and keeps looping until
//  Claude produces a final text reply. Calls go straight from the device to
//  api.anthropic.com and api.github.com -- no backend.
//

import Foundation
import UIKit

enum ClaudeAgentError: LocalizedError {
    case requestFailed(String)
    case tooManySteps

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message): return message
        case .tooManySteps: return "Claude took too many steps without finishing; stopped for safety."
        }
    }
}

struct ClaudeAgentService {
    private static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"
    private static let model = "claude-sonnet-5"
    private static let maxToolIterations = 12

    let apiKey: String
    let repo: GitHubRepository
    let githubToken: String

    /// Sends userText (with an optional image) as a new turn appended to `history`,
    /// runs any tool calls Claude requests, and returns Claude's final text reply.
    /// `history` is mutated in place so the caller can continue the same conversation.
    func send(
        userText: String,
        image: UIImage?,
        history: inout [[String: Any]],
        onActivity: @escaping (String) -> Void,
        onQuestion: @escaping (_ question: String, _ options: [String]) async -> String
    ) async throws -> String {
        var userContent: [[String: Any]] = []
        if let image, let jpeg = image.jpegData(compressionQuality: 0.7) {
            userContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpeg.base64EncodedString()
                ]
            ])
        }
        userContent.append(["type": "text", "text": userText])
        history.append(["role": "user", "content": userContent])

        var iterations = 0
        while true {
            iterations += 1
            if iterations > Self.maxToolIterations {
                throw ClaudeAgentError.tooManySteps
            }

            let responseBody = try await callMessagesAPI(history: history)
            guard let contentBlocks = responseBody["content"] as? [[String: Any]] else {
                throw ClaudeAgentError.requestFailed("Unexpected response from Claude.")
            }
            history.append(["role": "assistant", "content": contentBlocks])

            if responseBody["stop_reason"] as? String == "tool_use" {
                var toolResults: [[String: Any]] = []
                for block in contentBlocks where block["type"] as? String == "tool_use" {
                    guard let toolUseId = block["id"] as? String,
                          let toolName = block["name"] as? String else { continue }
                    let input = block["input"] as? [String: Any] ?? [:]

                    let result: String
                    if toolName == "ask_clarifying_question" {
                        let question = input["question"] as? String ?? "Claude has a question."
                        let options = input["options"] as? [String] ?? []
                        result = await onQuestion(question, options)
                    } else {
                        onActivity(activityDescription(tool: toolName, input: input))
                        result = await runTool(name: toolName, input: input)
                    }

                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolUseId,
                        "content": result
                    ])
                }
                history.append(["role": "user", "content": toolResults])
                continue
            }

            return contentBlocks
                .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                .joined(separator: "\n")
        }
    }

    private func callMessagesAPI(history: [[String: Any]]) async throws -> [String: Any] {
        var request = URLRequest(url: Self.messagesURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 4096,
            "system": Self.systemPrompt,
            "tools": Self.toolDefinitions,
            "messages": history
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAgentError.requestFailed("Couldn't parse Claude's response.")
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? "Claude request failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1))."
            throw ClaudeAgentError.requestFailed(message)
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
            "name": "ask_clarifying_question",
            "description": "Ask the user a clarifying question with a fixed set of short answer choices, when you need them to pick between specific options before continuing. Only use this for genuine multiple-choice decisions, not open-ended questions -- for those, just ask in your normal reply text.",
            "input_schema": [
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
            "name": "list_repository_files",
            "description": "List files and subdirectories at a path in the connected GitHub repository.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Directory path; empty string for the repository root."]
                ],
                "required": []
            ]
        ],
        [
            "name": "read_file",
            "description": "Read the full text contents of a file in the connected GitHub repository.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "File path relative to the repository root."]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "write_file",
            "description": "Create or update a file in the connected GitHub repository and commit the change to the repository's default branch.",
            "input_schema": [
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
