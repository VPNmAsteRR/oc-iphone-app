import SwiftUI

// MARK: - Чат

/// Переписка с сессией: сообщения, живой ответ, инструменты, поле ввода.
struct ChatScreen: View {
    @ObservedObject var store: ChatStore
    var onBack: () -> Void
    var onOpenWeb: () -> Void

    @State private var appeared = false
    @FocusState private var composerFocused: Bool
    @State private var showHeader = true
    @State private var lastScrollID: String?

    var body: some View {
        ZStack {
            AuraBackground(intensity: 0.7)

            VStack(spacing: 0) {
                header
                transcript
                composerArea
            }
        }
        .onAppear {
            withAnimation(Motion.gentle) { appeared = true }
        }
        .onChange(of: store.messages.count) { _ in
            scrollToBottom()
        }
        .onChange(of: store.streamingText) { _ in
            scrollToBottom()
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptic.tap()
                composerFocused = false
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .glass(radius: 20, interactive: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentSession?.displayTitle ?? "Сессия")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isWorking ? Ink.amber : Ink.mint)
                        .frame(width: 5, height: 5)
                    Text(store.isWorking ? "работает" : (store.currentSession?.projectName ?? "проект"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button {
                Haptic.tap()
                onOpenWeb()
            } label: {
                Image(systemName: "display")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Ink.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .glass(radius: 20, interactive: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [Ink.void.opacity(0.9), Ink.void.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        )
    }

    // MARK: Лента

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if store.messages.isEmpty {
                        quietStart
                    } else {
                        ForEach(store.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }

                    if !store.streamingText.isEmpty || !store.streamingReasoning.isEmpty {
                        LiveAnswer(text: store.streamingText,
                                   reasoning: store.streamingReasoning)
                            .id("live")
                    } else if store.isWorking {
                        ThinkingRow()
                            .id("live")
                    }

                    if !store.permissions.isEmpty {
                        ForEach(store.permissions) { permission in
                            PermissionCard(permission: permission) { decision in
                                Haptic.tap(.medium)
                                Task { await store.reply(permission, decision: decision) }
                            }
                            .id("permission-\(permission.id)")
                        }
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.streamingText) { _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: store.messages.count) { _ in
                withAnimation(Motion.gentle) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var quietStart: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Ink.indigo.opacity(0.1))
                    .frame(width: 76, height: 76)
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Ink.indigo.opacity(0.9))
            }
            Text("Пустая сессия")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Ink.primary)
            Text("Напиши первое сообщение — ответ появится здесь и на компьютере.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 30)
    }

    // MARK: Ввод

    private var composerArea: some View {
        VStack(spacing: 0) {
            SoftDivider().opacity(0.5)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Спроси что угодно", text: $store.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1...6)
                    .focused($composerFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)

                Button {
                    Haptic.tap(.medium)
                    if store.isWorking {
                        Task { await store.stopGeneration() }
                    } else {
                        Task { await store.send() }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Ink.aura : LinearGradient(
                                colors: [Color.white.opacity(0.09), Color.white.opacity(0.06)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 38, height: 38)

                        Image(systemName: store.isWorking ? "stop.fill" : "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(canSend ? .white : Ink.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !store.isWorking)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Ink.raised.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom))
    }

    private var canSend: Bool {
        !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scrollToBottom() {
        // Прокрутка живёт внутри ScrollViewReader; здесь только цель.
        lastScrollID = "bottom"
    }
}

// MARK: - Сообщение

struct MessageRow: View {
    let message: ChatMessage
    @State private var appeared = false

    var body: some View {
        Group {
            if message.isUser {
                userBubble
            } else {
                assistantBubble
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(Motion.gentle) { appeared = true }
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 44)
            Text(message.userText)
                .font(.system(size: 15.5))
                .foregroundStyle(Ink.primary)
                .lineSpacing(2)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Ink.float.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        }
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array((message.content ?? []).enumerated()), id: \.offset) { _, part in
                if part.isText, let text = part.text, !text.isEmpty {
                    RichText(text: text)
                } else if part.isReasoning, let text = part.text, !text.isEmpty {
                    ReasoningCard(text: text)
                } else if part.isTool {
                    ToolCard(part: part)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Живой ответ

struct LiveAnswer: View {
    let text: String
    let reasoning: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if !reasoning.isEmpty {
                ReasoningCard(text: reasoning, live: true)
            }
            if !text.isEmpty {
                RichText(text: text)
            } else if !reasoning.isEmpty {
                EmptyView()
            }
            HStack(spacing: 6) {
                TypingDots()
                Spacer()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }
}

// MARK: - Размышления

struct ReasoningCard: View {
    let text: String
    var live: Bool = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(Motion.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "brain")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Ink.orchid.opacity(0.9))
                    Text(live ? "Думает" : "Размышления")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                    if live {
                        TypingDots()
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Ink.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Ink.tertiary)
                    .lineSpacing(2)
                    .padding(.horizontal, 13)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Ink.orchid.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Ink.orchid.opacity(0.16), lineWidth: 1)
        )
    }
}

// MARK: - Инструмент

struct ToolCard: View {
    let part: Part
    @State private var expanded = false

    private var state: ToolState? { part.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(Motion.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 9) {
                    statusIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(part.displayName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Ink.primary.opacity(0.9))
                        if let summary = state?.summary {
                            Text(summary)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Ink.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Ink.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let input = state?.input, case let .object(dict) = input {
                        ForEach(dict.keys.sorted(), id: \.self) { key in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Ink.azure.opacity(0.85))
                                Text(Self.plain(dict[key]))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Ink.secondary)
                                    .lineLimit(6)
                            }
                        }
                    }
                    if let content = state?.content {
                        ForEach(Array(content.enumerated()), id: \.offset) { _, piece in
                            if let text = piece.text, !text.isEmpty {
                                Text(String(text.prefix(2500)))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Ink.tertiary)
                                    .padding(9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(Ink.void.opacity(0.55))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Ink.raised.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        if state?.isRunning == true {
            ProgressView()
                .controlSize(.mini)
                .tint(Ink.azure)
                .frame(width: 15, height: 15)
        } else if state?.isFailed == true {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Ink.coral)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Ink.mint.opacity(0.9))
        }
    }

    static func plain(_ value: JSONValue?) -> String {
        switch value {
        case let .string(text): return text
        case let .number(number):
            return number == number.rounded() ? String(Int(number)) : String(number)
        case let .bool(flag): return flag ? "да" : "нет"
        case let .array(items): return items.map { plain($0) }.joined(separator: ", ")
        case let .object(dict):
            return dict.map { "\($0.key): \(plain($0.value))" }.joined(separator: ", ")
        case .null, .none: return "—"
        }
    }
}

// MARK: - Ожидание

struct ThinkingRow: View {
    var body: some View {
        HStack(spacing: 9) {
            TypingDots()
            Text("Думает")
                .font(.system(size: 12.5))
                .foregroundStyle(Ink.tertiary)
        }
        .padding(.vertical, 6)
        .transition(.opacity)
    }
}

// MARK: - Разрешение

struct PermissionCard: View {
    let permission: PermissionRequest
    var onReply: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Ink.amber)
                Text("Нужно разрешение")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Ink.primary)
            }

            if let action = permission.action, !action.isEmpty {
                Text(action)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Ink.secondary)
            }
            if let resource = permission.resource, !resource.isEmpty {
                Text(resource)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(4)
            }

            HStack(spacing: 8) {
                actionButton("Разрешить", "once", Ink.azure, filled: true)
                actionButton("Всегда", "always", Ink.mint, filled: false)
                actionButton("Нет", "reject", Ink.coral, filled: false)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Ink.amber.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Ink.amber.opacity(0.22), lineWidth: 1)
        )
    }

    private func actionButton(_ title: String, _ decision: String,
                              _ tint: Color, filled: Bool) -> some View {
        Button {
            onReply(decision)
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(filled ? .white : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(filled ? tint.opacity(0.9) : tint.opacity(0.13))
                )
        }
        .buttonStyle(.plain)
    }
}
