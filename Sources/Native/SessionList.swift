import SwiftUI

// MARK: - Список сессий

/// Главный экран: все сессии, сгруппированные по времени,
/// с поиском и плавным появлением.
struct SessionListScreen: View {
    @ObservedObject var store: ChatStore
    var onOpen: (Session) -> Void
    var onNew: () -> Void
    var onOpenWeb: () -> Void
    var onSettings: () -> Void

    @State private var appeared = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            AuraBackground(intensity: 0.85)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    header
                    searchField
                    content
                }
                .padding(.bottom, 148)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                Haptic.tap()
                await store.loadSessions()
            }

            bottomBar
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
        .padding(.top, 14)
        .padding(.bottom, 18)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

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
                .focused($searchFocused)
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
                        onOpenWeb: onOpenWeb
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
                 ? "Начни диалог — он появится и на компьютере"
                 : "Попробуй другое название")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .transition(.opacity)
    }

    // MARK: Нижняя панель

    private var bottomBar: some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Button {
                    Haptic.tap(.medium)
                    onOpenWeb()
                } label: {
                    Label("Как на компьютере", systemImage: "display")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                }
                .glass(radius: 24, interactive: true)

                Button {
                    Haptic.tap(.medium)
                    onNew()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text("Новая")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 48)
                    .background(Capsule().fill(Ink.aura))
                    .shadow(color: Ink.indigo.opacity(0.55), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            .background(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    // Сплошная подложка до самого низа экрана.
                    Ink.void
                        .frame(height: 132)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.55),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Ink.void
                        .frame(height: 64)
                        .offset(y: 30)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
        }
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
    var onOpenWeb: () -> Void = {}

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
            Button {
                Haptic.tap()
                onOpenWeb()
            } label: {
                Label("Открыть как на компьютере", systemImage: "display")
            }
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
