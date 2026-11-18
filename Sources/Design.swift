import SwiftUI
import UIKit

// MARK: - Палитра (в духе Gemini: чёрный + синее свечение)

enum Palette {
    /// Основа — почти чистый чёрный, как в Gemini.
    static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let surface = Color(red: 0.055, green: 0.058, blue: 0.075)
    static let raised = Color(red: 0.086, green: 0.090, blue: 0.114)
    static let text = Color(red: 0.949, green: 0.957, blue: 0.973)
    static let muted = Color(red: 0.600, green: 0.627, blue: 0.690)

    // Фирменные цвета
    static let blue = Color(red: 0.259, green: 0.522, blue: 0.957)     // #4285F4
    static let indigo = Color(red: 0.420, green: 0.396, blue: 1.0)     // #6B65FF
    static let violet = Color(red: 0.608, green: 0.447, blue: 1.0)     // #9B72FF
    static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let mint = Color(red: 0.204, green: 0.878, blue: 0.600)
    static let danger = Color(red: 1.0, green: 0.361, blue: 0.416)

    /// Главный акцентный градиент.
    static var brand: LinearGradient {
        LinearGradient(colors: [blue, indigo, violet],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Градиент для текста-заголовка.
    static var brandText: LinearGradient {
        LinearGradient(colors: [Color(red: 0.60, green: 0.78, blue: 1.0), violet],
                       startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Живой фон

/// Чёрный фон с плавно дышащим синим свечением снизу — как в Gemini.
struct AuroraBackground: View {
    @State private var breathe = false
    @State private var drift = false

    var body: some View {
        ZStack {
            Palette.background

            // Основное свечение снизу — визитная карточка Gemini.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.blue.opacity(0.55), Palette.blue.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .scaleEffect(breathe ? 1.16 : 0.92)
                .offset(y: 330)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.indigo.opacity(0.40), Palette.indigo.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: 230
                    )
                )
                .frame(width: 460, height: 460)
                .scaleEffect(breathe ? 0.9 : 1.12)
                .offset(x: drift ? 150 : 90, y: 180)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.violet.opacity(0.30), Palette.violet.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .scaleEffect(breathe ? 1.05 : 0.88)
                .offset(x: drift ? -140 : -80, y: -220)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: breathe)
        .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: drift)
        .onAppear {
            breathe = true
            drift = true
        }
    }
}

// MARK: - 3D знак

/// Знак приложения с настоящим объёмом: наклоняется от касания и медленно
/// покачивается сам, с бликом и тенью.
struct BrandMark3D: View {
    var size: CGFloat = 100

    @State private var tiltX: Double = -8
    @State private var tiltY: Double = 10
    @State private var idle = false
    @State private var pressed = false

    var body: some View {
        ZStack {
            // Свечение под знаком
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(Palette.indigo.opacity(0.55))
                .frame(width: size, height: size)
                .blur(radius: size * 0.34)
                .scaleEffect(1.06)

            // Основная плитка
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.62, blue: 1.0),
                            Palette.indigo,
                            Color(red: 0.55, green: 0.30, blue: 0.95)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Блик стекла
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.02)],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .blendMode(.overlay)
                        .padding(1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                )
                .shadow(color: Palette.indigo.opacity(0.55), radius: 26, y: 14)
        }
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: pressed)
        .animation(.easeInOut(duration: 1.5), value: tiltX)
        .animation(.easeInOut(duration: 1.5), value: tiltY)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    pressed = true
                    tiltY = Double(value.translation.width / 5)
                    tiltX = Double(-value.translation.height / 5)
                }
                .onEnded { _ in
                    pressed = false
                    withAnimation(.easeInOut(duration: 1.2)) {
                        tiltX = idle ? 8 : -8
                        tiltY = idle ? -12 : 12
                    }
                }
        )
        .task {
            // Медленное «дыхание» объёма.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                idle.toggle()
                withAnimation(.easeInOut(duration: 2.0)) {
                    tiltX = idle ? 8 : -8
                    tiltY = idle ? -12 : 12
                }
            }
        }
    }
}

// MARK: - Стеклянная карточка

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Кнопки

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.brand)
                    .opacity(enabled ? 1 : 0.35)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Palette.indigo.opacity(enabled ? 0.5 : 0), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Поля ввода

struct FieldCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                content
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Palette.blue.opacity(0.75), Palette.violet.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .opacity(0.35)
        )
    }
}
