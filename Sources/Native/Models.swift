import Foundation

// MARK: - Сессия

struct Session: Decodable, Identifiable, Hashable {
    let id: String
    let title: String?
    let agent: String?
    let model: SessionModel?
    let time: Time?
    let location: Location?

    struct SessionModel: Decodable, Hashable {
        let id: String
        let providerID: String
        let variant: String?
    }

    struct Time: Decodable, Hashable {
        let created: Double?
        let updated: Double?
        let idle: Double?
        let viewed: Double?
    }

    struct Location: Decodable, Hashable {
        let directory: String?
    }

    var displayTitle: String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без названия" : trimmed
    }

    var projectName: String {
        guard let directory = location?.directory, !directory.isEmpty else {
            return "Проект"
        }
        return (directory as NSString).lastPathComponent
    }

    /// Когда сессия последний раз менялась.
    var date: Date {
        let stamp = time?.updated ?? time?.created ?? 0
        return Date(timeIntervalSince1970: stamp / 1000)
    }

    static func == (lhs: Session, rhs: Session) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Пустая заготовка для нового диалога: настоящая сессия создастся
    /// на сервере при первом сообщении.
    static var draft: Session {
        Session(id: "draft-\(UUID().uuidString)",
                title: "Новый диалог",
                agent: nil,
                model: nil,
                time: nil,
                location: nil)
    }

    var isDraft: Bool { id.hasPrefix("draft-") }
}

// MARK: - Сообщения

struct ChatMessage: Decodable, Identifiable {
    let id: String
    let type: String
    let time: Time?
    let text: String?
    let agent: String?
    let model: MessageModel?
    let content: [Part]?
    let metadata: Metadata?

    struct Time: Decodable {
        let created: Double?
        let completed: Double?
    }

    struct MessageModel: Decodable {
        let id: String
        let providerID: String
    }

    struct Metadata: Decodable {
        let displayText: String?
        let agent: String?
    }

    var isUser: Bool { type == "user" }
    var isAssistant: Bool { type == "assistant" }
    /// Служебные записи (`idle`) в ленте не нужны.
    var isVisible: Bool { isUser || isAssistant }

    /// Текст сообщения пользователя.
    var userText: String {
        metadata?.displayText ?? text ?? ""
    }

    var created: Date {
        Date(timeIntervalSince1970: (time?.created ?? 0) / 1000)
    }
}

// MARK: - Части сообщения

struct Part: Decodable, Identifiable {
    let type: String
    let text: String?
    let name: String?
    let id: String?
    let state: ToolState?

    var identity: String {
        id ?? UUID().uuidString
    }

    var isText: Bool { type == "text" }
    var isReasoning: Bool { type == "reasoning" }
    var isTool: Bool { type == "tool" }

    /// Название инструмента по-русски.
    var displayName: String {
        switch name ?? "" {
        case "bash": return "Команда"
        case "read": return "Чтение"
        case "write": return "Запись"
        case "edit": return "Правка"
        case "glob": return "Поиск файлов"
        case "grep": return "Поиск по тексту"
        case "list": return "Список файлов"
        case "webfetch": return "Загрузка страницы"
        case "websearch": return "Поиск в интернете"
        case "task": return "Задача"
        case "execute": return "Код"
        case "browser.preview", "browser_preview": return "Просмотр"
        default: return (name ?? "Инструмент").capitalized
        }
    }
}

struct ToolState: Decodable {
    let status: String?
    let title: String?
    let input: JSONValue?
    let content: [Part]?
    let metadata: JSONValue?

    var isRunning: Bool { status == "running" || status == "pending" }
    var isFailed: Bool { status == "error" || status == "failed" }

    /// Первое осмысленное описание действия.
    var summary: String? {
        if let title, !title.isEmpty { return title }
        guard let input else { return nil }
        if case let .object(dict) = input {
            for key in ["command", "path", "filePath", "pattern", "query", "url", "description"] {
                if case let .string(value)? = dict[key], !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }
}

// MARK: - Универсальное значение JSON

/// Нужен, чтобы разбирать произвольные данные инструментов
/// без жёстких моделей под каждый инструмент.
enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}

// MARK: - Разрешение

struct PermissionRequest: Decodable, Identifiable {
    let id: String
    let sessionID: String?
    let action: String?
    let resources: [String]?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case id, sessionID, action, resources, message, resource, description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        message = try container.decodeIfPresent(String.self, forKey: .message)

        if let list = try container.decodeIfPresent([String].self, forKey: .resources) {
            resources = list
        } else if let single = try container.decodeIfPresent(String.self, forKey: .resource) {
            resources = [single]
        } else {
            resources = nil
        }

        if message == nil {
            _messageFallback = try container.decodeIfPresent(String.self, forKey: .description)
        } else {
            _messageFallback = nil
        }
    }

    private var _messageFallback: String?

    /// Что именно просят: путь, команда, адрес.
    var resource: String? {
        if let resources, !resources.isEmpty {
            return resources.joined(separator: "\n")
        }
        return nil
    }

    /// Заголовок карточки.
    var description: String? { message ?? _messageFallback }

    var title: String {
        let value = description ?? action ?? "Запрос"
        return value.isEmpty ? "Запрос доступа" : value
    }
}

// MARK: - Агент и модель

struct AgentInfo: Decodable, Identifiable {
    let id: String
    let name: String?
    let description: String?

    var title: String {
        if let name, !name.isEmpty { return name }
        switch id {
        case "build": return "Build"
        case "general": return "General"
        case "explore": return "Explore"
        case "plan": return "Plan"
        default: return id.prefix(1).uppercased() + id.dropFirst()
        }
    }

    /// Понятное описание вместо английского из сервера.
    var subtitle: String {
        switch id {
        case "build": return "Пишет код и меняет файлы"
        case "general": return "Разные задачи: поиск, разбор, решения"
        case "explore": return "Быстро изучает проект и находит нужное"
        case "plan": return "Продумывает план, ничего не меняя"
        default:
            let text = (description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Режим работы" : text
        }
    }
}

struct ModelInfo: Decodable {
    let id: String
    let modelID: String?
    let providerID: String
    let name: String?
    let variants: [Variant]?

    struct Variant: Decodable {
        let id: String
    }

    var title: String { name ?? modelID ?? id }
    var key: String { "\(providerID)/\(modelID ?? id)" }
}
