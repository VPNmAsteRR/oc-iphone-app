import SwiftUI
import UIKit

@main
struct OpenCodeApp: App {
    @StateObject private var store = ConnectionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Palette.violet)
        }
    }
}

// MARK: - Корень

/// Корень приложения.
///
/// Это самостоятельный клиент: список диалогов и чат. Никакого
/// браузера внутри нет — все экраны нарисованы нативно.
struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @StateObject private var chat = ChatStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var setupDone: Bool
    @State private var showSettings = false
    @State private var showLaunch: Bool
    @State private var debugOpenChat = false
    @State private var debugOpenSheet = false
    @State private var debugKeyboard = false
    @State private var launchFaded = false

    init() {
        let ready = ConnectionStore().connection.isComplete
        _setupDone = State(initialValue: ready)
        _showLaunch = State(initialValue: ready)
    }

    var body: some View {
        ZStack {
            Ink.void.ignoresSafeArea()

            if setupDone {
                NativeRoot(
                    chat: chat,
                    onSettings: { showSettings = true },
                    forceOpenChat: debugOpenChat,
                    forceOpenSheet: debugOpenSheet,
                    forceKeyboard: debugKeyboard
                )
            } else {
                SetupView {
                    setupDone = true
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
            if screen == "sheet" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                if let first = chat.sessions.first {
                    await chat.open(first)
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    debugOpenChat = true
                    debugOpenSheet = true
                }
            }
            if screen == "keyboard" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                if let first = chat.sessions.first {
                    await chat.open(first)
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    debugOpenChat = true
                    debugKeyboard = true
                }
            }
            if screen == "empty" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                await chat.newSession()
                debugOpenChat = true
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
        .onChange(of: scenePhase) { phase in
            // После сворачивания поток событий обрывается системой.
            // Возвращаемся — сразу подключаемся заново и сверяемся с сервером.
            guard phase == .active, setupDone else { return }
            Task { await chat.refreshFromBackground() }
        }
        .onChange(of: chat.phase) { phase in
            #if DEBUG
            if ProcessInfo.processInfo.environment["OC_SCREEN"] == "launch" { return }
            #endif
            switch phase {
            // Заставку убираем только когда сервер реально ответил.
            // Иначе человек остаётся на экране с понятными кнопками
            // «Повторить» / «Настройки», а не с пустым списком.
            case .ready:
                if showLaunch, !launchFaded {
                    // Даём заставке доиграть появление, затем мягко уводим.
                    Task {
                        try? await Task.sleep(nanoseconds: 260_000_000)
                        withAnimation(.easeInOut(duration: 0.55)) { launchFaded = true }
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        showLaunch = false
                    }
                }
            case .connecting, .unauthorized, .failed:
                break
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(onApply: {
                launchFaded = false
                showLaunch = true
                Task { await chat.start() }
            })
        }
    }
}

// MARK: - Родной чат

struct NativeRoot: View {
    @ObservedObject var chat: ChatStore
    var onSettings: () -> Void
    var forceOpenChat: Bool = false
    var forceOpenSheet: Bool = false
    var forceKeyboard: Bool = false

    @State private var showingChat: Bool
    @State private var didAutoOpen = false

    init(chat: ChatStore, onSettings: @escaping () -> Void,
         forceOpenChat: Bool = false, forceOpenSheet: Bool = false,
         forceKeyboard: Bool = false) {
        self.chat = chat
        self.onSettings = onSettings
        self.forceOpenChat = forceOpenChat
        self.forceOpenSheet = forceOpenSheet
        self.forceKeyboard = forceKeyboard
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
                    forceOpenSheet: forceOpenSheet,
                    forceKeyboard: forceKeyboard
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
                    onNew: { draft in
                        withAnimation(Motion.gentle) { showingChat = true }
                        Task {
                            // Новая сессия создаётся при первом сообщении,
                            // поэтому черновик сначала открываем, потом шлём.
                            await chat.newSession()
                            if !draft.isEmpty {
                                chat.draft = draft
                                await chat.send()
                            }
                        }
                    },
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
