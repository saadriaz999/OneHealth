import SwiftUI

struct ChatbotView: View {
    @Environment(\.dismiss) var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                welcomeMessage
                            }
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if isLoading {
                                HStack {
                                    ProgressView()
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                // Input bar
                HStack(spacing: 12) {
                    TextField("Ask about your medicines...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4)

                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("Hi, I'm your medicine assistant")
                .font(.headline)
            Text("Ask me anything about your medications, side effects, timing, or interactions.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private func sendMessage() async {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        messages.append(ChatMessage(role: "user", content: userText))
        inputText = ""
        isLoading = true
        errorMessage = nil

        // Build history for API (exclude last user message, it's in the message param)
        let history = messages.dropLast().map { ["role": $0.role, "content": $0.content] }

        do {
            let response = try await APIService.shared.chat(message: userText, history: history)
            messages.append(ChatMessage(role: "assistant", content: response.response))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer() }
            Text(message.content)
                .padding(12)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .cornerRadius(16)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer() }
        }
    }
}
