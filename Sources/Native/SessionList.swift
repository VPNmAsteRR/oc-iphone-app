import SwiftUI

// MARK: - Список сессий

/// Главный экран: приветствие, поиск и все сессии, сгруппированные
/// по времени. Внизу — единственное действие: новый диалог.
struct SessionListScreen: View {
    @ObservedObject var store: ChatStore
    var onOpen: (Session) -> Void
    var onNew: (String) -> Void
    var onSettings: () -> Void

    @State private var appeared = false
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        ZStack {
            AuraBackground(intensity: 0.85)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    header
                    connectionBanner
                    startBlock
                    searchField
                    content
                }
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                Haptic.tap()
                await store.loadSessions()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                newChatBar
            }
        }
        .onAppear {
            withAnimation(Motion.gentle.delay(0.05)) { appeared = true }
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenCode")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Ink.primary)
                Text(store.sessions.isEmpty ? "Нет сессий" : "\(store.sessions.count) сессий · синхронизация включена")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Ink.tertiary)
            }

            Spacer()

            Button {
                Haptic.tap()
                onSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(CircleIconStyle(size: 44))
            .glass(radius: 22, interactive: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 18)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

    // MARK: Состояние связи

    /// Если связь пропала после запуска, не показываем пустой экран:
    /// объясняем, что случилось, и даём кнопку «Повторить».
    @ViewBuilder
    private var connectionBanner: some View {
        switch store.phase {
        case .ready, .connecting:
            EmptyView()

        case .unauthorized:
            bannerRow(
                icon: "lock.slash",
                title: "Нужен пароль",
                subtitle: "Сервер не принял логин или пароль.",
                action: "Настройки",
                tint: Ink.coral
            ) { onSettings() }

        case let .failed(message):
            bannerRow(
                icon: "wifi.exclamationmark",
                title: "Нет связи с сервером",
                subtitle: message,
                action: "Повторить",
                tint: Ink.amber
            ) { store.restart() }
        }
    }

    private func bannerRow(icon: String, title: String, subtitle: String,
                           action: String, tint: Color,
                           perform: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                Haptic.tap()
                perform()
            } label: {
                Text(action)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(tint.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Ink.raised.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: Быстрый старт

    /// Крупное поле ввода на главном экране, как в Gemini: можно начать
    /// диалог, не заходя ни в какую сессию.
    private var startBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.sessions.isEmpty ? "С чего начнём?" : "Начать новый диалог")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Ink.tertiary)
                .padding(.leading, 4)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Спроси что угодно", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.leading, 4)
                    .padding(.vertical, 10)

                Button {
                    Haptic.tap(.medium)
                    submit()
                } label: {
                    ZStack {
                        Circle()
                            .fill(canStart ? Ink.aura : LinearGradient(
                                colors: [Color.white.opacity(0.09), Color.white.opacity(0.06)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canStart ? .white : Ink.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canStart)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Ink.raised.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)

            quickStarts
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var quickStarts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.quickIdeas, id: \.self) { idea in
                    Button {
                        Haptic.select()
                        draft = idea
                        composerFocused = true
                    } label: {
                        Text(idea)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Ink.secondary)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .glass(radius: 18, interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private static let quickIdeas = [
        "Что делали в прошлый раз?",
        "Что изменилось в проекте?",
        "Найди ошибку",
        "Добавь тесты",
    ]

    // MARK: Поиск

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Ink.tertiary)

            TextField("Поиск сессий", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Ink.primary)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !store.searchText.isEmpty {
                Button {
                    Haptic.tap()
                    withAnimation(Motion.snappy) { store.searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Ink.tertiary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .glass(radius: 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .animation(Motion.snappy, value: store.searchText.isEmpty)
    }

    // MARK: Содержимое

    @ViewBuilder
    private var content: some View {
        if store.filteredSessions.isEmpty {
            emptyState
        } else {
            ForEach(groups) { group in
                section(group)
            }
        }
    }

    private func section(_ group: SessionGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
                .textCase(nil)
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                ForEach(group.sessions) { session in
                    SessionRow(
                        session: session,
                        action: {
                            Haptic.select()
                            onOpen(session)
                        },
                        onDelete: {
                            Task { await store.delete(session) }
                        },
                        busy: store.activeSessions.contains(session.id)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Ink.indigo.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: store.searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Ink.indigo.opacity(0.85))
            }

            Text(store.searchText.isEmpty ? "Пока нет сессий" : "Ничего не найдено")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Ink.primary)

            Text(store.searchText.isEmpty
                 ? "Напиши первое сообщение — ответ появится здесь и на компьютере"
                 : "Попробуй другое название")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .transition(.opacity)
    }

    // MARK: Нижняя панель

    /// Одно действие: новый диалог. Фон панели доходит до низа
    /// экрана, но сама панель занимает только свою высоту: если
    /// положить сюда ZStack с Color, он растянется на весь экран
    /// и закроет список.
    private var newChatBar: some View {
        Button {
            Haptic.tap(.medium)
            onNew("")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("Новый диалог")
                    .font(.system(size: 15.5, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(Ink.aura))
            .shadow(color: Ink.indigo.opacity(0.5), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            LinearGradient(colors: [.clear, Ink.void],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 40)
                .offset(y: -34)
                .allowsHitTesting(false)
        }
        .background {
            Ink.void.ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Действия

    private var canStart: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        composerFocused = false
        onNew(text)
    }

    // MARK: Группировка

    private var groups: [SessionGroup] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [Session]] = [:]

        for session in store.filteredSessions {
            let title = Self.groupTitle(for: session.date, calendar: calendar)
            if buckets[title] == nil {
                order.append(title)
                buckets[title] = []
            }
            buckets[title]?.append(session)
        }

        return order.map { SessionGroup(title: $0, sessions: buckets[$0] ?? []) }
    }

    private static func groupTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Сегодня" }
        if calendar.isDateInYesterday(date) { return "Вчера" }

        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: Date())).day ?? 0
        if days < 7 { return "На этой неделе" }
        if days < 30 { return "В этом месяце" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }
}

struct SessionGroup: Identifiable {
    let title: String
    let sessions: [Session]
    var id: String { title }
}

// MARK: - Строка сессии

struct SessionRow: View {
    let session: Session
    var action: () -> Void
    var onDelete: () -> Void = {}
    var busy: Bool = false

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(session.projectName)
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.tertiary)
                            .lineLimit(1)

                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.tertiary.opacity(0.6))

                        Text(Self.relative(session.date))
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.tertiary)
                    }
                }

                Spacer(minLength: 6)

                if busy {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Ink.azure)
                                .frame(width: 3.5, height: 3.5)
                                .opacity(0.5 + Double(index) * 0.25)
                        }
                    }
                    .padding(.trailing, 2)
                    .transition(.opacity)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.tertiary.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 20)
            .scaleEffect(pressed ? 0.985 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Haptic.tap(.medium)
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    withAnimation(Motion.snappy) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.snappy) { pressed = false }
                }
        )
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Ink.auraSoft)
                .frame(width: 40, height: 40)
                .opacity(0.9)

            Image(systemName: "bubble.left.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private static func relative(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "только что" }
        if interval < 3600 { return "\(Int(interval / 60)) мин назад" }
        if interval < 86_400 { return "\(Int(interval / 3600)) ч назад" }
        let days = Int(interval / 86_400)
        if days == 1 { return "вчера" }
        if days < 7 { return "\(days) дн назад" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
