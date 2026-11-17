import SwiftUI
import CoreMotion

// MARK: - Заставка

/// Экран запуска: объёмная сфера из частиц, светящееся ядро и кольца.
///
/// Частицы лежат на настоящей сфере и вращаются по трём осям —
/// это не картинка, а живая проекция, поэтому глубина видна по размеру
/// и яркости точек. При наклоне телефона фигура слегка поворачивается
/// вслед за рукой.
struct LaunchScreen: View {
    let phase: ChatStore.Phase
    var onRetry: () -> Void
    var onSettings: () -> Void

    @State private var appeared = false
    @State private var breathe = false
    @State private var tilt = CGSize.zero

    private let motion = MotionDriver()

    var body: some View {
        ZStack {
            AuraBackground(intensity: 1.15)

            // Мягкое свечение под фигурой
            RadialGradient(
                colors: [Ink.indigo.opacity(0.35), .clear],
                center: .center, startRadius: 0, endRadius: 260
            )
            .frame(width: 520, height: 520)
            .offset(y: -40)
            .scaleEffect(breathe ? 1.08 : 0.94)
            .blur(radius: 26)
            .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: breathe)

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                ParticleOrb()
                    .frame(width: 300, height: 300)
                    .overlay(CoreMark())
                    .rotation3DEffect(.degrees(tilt.height * 10),
                                      axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(tilt.width * 10),
                                      axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .scaleEffect(appeared ? 1 : 0.62)
                    .opacity(appeared ? 1 : 0)
                    .animation(Motion.slow, value: appeared)
                    .blur(radius: appeared ? 0 : 12)

                VStack(spacing: 10) {
                    Text("OpenCode")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Ink.azure, Ink.orchid],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .shadow(color: Ink.indigo.opacity(0.45), radius: 10, y: 3)

                    Text(statusText)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: statusText)

                    if let detailText {
                        Text(detailText)
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 46)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if case .connecting = phase {
                        AuraProgress()
                            .frame(width: 132)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 26)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(Motion.gentle.delay(0.15), value: appeared)

                if needsActions {
                    VStack(spacing: 10) {
                        if case .failed = phase {
                            Button {
                                Haptic.tap(.medium)
                                onRetry()
                            } label: {
                                Label("Повторить", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(AuraButtonStyle(compact: true))
                        }
                        if case .unauthorized = phase {
                            Button {
                                Haptic.tap(.medium)
                                onRetry()
                            } label: {
                                Label("Повторить", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(AuraButtonStyle(compact: true))
                        }
                        Button {
                            Haptic.tap()
                            onSettings()
                        } label: {
                            Label("Настройки сервера", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                    .frame(maxWidth: 268)
                    .padding(.top, 26)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 26)
        }
        .onAppear {
            appeared = true
            breathe = true
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
            motion.start { pitch, roll in
                withAnimation(.easeOut(duration: 0.45)) {
                    tilt = CGSize(width: roll, height: pitch)
                }
            }
        }
        .onDisappear { motion.stop() }
    }

    private var needsActions: Bool {
        switch phase {
        case .failed, .unauthorized: return true
        case .connecting, .ready: return false
        }
    }

    private var statusText: String {
        switch phase {
        case .connecting: return "подключение к серверу"
        case .ready: return "готово"
        case .unauthorized: return "сервер не принял пароль"
        case .failed: return "нет связи с сервером"
        }
    }

    private var detailText: String? {
        switch phase {
        case let .failed(message): return message
        case .unauthorized: return "Проверь логин и пароль в настройках"
        default: return nil
        }
    }
}

// MARK: - Сфера из частиц

/// Точки на сфере Фибоначчи, спроецированные в перспективе.
private struct ParticleOrb: View {
    private let points: [SIMD3<Double>]
    private let radius: Double = 1.0

    init(count: Int = 460) {
        var generated: [SIMD3<Double>] = []
        let golden = Double.pi * (3 - sqrt(5.0))
        for index in 0..<count {
            let y = 1 - (Double(index) / Double(count - 1)) * 2
            let ringRadius = sqrt(max(0, 1 - y * y))
            let theta = golden * Double(index)
            generated.append(SIMD3(cos(theta) * ringRadius, y, sin(theta) * ringRadius))
        }
        points = generated
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let angleY = time * 0.42
                let angleX = sin(time * 0.31) * 0.55

                let cosY = cos(angleY), sinY = sin(angleY)
                let cosX = cos(angleX), sinX = sin(angleX)

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let scale = min(size.width, size.height) * 0.42

                for point in points {
                    // Вращение вокруг Y
                    let x = point.x * cosY + point.z * sinY
                    var z = -point.x * sinY + point.z * cosY
                    // Вращение вокруг X
                    let y = point.y * cosX - z * sinX
                    z = point.y * sinX + z * cosX

                    // Перспектива
                    let depth = 2.4 / (2.4 + z)
                    let screen = CGPoint(
                        x: center.x + x * scale * depth,
                        y: center.y + y * scale * depth
                    )

                    // Чем ближе точка, тем ярче и крупнее
                    let near = (1 - z) / 2               // 0..1
                    let size2 = (1.1 + near * 2.1) * depth
                    let color = inkColor(for: near)

                    let rect = CGRect(
                        x: screen.x - size2 / 2,
                        y: screen.y - size2 / 2,
                        width: size2, height: size2
                    )
                    canvas.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .compositingGroup()
    }

    private func inkColor(for near: Double) -> Color {
        // Дальние — глубокая синева, ближние — светлая орхидея.
        let clamped = max(0, min(1, near))
        let r = 0.28 + 0.55 * clamped
        let g = 0.34 + 0.26 * clamped
        let b = 0.95 - 0.02 * clamped
        return Color(red: r, green: g, blue: b)
            .opacity(0.18 + 0.82 * clamped)
    }
}

// MARK: - Ядро

/// Светящийся шар с бликом и знаком в центре.
private struct CoreMark: View {
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.55, green: 0.65, blue: 1.0).opacity(0.55),
                            Ink.indigo.opacity(0.35),
                            Ink.orchid.opacity(0.05),
                            .clear,
                        ],
                        center: .init(x: 0.42, y: 0.36),
                        startRadius: 0, endRadius: 74
                    )
                )
                .frame(width: 148, height: 148)
                .blur(radius: 8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.40, green: 0.50, blue: 0.98),
                            Ink.indigo,
                            Color(red: 0.34, green: 0.18, blue: 0.68),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 92, height: 92)

            // Верхний блик стекла
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        startPoint: .top, endPoint: .center
                    )
                )
                .frame(width: 84, height: 84)
                .offset(y: -3)
                .blendMode(.plusLighter)

