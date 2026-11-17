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
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onChange(of: state) { newState in
            if case .ready = newState, showSplash {
                withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
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
    @State private var pulse = false

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 20) {
                BrandMark(size: 96)
                    .scaleEffect(pulse ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                VStack(spacing: 6) {
                    Text("OpenCode")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text("подключение к серверу")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Palette.violet)
                    .padding(.top, 6)
            }
        }
        .onAppear { pulse = true }
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
