import SwiftUI

// MARK: - Палитра

enum Palette {
    static let background = Color(red: 0.035, green: 0.043, blue: 0.063)
    static let surface = Color(red: 0.078, green: 0.090, blue: 0.121)
    static let raised = Color(red: 0.110, green: 0.125, blue: 0.165)
    static let text = Color(red: 0.906, green: 0.925, blue: 0.957)
    static let muted = Color(red: 0.549, green: 0.588, blue: 0.663)
    static let violet = Color(red: 0.486, green: 0.361, blue: 1.0)
    static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let mint = Color(red: 0.204, green: 0.878, blue: 0.600)
    static let danger = Color(red: 1.0, green: 0.361, blue: 0.416)

    static var brand: LinearGradient {
        LinearGradient(colors: [violet, cyan],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Живой фон

/// Мягкие светящиеся пятна. Даёт глубину вместо плоской заливки.
struct AuroraBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Palette.background

            Circle()
                .fill(Palette.violet.opacity(0.42))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: drift ? 90 : -60, y: drift ? -180 : -260)

            Circle()
                .fill(Palette.cyan.opacity(0.30))
                .frame(width: 300, height: 300)
                .blur(radius: 130)
                .offset(x: drift ? -110 : 80, y: drift ? 240 : 320)

            Circle()
                .fill(Palette.mint.opacity(0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 120)
                .offset(x: drift ? 120 : -100, y: drift ? 60 : -40)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }
}

// MARK: - Знак приложения

struct BrandMark: View {
    var size: CGFloat = 92
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Palette.brand)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .shadow(color: Palette.violet.opacity(0.55), radius: size * 0.30, y: size * 0.12)
        }
        .frame(width: size, height: size)
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
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.brand)
                    .opacity(enabled ? 1 : 0.35)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Palette.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
                .foregroundStyle(Palette.violet.opacity(0.95))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Пилюля состояния

struct StatusPill: View {
    let text: String
    let color: Color
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}
