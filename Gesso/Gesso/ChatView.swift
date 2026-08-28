//
//  ChatView.swift
//  Gesso
//
//  Chat with Claude about the current annotation round. Back returns to the
//  canvas keeping everything (marks, captured artifacts, conversation) so
//  you can add more and resubmit as "additional information." Forward
//  clears everything and reloads the page for a fresh round.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var conversation: ConversationStore
    let agent: any AgentService
    let providerName: String
    var onBack: () -> Void
    var onForward: () -> Void

    @State private var followUpText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
                .background(AppTheme.background.ignoresSafeArea())
            if let error = conversation.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppTheme.danger)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            inputBar
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
                    .foregroundColor(AppTheme.accent)
            }
            Spacer()
            Text(providerName).font(.sectionHeadline).foregroundColor(AppTheme.ink)
            Spacer()
            Button(action: onForward) {
                Label("New", systemImage: "chevron.right")
                    .labelStyle(.trailingIcon)
                    .foregroundColor(AppTheme.success)
            }
        }
        .padding()
        .background(AppTheme.surface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.ink.opacity(0.1)), alignment: .bottom)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.displayMessages) { message in
                        messageRow(message).id(message.id)
                    }
                    if conversation.isWaitingForClaude {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Claude is working…").foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: conversation.displayMessages.count) { _, _ in
                if let last = conversation.displayMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            VStack(alignment: .trailing, spacing: 6) {
                ForEach(Array(message.images.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(message.text)
                    .foregroundColor(.white)
                    .card(fill: AppTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

        case .assistant:
            Text(message.text)
                .foregroundColor(AppTheme.ink)
                .card()
                .frame(maxWidth: .infinity, alignment: .leading)

        case .activity:
            Text(message.text)
                .font(.caption)
                .italic()
                .foregroundColor(AppTheme.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .question:
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .foregroundColor(AppTheme.ink)
                    .card()

                ForEach(message.options ?? [], id: \.self) { option in
                    Button {
                        conversation.answerQuestion(messageID: message.id, option: option)
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if message.selectedOption == option {
                                Image(systemName: "checkmark.seal.fill")
                            }
                        }
                    }
                    .buttonStyle(.flat(message.selectedOption == option ? AppTheme.success : AppTheme.success.opacity(0.6)))
                    .disabled(message.selectedOption != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputBar: some View {
        HStack {
            TextField("Message \(providerName)…", text: $followUpText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(sendFollowUp)
            Button("Send", action: sendFollowUp)
                .buttonStyle(.flat(AppTheme.accent))
                .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.isWaitingForClaude)
        }
        .padding()
        .background(AppTheme.surface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.ink.opacity(0.1)), alignment: .top)
    }

    private func sendFollowUp() {
        let text = followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        followUpText = ""
        Task { await conversation.sendFollowUp(text: text, agent: agent) }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

private extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}
