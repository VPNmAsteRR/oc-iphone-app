import Foundation

/// Оформление настоящего интерфейса OpenCode в духе Gemini.
/// Файл собран из Resources/shell.css — правки вносить туда.
enum ShellCSS {
    static let styles = """
/* Оформление настоящего интерфейса OpenCode в духе Gemini.

   Перекрашиваем через штатные переменные темы, поэтому все состояния
   (наведение, выбор, ошибки, диффы) остаются рабочими.

   Важно: интерфейс использует набор --v2-*, а его стили подключаются позже
   наших, поэтому значения задаются с !important.

   Классы oc-* ставит скрипт разметки (см. WebView.swift): он находит
   элементы по смыслу, потому что сгенерированные имена Tailwind меняются
   от сборки к сборке. */

:root {
  color-scheme: dark;

  /* ---- Фон: глубокий чёрный с холодным подтоном ---- */
  --v2-background-bg-deep: #0b0b0c !important;
  --v2-background-bg-base: #131314 !important;
  --v2-background-bg-layer-01: #1e1f20 !important;
  --v2-background-bg-layer-02: #282a2c !important;
  --v2-background-bg-layer-03: #303134 !important;
  --v2-background-bg-layer-04: #3c4043 !important;

  /* Акцент — синий Gemini */
  --v2-background-bg-accent: #4c8df6 !important;
  --v2-background-bg-contrast: #6b7385 !important;
  --v2-background-bg-button-neutral: rgba(255, 255, 255, 0.06) !important;
  --v2-background-bg-code-path: rgba(66, 133, 244, 0.14) !important;

  /* ---- Текст: белый, серый, приглушённый ---- */
  --v2-text-text-base: #e3e3e3 !important;
  --v2-text-text-contrast: #ffffff !important;
  --v2-text-text-muted: #9aa0a6 !important;
  --v2-text-text-faint: #6e7276 !important;
  --v2-text-text-accent: #8ab4f8 !important;
  --v2-text-text-accent-hover: #b3cdff !important;
  --v2-text-text-code-accent: #8ab4f8 !important;
  --v2-text-text-code-path: #b3cdff !important;
  --v2-text-text-inverse: #05060a !important;

  /* ---- Границы: тонкие, светящиеся ---- */
  --v2-border-border-base: rgba(255, 255, 255, 0.10) !important;
  --v2-border-border-muted: rgba(255, 255, 255, 0.06) !important;
  --v2-border-border-strong: rgba(255, 255, 255, 0.20) !important;
  --v2-border-border-focus: #7c6bff !important;

  /* ---- Иконки ---- */
  --v2-icon-icon-base: #c8cfdc !important;
  --v2-icon-icon-muted: #8b93a5 !important;
  --v2-icon-icon-faint: #5e6678 !important;
  --v2-icon-icon-contrast: #ffffff !important;
  --v2-icon-icon-accent: #8ab4ff !important;
  --v2-icon-icon-accent-hover: #b3cdff !important;
  --v2-icon-icon-inverse: #05060a !important;

  /* ---- Статусы ---- */
  --v2-state-bg-info: rgba(66, 133, 244, 0.16) !important;
  --v2-state-border-info: rgba(66, 133, 244, 0.55) !important;
  --v2-state-fg-info: #8ab4ff !important;
  --v2-state-bg-success: rgba(46, 160, 67, 0.16) !important;
  --v2-state-border-success: rgba(46, 160, 67, 0.55) !important;
  --v2-state-fg-success: #6fd47e !important;
  --v2-state-bg-warning: rgba(255, 188, 85, 0.16) !important;
  --v2-state-border-warning: rgba(255, 188, 85, 0.55) !important;
  --v2-state-fg-warning: #ffc76b !important;
  --v2-state-bg-danger: rgba(248, 81, 73, 0.16) !important;
  --v2-state-border-danger: rgba(248, 81, 73, 0.55) !important;
  --v2-state-fg-danger: #ff8b84 !important;

  /* ---- Старый набор переменных: тот же вид ---- */
  --background-base: #131314 !important;
  --background-strong: #131314 !important;
  --background-stronger: #0b0b0c !important;
  --background-weak: #1e1f20 !important;
  --text-strong: #e3e3e3 !important;
  --text-stronger: #ffffff !important;
  --text-base: #c3c8d4 !important;
  --text-weak: #9aa0a6 !important;
  --text-weaker: #626b7d !important;
  --text-interactive-base: #8ab4ff !important;
  --icon-base: #9aa3b5 !important;
  --icon-weak-base: #6b7385 !important;
  --icon-strong-base: #eef1f6 !important;
  --icon-interactive-base: #8ab4ff !important;
  --border-base: rgba(255, 255, 255, 0.12) !important;
  --border-weak-base: rgba(255, 255, 255, 0.09) !important;
  --border-weaker-base: rgba(255, 255, 255, 0.06) !important;
  --border-interactive-base: #4285f4 !important;
  --border-interactive-focus: #7c6bff !important;
  --surface-base: rgba(255, 255, 255, 0.045) !important;
  --surface-base-hover: rgba(255, 255, 255, 0.075) !important;
  --surface-weak: rgba(255, 255, 255, 0.035) !important;
  --surface-raised-base: rgba(255, 255, 255, 0.06) !important;
  --surface-float-base: #1e1f20 !important;
  --surface-interactive-base: rgba(66, 133, 244, 0.16) !important;
  --markdown-link-text: #8ab4ff !important;
  --markdown-text: #eef1f6 !important;

  /* Диффы */
  --surface-diff-add-base: rgba(46, 160, 67, 0.18) !important;
  --surface-diff-add-weak: rgba(46, 160, 67, 0.13) !important;
  --surface-diff-delete-base: rgba(248, 81, 73, 0.18) !important;
  --surface-diff-delete-weak: rgba(248, 81, 73, 0.13) !important;
  --text-diff-add-base: #6fd47e !important;
  --text-diff-delete-base: #ff8b84 !important;
  --icon-diff-add-base: #6fd47e !important;
  --icon-diff-delete-base: #ff8b84 !important;
  --icon-diff-modified-base: #ffbc55 !important;
}

/* ---- Фон: ровный тёмный, как в Gemini ---- */
html {
  background: #0b0b0c !important;
}

body {
  background-color: #0b0b0c !important;
  background-image: none !important;
  color: #e3e3e3;
  -webkit-font-smoothing: antialiased;
  letter-spacing: -0.011em;
  overscroll-behavior: none;
  -webkit-tap-highlight-color: transparent;
}

/* Оболочка приложения рисует свой сплошной фон — убираем, чтобы
   свечение было видно, и заливаем тем же градиентом саму панель. */
.oc-shell-transparent,
[class*="bg-v2-background-bg-deep"] {
  background-color: transparent !important;
  background-image: none !important;
}

/* ---- Основная панель ---- */

.oc-panel {
  border-radius: 20px !important;
  background-color: #131314 !important;
  background-image:
    radial-gradient(ellipse 110% 34% at 50% 104%, rgba(92, 148, 255, 0.16) 0%, rgba(92, 148, 255, 0.05) 45%, rgba(0, 0, 0, 0) 74%),
    radial-gradient(ellipse 60% 22% at 18% 102%, rgba(150, 120, 255, 0.10) 0%, rgba(0, 0, 0, 0) 70%) !important;
  background-repeat: no-repeat !important;
  box-shadow: none !important;
}

/* Мягкое свечение под полем ввода — единственный источник цвета внизу,
   как у Gemini. */

/* ---- Верхняя панель ---- */

.oc-header {
  background: #131314 !important;
  border-bottom: none;
}

.oc-header button {
  border-radius: 12px !important;
  transition: background-color 0.18s ease;
}

/* ---- Вкладки: сегментированный переключатель, как в Gemini ---- */

.oc-tabs,
[data-slot="tabs-v2-list"] {
  background: #1e1f20 !important;
  border: none !important;
  border-radius: 999px !important;
  padding: 4px !important;
  margin: 6px 12px 10px !important;
  height: 44px !important;
  min-height: 44px !important;
  max-height: 44px !important;
  box-shadow: none !important;
}

/* Убираем подчёркивание активной вкладки — в Gemini это заливка */
.oc-tabs [data-slot="tabs-v2-trigger-wrapper"] {
  border-bottom: none !important;
  padding: 0 !important;
}

.oc-tabs [data-slot="tabs-v2-trigger"] {
  border-radius: 999px !important;
  background: transparent !important;
  border: none !important;
  height: 36px !important;
  font-size: 13.5px !important;
  font-weight: 500 !important;
  color: #9aa0a6 !important;
  transition: background-color 0.2s ease, color 0.2s ease;
}

.oc-tabs [data-slot="tabs-v2-trigger"][aria-selected="true"] {
  background: rgba(255, 255, 255, 0.10) !important;
  color: #e3e3e3 !important;
}

/* Индикаторы-полоски внутри вкладок не нужны */
.oc-tabs [data-slot="tabs-v2-trigger-wrapper"] > div[class*="absolute"],
.oc-tabs [class*="tab-indicator"] {
  display: none !important;
}

/* ---- Композер: круглая стеклянная капсула ---- */

.oc-composer {
  position: relative;
  z-index: 1;
  border-radius: 28px !important;
  background: #1e1f20 !important;
  border: none !important;
  box-shadow:
    0 10px 40px rgba(0, 0, 0, 0.35),
    0 0 70px rgba(92, 148, 255, 0.16) !important;
  transition: background-color 0.25s ease, box-shadow 0.25s ease;
}

.oc-composer:focus-within {
  background: #282a2c !important;
}

/* Поле ввода внутри капсулы */
.oc-input {
  padding: 16px 20px 6px !important;
  font-size: 15.5px !important;
  line-height: 1.5 !important;
  letter-spacing: -0.01em;
}

/* Нижняя строка композера: отступ снизу под домашний индикатор */
.oc-composer__bar {
  padding: 2px 8px 8px !important;
  height: auto !important;
  min-height: 44px !important;
}

/* Контейнер композера: прозрачный, чтобы было видно свечение,
   и с местом под домашний индикатор iPhone. Высоту клавиатуры
   считает скрипт разметки и кладёт в --oc-keyboard. */
.oc-composer-wrap {
  position: relative;
  background: transparent !important;
  background-image: none !important;
  padding-bottom: calc(var(--oc-keyboard, 0px) + env(safe-area-inset-bottom, 0px) + 8px) !important;
}

html.oc-typing .oc-composer-wrap {
  transition: padding-bottom 0.22s ease;
}

/* Пока человек печатает, подсказки и нижние панели не мешают. */
html.oc-typing .oc-row {
  animation: none;
}

/* ---- Кнопки в композере ---- */

.oc-chip {
  border-radius: 999px !important;
  background: transparent !important;
  border: none;
  padding: 0 10px !important;
  height: 32px !important;
  transition: background-color 0.18s ease, border-color 0.18s ease;
}

.oc-chip:active {
  background: rgba(255, 255, 255, 0.12) !important;
}

.oc-round {
  border-radius: 999px !important;
  background: transparent !important;
  width: 36px !important;
  height: 36px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  transition: background-color 0.18s ease, transform 0.14s ease;
}

.oc-round:active {
  transform: scale(0.92);
  background: rgba(255, 255, 255, 0.10) !important;
}

/* Кнопка отправки — сине-фиолетовый градиент */
.oc-send {
  border-radius: 999px !important;
  width: 36px !important;
  height: 36px !important;
  min-width: 36px !important;
  padding: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  background: #e3e3e3 !important;
  color: #131314 !important;
  box-shadow: none !important;
  transition: transform 0.16s ease, opacity 0.2s ease, background-color 0.2s ease;
}

.oc-send:active {
  transform: scale(0.92);
  background: #ffffff !important;
}

.oc-send svg {
  color: #131314 !important;
  width: 18px !important;
  height: 18px !important;
}

/* ---- Сообщения ---- */

.oc-row {
  animation: oc-rise 0.35s cubic-bezier(0.22, 1, 0.36, 1) both;
}

@keyframes oc-rise {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: none; }
}

.oc-row p {
  font-size: 15px !important;
  line-height: 1.72 !important;
  letter-spacing: -0.005em;
}

.oc-row h1, .oc-row h2, .oc-row h3 {
  letter-spacing: -0.02em;
  font-weight: 600 !important;
}

.oc-row code {
  border-radius: 7px !important;
  padding: 1px 6px !important;
  background: rgba(255, 255, 255, 0.07) !important;
}

.oc-row pre {
  border-radius: 14px !important;
  border: 1px solid rgba(255, 255, 255, 0.08) !important;
  background: rgba(0, 0, 0, 0.45) !important;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05);
}

/* ---- Общее ---- */

button {
  transition: transform 0.14s ease, background-color 0.18s ease, opacity 0.18s ease;
  -webkit-tap-highlight-color: transparent;
}

/* Поля ввода: 16px, чтобы iOS не зумил экран при фокусе */
textarea, input {
  font-size: max(16px, 1em) !important;
}

/* Подсказки в полях: тот же мягкий серый, что и в остальном тексте */
input::placeholder,
textarea::placeholder,
[contenteditable="true"] [data-placeholder] {
  color: #8e949c !important;
  opacity: 1 !important;
}

/* Поиск на главной: таблетка, как в Gemini */
[class*="search"] input,
input[type="search"] {
  background: transparent !important;
}

::-webkit-scrollbar { width: 0; height: 0; }

@media (prefers-reduced-motion: reduce) {
  .oc-row { animation: none; }
  * { animation-duration: 0.001ms !important; transition-duration: 0.001ms !important; }
}

/* ---- Заголовок сессии: крупный, как в Gemini ---- */

.oc-header button {
  border-radius: 14px !important;
}

.oc-header button > span[class*="truncate"] {
  font-size: 15px !important;
  font-weight: 500 !important;
  letter-spacing: -0.01em;
}

/* ---- Сообщения: воздух и ритм, как в Gemini ---- */

.oc-row {
  padding-top: 18px !important;
}

.oc-row [class*="px-4"],
.oc-row [class*="px-6"] {
  padding-left: 20px !important;
  padding-right: 20px !important;
}

/* Служебные плашки («Использовано N …») делаем тише */
.oc-row [class*="tool-collapsible"] {
  opacity: 0.85;
}

.oc-row [class*="tool-collapsible"] button {
  border-radius: 12px !important;
}

/* Таблицы и списки не выпирают за края */
.oc-row table {
  border-radius: 12px;
  overflow: hidden;
}

.oc-row blockquote {
  border-left: 3px solid rgba(138, 180, 248, 0.5) !important;
  padding-left: 14px !important;
  color: #c4c7c5 !important;
}

/* Выделение текста — в цветах темы */
::selection {
  background: rgba(138, 180, 248, 0.35);
  color: #ffffff;
}

/* ---- Главный экран: список сессий, как в Gemini ---- */

/* Поле поиска — таблетка на поверхности Gemini */
.oc-search {
  border-radius: 999px !important;
  background: #1e1f20 !important;
  border: none !important;
  height: 46px !important;
  padding-left: 12px !important;
  padding-right: 12px !important;
}

.oc-search input {
  font-size: 15px !important;
}

.oc-search input::placeholder {
  color: #9aa0a6 !important;
}

/* Строка сессии: скругление и мягкое наведение вместо вспышки */
[class*="group/session"] {
  border-radius: 14px !important;
  transition: background-color 0.16s ease;
}

[class*="group/session"]:active {
  background: rgba(255, 255, 255, 0.06) !important;
}

/* Заголовки групп («Сегодня», «Вчера») — тише и мельче */
[class*="text-v2-text-text-faint"] {
  font-size: 12px !important;
  font-weight: 500 !important;
  letter-spacing: 0.01em;
  text-transform: none !important;
}

/* Кнопка «Все проекты» — таблетка-обводка */
button[class*="justify-between"] {
  border-radius: 14px !important;
}

"""
}
