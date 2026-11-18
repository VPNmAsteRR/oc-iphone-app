#!/usr/bin/env python3
"""Собирает Sources/ShellCSS.swift из Resources/shell.css.

Править нужно только shell.css — этот файл лишь вшивает те же стили
в код приложения, чтобы они применялись без сетевых запросов.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "Resources/shell.css"
TARGET = ROOT / "Sources/ShellCSS.swift"

HEADER = """import Foundation

/// Оформление настоящего интерфейса OpenCode в духе Gemini.
/// Файл собран из Resources/shell.css — правки вносить туда.
enum ShellCSS {
    static let styles = \"\"\"
"""

FOOTER = """
\"\"\"
}
"""


def main() -> None:
    css = SOURCE.read_text()

    # В многострочной строке Swift особый смысл имеют \\, \"\"\" и \\(
    escaped = (
        css.replace("\\", "\\\\")
        .replace('"""', '\\"\\"\\"')
        .replace("\\(", "\\\\(")
    )

    TARGET.write_text(HEADER + escaped + FOOTER)
    print(f"{TARGET.relative_to(ROOT)}: {len(css)} символов стилей")


if __name__ == "__main__":
    main()
