import SwiftUI
import UIKit

// MARK: - Палитра

/// Цвета приложения. Основа — глубокий графит, акцент — сине-фиолетовый,
/// как у современных ассистентов.
enum Ink {
    static let void = Color(red: 0.043, green: 0.047, blue: 0.055)      // #0B0C0E
    static let base = Color(red: 0.075, green: 0.078, blue: 0.086)      // #131416
    static let raised = Color(red: 0.118, green: 0.125, blue: 0.137)    // #1E2023
    static let float = Color(red: 0.157, green: 0.165, blue: 0.180)     // #282A2E

    static let primary = Color(red: 0.925, green: 0.933, blue: 0.945)
    static let secondary = Color(red: 0.643, green: 0.663, blue: 0.694)
    static let tertiary = Color(red: 0.427, green: 0.443, blue: 0.475)

    static let azure = Color(red: 0.345, green: 0.588, blue: 0.980)     // #5896FA
    static let indigo = Color(red: 0.463, green: 0.427, blue: 1.0)      // #766DFF
    static let orchid = Color(red: 0.694, green: 0.478, blue: 1.0)      // #B17AFF
    static let mint = Color(red: 0.325, green: 0.878, blue: 0.702)
    static let coral = Color(red: 1.0, green: 0.435, blue: 0.478)
    static let amber = Color(red: 1.0, green: 0.741, blue: 0.353)

    /// Главный градиент: небесно-синий → индиго → орхидея.
    static var aura: LinearGradient {
        LinearGradient(
            colors: [azure, indigo, orchid],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var auraSoft: LinearGradient {
        LinearGradient(
            colors: [azure.opacity(0.85), indigo.opacity(0.8), orchid.opacity(0.75)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Анимации

/// Единые пружины приложения: всё двигается одинаково мягко.
enum Motion {
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.62)
    static let slow = Animation.spring(response: 0.9, dampingFraction: 0.9)
}

// MARK: - Живой фон

/// Медленно дышащие цветные пятна под стеклом.
/// Работает везде: на iOS 18+ через плавную сетку, ниже — через размытые круги.
struct AuraBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            Ink.void

            if #available(iOS 18.0, *) {
                MeshBackdrop(intensity: intensity)
            } else {
                BlobBackdrop(intensity: intensity)
            }

            // Лёгкое затемнение сверху, чтобы текст всегда читался.
            LinearGradient(
                colors: [Ink.void.opacity(0.75), .clear, Ink.void.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

@available(iOS 18.0, *)
private struct MeshBackdrop: View {
    var intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let wave = (sin(t / 9) + 1) / 2
            let wave2 = (cos(t / 13) + 1) / 2
            BackdropMesh(wave: wave, wave2: wave2, intensity: intensity)
        }
        .blur(radius: 40)
        .opacity(0.9)
    }
}

@available(iOS 18.0, *)
private struct BackdropMesh: View {
    let wave: Double
    let wave2: Double
    let intensity: Double

    var body: some View {
        MeshGradient(width: 3, height: 3,
                     points: meshPoints, colors: meshColors)
    }

    private var meshPoints: [SIMD2<Float>] {
        let a = Float(wave)
        let b = Float(wave2)
        return [
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(0.5 + 0.08 * a, 0.0),
            SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.42),
            SIMD2<Float>(0.5, 0.45 + 0.06 * b),
            SIMD2<Float>(1.0, 0.40),
            SIMD2<Float>(0.0, 1.0),
            SIMD2<Float>(0.5 + 0.06 * b, 1.0),
            SIMD2<Float>(1.0, 1.0),
        ]
    }

    private var meshColors: [Color] {
        let k = intensity
        return [
            Ink.void,
            Ink.void,
            Color(red: 0.09, green: 0.07, blue: 0.15).opacity(k),
            Color(red: 0.06, green: 0.09, blue: 0.18).opacity(k),
            Ink.indigo.opacity(0.20 * k),
            Color(red: 0.15, green: 0.08, blue: 0.20).opacity(k),
            Ink.void,
            Ink.azure.opacity(0.16 * k),
            Ink.void,
        ]
    }
}

private struct BlobBackdrop: View {
    var intensity: Double
    @State private var breathe = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                blob(Ink.indigo.opacity(0.28 * intensity), size: geo.size.width * 1.1)
                    .offset(x: breathe ? geo.size.width * 0.15 : -geo.size.width * 0.1,
                            y: geo.size.height * 0.32)
                blob(Ink.azure.opacity(0.22 * intensity), size: geo.size.width * 0.9)
                    .offset(x: breathe ? -geo.size.width * 0.2 : geo.size.width * 0.2,
                            y: geo.size.height * 0.62)
                blob(Ink.orchid.opacity(0.16 * intensity), size: geo.size.width * 0.8)
                    .offset(x: geo.size.width * 0.2, y: -geo.size.height * 0.12)
            }
            .blur(radius: 70)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, .clear],
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }
}

// MARK: - Стекло

/// Стеклянная поверхность: настоящий Liquid Glass на iOS 26,
/// матовое стекло на более старых системах.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 24
    var tint: Color? = nil
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                tint == nil ? .regular : .regular.tint(tint),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill((tint ?? Color.white).opacity(tint == nil ? 0.03 : 0.14))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.03)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
}

extension View {
    func glass(radius: CGFloat = 24, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, tint: tint, interactive: interactive))
    }

    /// Мягкая тень под плавающими элементами.
    func floatingShadow(_ strength: Double = 1) -> some View {
        shadow(color: .black.opacity(0.45 * strength), radius: 24 * strength, y: 10 * strength)
    }
}

// MARK: - Кнопки

/// Главная кнопка: градиент, объём, отклик.
struct AuraButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                    .fill(Ink.aura)
                    .opacity(enabled ? 1 : 0.32)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .shadow(color: Ink.indigo.opacity(enabled ? 0.45 : 0), radius: 20, y: 10)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Второстепенная кнопка: стекло.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Ink.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glass(radius: 18)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Круглая иконка-кнопка.
struct CircleIconStyle: ButtonStyle {
    var size: CGFloat = 40
    var tint: Color = Ink.secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Мелочи

/// Пилюля состояния.
struct Pill: View {
    let text: String
    var color: Color = Ink.secondary
    var icon: String? = nil
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(filled ? .white : color)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background {
            if filled {
                Capsule().fill(color.opacity(0.9))
            } else {
                Capsule().fill(color.opacity(0.14))
            }
        }
        .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 1))
    }
}

/// Разделитель с градиентом.
struct SoftDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.12), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

/// Тактильный отклик.
enum Haptic {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
