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

struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @State private var setupDone: Bool
    @State private var reloadToken = 0
    @State private var state: WebState = .loading
    @State private var showSettings = false
    @State private var showSplash = true

    init() {
        _setupDone = State(initialValue: ConnectionStore().connection.isComplete)
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if setupDone, let url = store.connection.url {
                WebContainer(
                    url: url,
                    username: store.connection.username,
                    password: store.connection.password,
                    reloadToken: reloadToken,
                    state: $state,
                    onSettings: { showSettings = true }
                )
            } else {
                SetupView {
                    setupDone = true
                    reloadToken += 1
                }
                .transition(.opacity)
            }

            if showSplash {
                SplashView(
                    state: state,
                    onRetry: {
                        state = .loading
                        reloadToken += 1
                    },
                    onSettings: {
                        showSplash = false
                        showSettings = true
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onChange(of: state) { newState in
            // При успехе прячем заставку. При ошибке — оставляем её с кнопками
            // «Повторить» и «Настройки», чтобы не было вечного спиннера.
            if showSplash, case .ready = newState {
                withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
            }
        }
        .task {
            // Страховка: если через 20 секунд ничего не произошло —
            // показываем понятное состояние, а не бесконечный спиннер.
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if showSplash, case .loading = state {
                state = .failed("Сервер не отвечает. Проверь связь или потяни для повтора.")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(onApply: {
                state = .loading
                reloadToken += 1
            })
        }
    }
}

// MARK: - Заставка

struct SplashView: View {
    let state: WebState
    let onRetry: () -> Void
    let onSettings: () -> Void

    @State private var appeared = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    // Орбитальное кольцо — глубина и движение
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [Palette.blue.opacity(0.0),
                                         Palette.blue.opacity(0.9),
                                         Palette.violet.opacity(0.9),
                                         Palette.blue.opacity(0.0)],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 168, height: 168)
                        .rotationEffect(.degrees(orbit ? 360 : 0))
                        .blur(radius: 0.3)
                        .opacity(appeared ? 1 : 0)

                    BrandMark3D(size: 106)
                        .scaleEffect(appeared ? 1 : 0.7)
                        .opacity(appeared ? 1 : 0)
                }

                VStack(spacing: 8) {
                    Text("OpenCode")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.brandText)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                switch state {
                case .loading:
                    DotsLoader()
                        .padding(.top, 10)

                case .failed:
                    VStack(spacing: 11) {
                        Button("Повторить") { onRetry() }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: 240)
                        Button("Настройки сервера") { onSettings() }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: 240)
                    }
                    .padding(.top, 8)

                case .unauthorized:
                    VStack(spacing: 11) {
                        Button("Исправить пароль") { onSettings() }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: 240)
                        Button("Повторить") { onRetry() }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: 240)
                    }
                    .padding(.top, 8)

                case .ready:
                    EmptyView()
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .animation(.spring(response: 0.75, dampingFraction: 0.75), value: appeared)
        .animation(.easeOut(duration: 1.1), value: state)
        .onAppear {
            appeared = true
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                orbit = true
            }
        }
    }

    private var subtitle: String {
        switch state {
        case .loading: return "подключение к серверу"
        case .failed: return "сервер не отвечает"
        case .unauthorized: return "сервер не принял пароль"
        case .ready: return ""
        }
    }
}

/// Три точки, бегущие по кругу — вместо системного спиннера.
struct DotsLoader: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == phase ? Palette.blue : Color.white.opacity(0.22))
                    .frame(width: 7, height: 7)
                    .scaleEffect(index == phase ? 1.35 : 1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 360_000_000)
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Контейнер с интерфейсом

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
                .ignoresSafeArea()

            topOverlay

            // Слева — узкая полоса: потяни вправо, чтобы открыть панель управления.
            // Так кнопка не перекрывает интерфейс OpenCode снизу.
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
                StatusPill(text: "Загрузка", color: Palette.violet, systemImage: "arrow.triangle.2.circlepath")
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