            // Нижний отсвет
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Ink.orchid.opacity(0.6), .clear],
                        center: .init(x: 0.5, y: 0.85), startRadius: 0, endRadius: 44
                    )
                )
                .frame(width: 88, height: 88)
                .blendMode(.plusLighter)

            // Медленный световой сектор по стеклу
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.28),
                            .clear,
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90)
                    )
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(shimmer ? 360 : 0))
                .blendMode(.plusLighter)
                .opacity(0.55)

            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Наклон по движению телефона

/// Отдаёт наклон телефона, чтобы фигура поворачивалась вслед за рукой.
private final class MotionDriver {
    private let manager = CMMotionManager()
    private var handler: ((Double, Double) -> Void)?

    func start(_ handler: @escaping (Double, Double) -> Void) {
        self.handler = handler
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let pitch = max(-1, min(1, data.attitude.pitch / 1.2))
            let roll = max(-1, min(1, data.attitude.roll / 1.2))
            self.handler?(pitch, roll)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        handler = nil
    }
}

// MARK: - Компактные индикаторы

/// Три точки, бегущие по кругу: используются в чате.
struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == phase ? Ink.azure : Ink.tertiary)
                    .frame(width: 5, height: 5)
                    .scaleEffect(index == phase ? 1.4 : 1)
            }
        }
        .animation(Motion.snappy, value: phase)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 340_000_000)
                phase = (phase + 1) % 3
            }
        }
    }
}

/// Полоса неопределённого прогресса с градиентом.
struct AuraProgress: View {
    @State private var slide: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(
                    LinearGradient(colors: [.clear, Ink.azure, Ink.indigo, .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: geo.size.width * 0.42, height: 3)
                .offset(x: geo.size.width * slide)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: false)) {
                        slide = 1.05
                    }
                }
        }
        .frame(height: 3)
        .clipShape(Capsule())
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}
