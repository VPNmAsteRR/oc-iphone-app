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
            if screen == "chat" || screen == "chatwait" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                if let first = chat.sessions.first {
                    debugOpenChat = true
                    await chat.open(first)
                }
            }
            #endif
        }
        .onChange(of: chat.phase) { phase in
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

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .native:
            NativeRoot(
                chat: chat,
                onOpenWeb: {
                    withAnimation(Motion.gentle) { mode = .web }
                },
                onSettings: { showSettings = true },
                forceOpenChat: debugOpenChat
            )
            .transition(.opacity)

        case .web:
            webMode
                .transition(.opacity)
        }
    }

    private var webMode: some View {
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

            // Выход обратно в родной чат — всегда на виду, сверху справа.
            VStack {
                HStack {
                    Button {
                        Haptic.tap(.medium)
                        withAnimation(Motion.gentle) { mode = .native }
                        Task { await chat.refreshFromBackground() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Мой чат")
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                    }
                    .glass(radius: 20, interactive: true)

                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 6)

                Spacer()
            }
            .allowsHitTesting(mode == .web)
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
            if let first = chat.sessions.first {
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
                // Не игнорируем клавиатуру: иначе она накрывает поле ввода.
                // Верх (вырез) по-прежнему занимаем целиком.
                .ignoresSafeArea(.container, edges: .top)

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
