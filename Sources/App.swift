import SwiftUI
import UIKit

@main
struct OpenCodeApp: App {
    @StateObject private var store = ConnectionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(AppSettings())
                .preferredColorScheme(.dark)
                .tint(Palette.violet)
        }
    }
}

// MARK: - Настройки отображения

@MainActor
final class AppSettings: ObservableObject {
    private static let zoomKey = "web.zoom"

    @Published var zoom: Double {
        didSet { UserDefaults.standard.set(zoom, forKey: Self.zoomKey) }
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.zoomKey)
        zoom = saved > 0 ? saved : 1.0
    }
}

// MARK: - Корень

/// Корень приложения.
///
/// Два способа работы:
/// 1. `native` — свой чат: сессии, переписка, поток ответа, разрешения.
/// 2. `web` — тот же интерфейс, что на компьютере: терминал, диффы, файлы.
///
/// Оба режима смотрят в один сервер, поэтому всё синхронизировано.
struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @StateObject private var chat = ChatStore()

    @State private var setupDone: Bool
    @State private var mode: Mode = .native
    @State private var reloadToken = 0
    @State private var state: WebState = .loading
    @State private var showSettings = false
    @State private var showLaunch: Bool
    @State private var debugOpenChat = false
    @State private var launchFaded = false

    enum Mode { case native, web }

    init() {
        let ready = ConnectionStore().connection.isComplete
        _setupDone = State(initialValue: ready)
        _showLaunch = State(initialValue: ready)
    }

    var body: some View {
        ZStack {
            Ink.void.ignoresSafeArea()

            if setupDone {
                content
            } else {
                SetupView {
                    setupDone = true
                    reloadToken += 1
                    launchFaded = false
                    showLaunch = true
                    Task { await chat.start() }
                }
                .transition(.opacity)
            }

            if showLaunch {
                LaunchScreen(
                    phase: chat.phase,
                    onRetry: {
                        launchFaded = false
                        Task { await chat.start() }
                    },
                    onSettings: {
                        showLaunch = false
                        showSettings = true
                    }
                )
                .opacity(launchFaded ? 0 : 1)
                .scaleEffect(launchFaded ? 1.04 : 1)
                .allowsHitTesting(!launchFaded)
                .zIndex(20)
                .transition(.opacity)
            }
        }
        .task {
            guard setupDone else { return }
            #if DEBUG
            let screen = ProcessInfo.processInfo.environment["OC_SCREEN"] ?? ""
            if screen == "web" { mode = .web }
            #endif
            await chat.start()
            #if DEBUG
            if screen == "chat" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                if let first = chat.sessions.first {
                    debugOpenChat = true
                    await chat.open(first)
                }
            }
            if screen == "new" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                await chat.newSession()
                debugOpenChat = true
                try? await Task.sleep(nanoseconds: 600_000_000)
                chat.draft = "Привет! Ответь двумя словами, что ты умеешь."
                await chat.send()
            }
            #endif
        }
        .onChange(of: chat.phase) { phase in
            #if DEBUG
            if ProcessInfo.processInfo.environment["OC_SCREEN"] == "launch" { return }
            #endif
            switch phase {
            case .ready, .unauthorized, .failed:
                if showLaunch, !launchFaded {
                    // Даём заставке доиграть появление, затем мягко уводим.
                    Task {
                        try? await Task.sleep(nanoseconds: 260_000_000)
                        withAnimation(.easeInOut(duration: 0.55)) { launchFaded = true }
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        showLaunch = false
                    }
                }
            case .connecting:
                break
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(onApply: {
                state = .loading
                reloadToken += 1
                launchFaded = false
                showLaunch = true
                Task { await chat.start() }
            })
        }
    }

    // MARK: Режимы

    private var content: some View {
        ZStack {
            // Родной чат. Не снимаем его с экрана, а прячем: так состояние
            // и прокрутка сохраняются при возврате из веб-режима.
            NativeRoot(
                chat: chat,
                onOpenWeb: {
                    Haptic.tap()
                    withAnimation(Motion.gentle) { mode = .web }
                },
                onSettings: { showSettings = true },
                forceOpenChat: debugOpenChat
            )
            .opacity(mode == .native ? 1 : 0)
            .allowsHitTesting(mode == .native)

            // Веб-интерфейс создаётся сразу при запуске и грузится в фоне.
            // Поэтому переключение «как на компьютере» происходит мгновенно,
            // без экрана загрузки.
            webMode
                .opacity(mode == .web ? 1 : 0)
                .allowsHitTesting(mode == .web)
        }
    }

    private var webMode: some View {
        VStack(spacing: 0) {
            // Тонкая родная полоса: возврат в свой чат, настройки, состояние.
            // Отдельная строка — чтобы не накрывать шапку интерфейса OpenCode.
            HStack(spacing: 10) {
                Button {
                    Haptic.tap(.medium)
                    withAnimation(Motion.gentle) { mode = .native }
                    Task { await chat.refreshFromBackground() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Мой чат")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Ink.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.white.opacity(0.09)))
                }
                .buttonStyle(.plain)

                Spacer()

                if case let .failed(message) = state {
                    Button {
                        state = .loading
                        reloadToken += 1
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "wifi.exclamationmark")
                            Text(message)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Ink.coral)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(Ink.coral.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                } else if state == .loading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(Ink.secondary)
                        Text("Загрузка")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Ink.tertiary)
                    }
                }

                Button {
                    Haptic.tap()
                    reloadToken += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)

                Button {
                    Haptic.tap()
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Ink.void)

            ZStack(alignment: .top) {
                if let url = store.connection.url {
                    WebContainer(
                        url: url,
                        username: store.connection.username,
                        password: store.connection.password,
                        reloadToken: reloadToken,
                        state: $state,
                        onSettings: { showSettings = true }
                    )
                }
            }
        }
    }
}

