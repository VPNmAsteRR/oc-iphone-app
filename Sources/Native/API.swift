import Foundation

// MARK: - Ошибки

enum APIError: LocalizedError {
    case badURL
    case unauthorized
    case http(Int)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Неверный адрес сервера"
        case .unauthorized:
            return "Сервер не принял пароль"
        case let .http(code):
            return "Сервер ответил ошибкой \(code)"
        case let .transport(message):
            return "Нет связи: \(message)"
        case let .decoding(message):
            return "Непонятный ответ сервера: \(message)"
        }
    }
}

// MARK: - Клиент

/// Клиент настоящего API OpenCode.
///
/// Ходит в тот же сервер, что и компьютер, поэтому всё, что сделано
/// на телефоне, сразу видно на ноутбуке и наоборот.
final class APIClient {
    private let session: URLSession
    private let lock = NSLock()
    private var _base: URL?
    private var _user = ""
    private var _password = ""

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func configure(base: URL, user: String, password: String) {
        lock.lock()
        _base = base
        _user = user
        _password = password
        lock.unlock()
    }

    private var credentials: (URL, String, String)? {
        lock.lock()
        defer { lock.unlock() }
        guard let base = _base else { return nil }
        return (base, _user, _password)
    }

    private func authorized(_ request: inout URLRequest) {
        guard let (_, user, password) = credentials else { return }
        let token = Data("\(user):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
    }

    private func makeURL(_ path: String, query: [String: String] = [:]) throws -> URL {
        guard let (base, _, _) = credentials else { throw APIError.badURL }
        let trimmed = base.absoluteString.hasSuffix("/")
            ? String(base.absoluteString.dropLast())
            : base.absoluteString
        guard var components = URLComponents(string: trimmed + path) else {
            throw APIError.badURL
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.badURL }
        return url
    }

    // MARK: Запросы

    @discardableResult
    func send(_ method: String, _ path: String,
              query: [String: String] = [:],
              body: Encodable? = nil) async throws -> Data {
        var request = URLRequest(url: try makeURL(path, query: query))
        request.httpMethod = method
        authorized(&request)

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response, data: data)
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:],
                           as type: T.Type = T.self) async throws -> T {
        let data = try await send("GET", path, query: query)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil,
                            as type: T.Type = T.self) async throws -> T {
        let data = try await send("POST", path, body: body)
        if data.isEmpty, let empty = EmptyResponse() as? T { return empty }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw APIError.unauthorized
        default:
            throw APIError.http(http.statusCode)
        }
    }

    // MARK: Проверка связи

    /// Короткая проверка: отвечает ли сервер и принимает ли пароль.
    func probe() async throws -> String {
        let info: InfoResponse = try await get("/api/info")
        return info.version
    }

    // MARK: Поток событий

    /// Живой поток событий сервера. Возвращает строки `data:` по мере поступления.
    func events() -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: try makeURL("/api/event"))
                    authorized(&request)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 3600

                    let (bytes, response) = try await session.bytes(for: request)
                    try validate(response, data: Data())

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty, let data = payload.data(using: .utf8) else { continue }
                        if let event = try? JSONDecoder().decode(ServerEvent.self, from: data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Вспомогательные типы

struct EmptyResponse: Decodable {}

/// Нужен, чтобы принимать `Encodable` в общем виде.
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeClosure = { encoder in try wrapped.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

struct InfoResponse: Decodable {
    let version: String
}

/// Конверт ответа: сервер заворачивает списки в `data`.
struct Envelope<T: Decodable>: Decodable {
    let data: T
}

// MARK: - Событие сервера

struct ServerEvent: Decodable {
    let id: String?
    let type: String
    let data: EventData?

    struct EventData: Decodable {
        let sessionID: String?
        let assistantMessageID: String?
        let ordinal: Int?
        let delta: String?
        let text: String?
        let inboxID: String?
        let finish: String?

        private enum CodingKeys: String, CodingKey {
            case sessionID, assistantMessageID, ordinal, delta, text, inboxID, finish
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
            assistantMessageID = try container.decodeIfPresent(String.self, forKey: .assistantMessageID)
            ordinal = try container.decodeIfPresent(Int.self, forKey: .ordinal)
            delta = try container.decodeIfPresent(String.self, forKey: .delta)
            text = try container.decodeIfPresent(String.self, forKey: .text)
            inboxID = try container.decodeIfPresent(String.self, forKey: .inboxID)
            finish = try container.decodeIfPresent(String.self, forKey: .finish)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        data = try? container.decodeIfPresent(EventData.self, forKey: .data)
    }
}
