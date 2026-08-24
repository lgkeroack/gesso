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
    let agent: ClaudeAgentService
    var onBack: () -> Void
    var onForward: () -> Void

    @State private var followUpText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
                .background(BaroqueTheme.backgroundGradient.ignoresSafeArea())
            if let error = conversation.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(BaroqueTheme.burgundy)
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
                    .foregroundColor(BaroqueTheme.sapphire)
            }
            Spacer()
            Text("Claude").font(.baroqueHeadline).foregroundColor(BaroqueTheme.gold)
            Spacer()
            Button(action: onForward) {
                Label("New", systemImage: "chevron.right")
                    .labelStyle(.trailingIcon)
                    .foregroundColor(BaroqueTheme.emerald)
            }
        }
        .padding()
        .background(BaroqueTheme.backgroundGradient)
        .overlay(Rectangle().frame(height: 1).foregroundColor(BaroqueTheme.gold.opacity(0.5)), alignment: .bottom)
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
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(BaroqueTheme.gold, lineWidth: 1))
                }
                Text(message.text)
                    .foregroundColor(.white)
                    .ornateCard(
                        tint: BaroqueTheme.gold,
                        fillColors: [BaroqueTheme.sapphire, BaroqueTheme.sapphire.opacity(0.85)]
                    )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

        case .assistant:
            Text(message.text)
                .foregroundColor(BaroqueTheme.ink)
                .ornateCard(tint: BaroqueTheme.gold)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .activity:
            Text(message.text)
                .font(.caption)
                .italic()
                .foregroundColor(BaroqueTheme.amethyst)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .question:
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .foregroundColor(BaroqueTheme.ink)
                    .ornateCard(tint: BaroqueTheme.emerald)

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
                    .buttonStyle(.ornate(message.selectedOption == option ? BaroqueTheme.emerald : BaroqueTheme.emerald.opacity(0.6)))
                    .disabled(message.selectedOption != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputBar: some View {
        HStack {
            TextField("Message Claude…", text: $followUpText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(sendFollowUp)
            Button("Send", action: sendFollowUp)
                .buttonStyle(.ornate(BaroqueTheme.sapphire))
                .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.isWaitingForClaude)
        }
        .padding()
        .background(BaroqueTheme.backgroundGradient)
        .overlay(Rectangle().frame(height: 1).foregroundColor(BaroqueTheme.gold.opacity(0.5)), alignment: .top)
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