// MARK: - Родной чат

struct NativeRoot: View {
    @ObservedObject var chat: ChatStore
    var onOpenWeb: () -> Void
    var onSettings: () -> Void
    var forceOpenChat: Bool = false

    @State private var showingChat: Bool
    @State private var didAutoOpen = false

    init(chat: ChatStore, onOpenWeb: @escaping () -> Void,
         onSettings: @escaping () -> Void, forceOpenChat: Bool = false) {
        self.chat = chat
        self.onOpenWeb = onOpenWeb
        self.onSettings = onSettings
        self.forceOpenChat = forceOpenChat
        _showingChat = State(initialValue: forceOpenChat)
    }

    var body: some View {
        ZStack {
            if showingChat {
                ChatScreen(
                    store: chat,
                    onBack: {
                        withAnimation(Motion.gentle) {
                            showingChat = false
                            chat.close()
                        }
                    },
                    onOpenWeb: onOpenWeb
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                SessionListScreen(
                    store: chat,
                    onOpen: { session in
                        withAnimation(Motion.gentle) { showingChat = true }
                        Task { await chat.open(session) }
                    },
                    onNew: {
                        Task { await chat.newSession() }
                        withAnimation(Motion.gentle) { showingChat = true }
                    },
                    onOpenWeb: onOpenWeb,
                    onSettings: onSettings
                )
                .transition(.opacity)
            }
        }
        .onChange(of: forceOpenChat) { value in
            guard value, !didAutoOpen else { return }
            didAutoOpen = true
            withAnimation(Motion.gentle) { showingChat = true }
            // Если чат уже открыт намеренно (например, новый диалог) — не трогаем.
            if chat.currentSession == nil, let first = chat.sessions.first {
                Task { await chat.open(first) }
            }
        }
    }
}

// MARK: - Контейнер с веб-интерфейсом

struct WebContainer: View {
    let url: URL
    let username: String
    let password: String
    let reloadToken: Int
    @Binding var state: WebState
    let onSettings: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var showPanel = false
    @State private var localReloads = 0

    var body: some View {
        ZStack(alignment: .top) {
            WebView(url: url,
                    username: username,
                    password: password,
                    zoom: settings.zoom,
                    reloadToken: reloadToken + localReloads,
                    onStateChange: { state = $0 })
                // Клавиатуру не игнорируем, иначе она накрывает поле ввода.
                // Верх не растягиваем: над интерфейсом есть своя полоса.


            topOverlay

            // Слева — узкая полоса: потяни вправо, чтобы открыть панель управления.
            HStack {
                ControlHandle { showPanel = true }
                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $showPanel) {
            ControlPanel(reload: { localReloads += 1 }, openSettings: {
                showPanel = false
                onSettings()
            })
        }
    }

    @ViewBuilder
    private var topOverlay: some View {
        switch state {
        case .loading:
            VStack(spacing: 10) {
                StatusPill(text: "Загрузка", color: Palette.violet,
                           systemImage: "arrow.triangle.2.circlepath")
                LoadingLine()
            }
            .padding(.top, 2)
            .transition(.opacity)

        case let .failed(message):
            Button {
                state = .loading
            } label: {
                StatusPill(text: "Нет связи · \(message)", color: Palette.danger,
                           systemImage: "wifi.exclamationmark")
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

        case .unauthorized:
            Button(action: onSettings) {
                StatusPill(text: "Неверный пароль · открыть настройки",
                           color: Palette.danger, systemImage: "lock.slash")
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

        case .ready:
            EmptyView()
        }
    }
}

struct ControlHandle: View {
    let onOpen: () -> Void
    @State private var hintVisible = false

    var body: some View {
        ZStack(alignment: .leading) {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            if value.translation.width > 50, abs(value.translation.height) < 90 {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                onOpen()
                            }
                        }
                )
                .frame(width: 22)

            if hintVisible {
                StatusPill(text: "Потяни вправо → настройки", color: Palette.violet,
                           systemImage: "slider.horizontal.3")
                    .padding(.leading, 26)
                    .padding(.top, 90)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(width: 22)
        .task {
            guard !UserDefaults.standard.bool(forKey: "hint.shown") else { return }
            UserDefaults.standard.set(true, forKey: "hint.shown")
            withAnimation(.easeIn(duration: 0.35)) { hintVisible = true }
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            withAnimation(.easeOut(duration: 0.4)) { hintVisible = false }
        }
    }
}

/// Тонкая полоса прогресса под верхним краем.
struct LoadingLine: View {
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Palette.brand)
                .frame(width: geo.size.width * 0.38, height: 2)
                .offset(x: geo.size.width * phase)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                        phase = 1.05
                    }
                }
        }
        .frame(height: 2)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
