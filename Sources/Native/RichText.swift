import SwiftUI
import UIKit

// MARK: - Разметка

/// Лёгкий рендер markdown: заголовки, списки, код, цитаты.
///
/// Не тянет внешних зависимостей — собирает блоки сам, чтобы текст
/// выглядел аккуратно и одинаково на всех версиях iOS.
struct RichText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Block.parse(text)) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block.kind {
        case .code:
            CodeBlock(code: block.text, language: block.language)

        case .heading:
            Text(inline(block.text))
                .font(.system(size: block.level <= 2 ? 18 : 16, weight: .semibold))
                .foregroundStyle(Ink.primary)
                .padding(.top, 4)

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Circle()
                    .fill(Ink.tertiary)
                    .frame(width: 4, height: 4)
                    .offset(y: -4)
                Text(inline(block.text))
                    .font(.system(size: 15.5))
                    .foregroundStyle(Ink.primary.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .numbered:
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(block.marker)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Ink.azure.opacity(0.9))
                    .frame(minWidth: 16, alignment: .trailing)
                Text(inline(block.text))
                    .font(.system(size: 15.5))
                    .foregroundStyle(Ink.primary.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .quote:
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(Ink.indigo.opacity(0.6))
                    .frame(width: 3)
                Text(inline(block.text))
                    .font(.system(size: 15))
                    .foregroundStyle(Ink.secondary)
                    .italic()
            }

        case .rule:
            SoftDivider().padding(.vertical, 4)

        case .paragraph:
            Text(inline(block.text))
                .font(.system(size: 15.5))
                .foregroundStyle(Ink.primary.opacity(0.94))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Инлайн-разметка: жирный, курсив, код, ссылки.
    private func inline(_ raw: String) -> AttributedString {
        guard let parsed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(raw)
        }
        var result = parsed
        let spans = result.runs.map { (range: $0.range, intent: $0.inlinePresentationIntent, link: $0.link) }
        for span in spans {
            if let intent = span.intent {
                if intent.contains(.code) {
                    result[span.range].font = .system(size: 14, design: .monospaced)
                    result[span.range].foregroundColor = Ink.orchid
                }
            }
            if span.link != nil {
                result[span.range].foregroundColor = Ink.azure
            }
        }
        return result
    }
}

// MARK: - Блок

struct Block: Identifiable {
    enum Kind: Equatable {
        case paragraph, heading, bullet, numbered, quote, code, rule
    }

    let id = UUID()
    let kind: Kind
    var text: String = ""
    var level: Int = 1
    var marker: String = ""
    var language: String = ""

    /// Разбирает текст на блоки.
    static func parse(_ source: String) -> [Block] {
        var blocks: [Block] = []
        let lines = source.components(separatedBy: .newlines)
        var index = 0

        func flush(_ buffer: inout [String]) {
            let joined = buffer.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(Block(kind: .paragraph, text: joined))
            }
            buffer.removeAll(keepingCapacity: true)
        }

        var paragraph: [String] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Блок кода
            if trimmed.hasPrefix("```") {
                flush(&paragraph)
                let language = String(trimmed.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                index += 1
                while index < lines.count,
                      !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[index])
                    index += 1
                }
                index += 1
                blocks.append(Block(kind: .code,
                                    text: body.joined(separator: "\n"),
                                    language: language))
                continue
            }

            if trimmed.isEmpty {
                flush(&paragraph)
                index += 1
                continue
            }

            // Горизонтальная линия
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flush(&paragraph)
                blocks.append(Block(kind: .rule))
                index += 1
                continue
            }

            // Заголовок
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                if hashes <= 6, trimmed.dropFirst(hashes).hasPrefix(" ") {
                    flush(&paragraph)
                    let body = String(trimmed.dropFirst(hashes))
                        .trimmingCharacters(in: .whitespaces)
                    blocks.append(Block(kind: .heading, text: body, level: hashes))
                    index += 1
                    continue
                }
            }

            // Цитата
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                flush(&paragraph)
                var body: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    body.append(String(candidate.dropFirst(1))
                        .trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(Block(kind: .quote, text: body.joined(separator: " ")))
                continue
            }

            // Маркированный список
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                flush(&paragraph)
                blocks.append(Block(kind: .bullet,
                                    text: String(trimmed.dropFirst(2))))
                index += 1
                continue
            }

            // Нумерованный список
            if let match = Self.numbered(trimmed) {
                flush(&paragraph)
                blocks.append(Block(kind: .numbered,
                                    text: match.text,
                                    marker: match.marker))
                index += 1
                continue
            }

            // Обычная строка
            paragraph.append(line)
            index += 1
        }

        flush(&paragraph)
        return blocks
    }

    /// Разбирает «1. текст» и «1) текст».
    static func numbered(_ line: String) -> (marker: String, text: String)? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return (String(digits),
                String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Код

struct CodeBlock: View {
    let code: String
    let language: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if !language.isEmpty {
                    Text(language.lowercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    Haptic.success()
                    withAnimation(Motion.snappy) { copied = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation(Motion.snappy) { copied = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Скопировано" : "Копировать")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copied ? Ink.mint : Ink.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.035))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Ink.primary.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Ink.void.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
