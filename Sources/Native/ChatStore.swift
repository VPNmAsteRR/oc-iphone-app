import Foundation
import SwiftUI

/// Состояние нативного приложения и вся работа с сервером.
///
/// Синхронизация держится на одном принципе: телефон не хранит свою правду,
/// он слушает тот же сервер, что и компьютер. Поэтому сообщение, отправленное
/// на ноутбуке, появляется здесь само, и наоборот.
@MainActor
final class ChatStore: ObservableObject {

    // MARK: Состояние экрана

    enum Phase: Equatable {
        case connecting
        case ready
        case unauthorized
        case failed(String)
    }

    @Published private(set) var phase: Phase = .connecting
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var permissions: [PermissionRequest] = []
    @Published var currentSession: Session?
    @Published var draft: String = ""
    /// Идёт ли сейчас ответ и ждём ли первый текст.
    @Published private(set) var isWorking = false
    /// Текст последней ошибки — показывается над полем ввода.
    @Published var errorText: String?
    @Published private(set) var workingSessionID: String?
    /// Сессии, в которых прямо сейчас идёт работа (в том числе с компьютера).
    @Published private(set) var activeSessions: Set<String> = []
    /// Живой текст ответа до того, как сервер его сохранил.
    @Published private(set) var streamingText: String = ""
    @Published private(set) var streamingReasoning: String = ""
    @Published private(set) var agents: [AgentInfo] = []
    @Published private(set) var models: [ModelInfo] = []
    @Published var searchText: String = ""

    /// Подключение из настроек.
    var connection: Connection { ConnectionStore().connection }

    // MARK: Внутреннее

    private let api = APIClient()
    private var streamTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    private var polling: Task<Void, Never>?
    private var lastReload = Date.distantPast
    private var reconnectAttempt = 0

    // MARK: Запуск

    func start() async {
        guard let url = connection.url else {
            phase = .failed("Адрес сервера не задан")
            return
        }
        api.configure(base: url,
                      user: connection.username,
                      password: connection.password)
        await connect()
    }

    func restart() {
        stop()
        phase = .connecting
        Task { await connect() }
    }

    /// Ограниченное время на подключение: если сервер молчит,
    /// показываем ошибку, а не бесконечную заставку.
    private func withTimeout(_ seconds: Double,
                             _ operation: @escaping () async throws -> String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw APIError.transport("Сервер не ответил за \(Int(seconds)) секунд")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func connect() async {
        do {
            _ = try await withTimeout(14) { try await self.api.probe() }
            phase = .ready
            await loadSessions()
            await loadAgentsAndModels()
            openEventStream()
            startPolling()
        } catch let error as APIError {
            if case .unauthorized = error {
                phase = .unauthorized
            } else {
                phase = .failed(error.localizedDescription)
            }
        } catch is CancellationError {
            phase = .failed("Подключение прервано. Попробуй ещё раз.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        streamTask?.cancel(); streamTask = nil
        reloadTask?.cancel(); reloadTask = nil
        polling?.cancel(); polling = nil
    }

    // MARK: Список сессий

    func loadSessions() async {
        do {
            let envelope: Envelope<[Session]> = try await api.get("/api/session")
            sessions = envelope.data
                .sorted { $0.date > $1.date }
        } catch {
            // Список не критичен: соединение покажет поток событий.
        }
    }

    private func loadAgentsAndModels() async {
        if let envelope: Envelope<[AgentInfo]> = try? await api.get("/api/agent") {
            agents = envelope.data
        }
        if let envelope: Envelope<[ModelInfo]> = try? await api.get("/api/model") {
            models = envelope.data
        }
    }

    var filteredSessions: [Session] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return sessions }
        return sessions.filter {
            $0.displayTitle.lowercased().contains(query) ||
            $0.projectName.lowercased().contains(query)
        }
    }

    // MARK: Открыть сессию

    func open(_ session: Session) async {
        currentSession = session
        messages = []
        streamingText = ""
        streamingReasoning = ""
        permissions = []
        isWorking = false
        guard !session.isDraft else { return }
        await loadMessages(for: session.id)
    }

    func close() {
        currentSession = nil
        messages = []
        streamingText = ""
        streamingReasoning = ""
    }

    func loadMessages(for sessionID: String) async {
        do {
            let envelope: Envelope<[ChatMessage]> =
                try await api.get("/api/session/\(sessionID)/message")
            guard currentSession?.id == sessionID else { return }

            // Служебные записи не нужны, но по ним видно, идёт ли работа.
            let visible = envelope.data.filter(\.isVisible)
            messages = visible

            // Если сервер уже отдал ответ целиком — живой текст не нужен.
            if let last = visible.last, last.isAssistant,
               last.time?.completed != nil {
                streamingText = ""
                isWorking = false
            }
            await loadPermissions(for: sessionID)
        } catch {
            // Тихо: поток событий всё равно принесёт новое.
        }
    }

    private func loadPermissions(for sessionID: String) async {
        if let envelope: Envelope<[PermissionRequest]> =
            try? await api.get("/api/session/\(sessionID)/permission") {
            permissions = envelope.data
        }
    }

    // MARK: Отправка

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var sessionID = currentSession?.id

        // Нет открытой сессии или она ещё черновик — создаём настоящую.
        if sessionID == nil || (currentSession?.isDraft ?? true) {
            sessionID = await createSession(title: Self.title(from: text))
        }
        guard let sessionID else { return }

        draft = ""
        errorText = nil
        streamingText = ""
        streamingReasoning = ""
        isWorking = true
        workingSessionID = sessionID

        do {
            _ = try await api.send("POST",
                                   "/api/session/\(sessionID)/prompt",
                                   body: PromptBody(text: text))
            // Сообщение пользователя показываем сразу, не дожидаясь сервера.
            await loadMessages(for: sessionID)
        } catch {
            isWorking = false
            errorText = (error as? APIError)?.localizedDescription
                ?? error.localizedDescription
        }
    }

    // MARK: Модель и агент

    /// Сменить модель у текущей сессии.
    func select(model: ModelInfo) async {
        guard let session = currentSession, !session.isDraft else { return }
        struct Ref: Encodable {
            let id: String
            let providerID: String
        }
        struct Body: Encodable {
            let model: Ref
        }
        _ = try? await api.send(
            "POST",
            "/api/session/\(session.id)/model",
            body: Body(model: Ref(id: model.modelID ?? model.id,
                                  providerID: model.providerID))
        )
        await loadSessions()
    }

    /// Сменить режим работы (агента).
    func select(agent: AgentInfo) async {
        guard let session = currentSession, !session.isDraft else { return }
        struct Body: Encodable { let agent: String }
        _ = try? await api.send("POST",
                                "/api/session/\(session.id)/agent",
                                body: Body(agent: agent.id))
        await loadSessions()
        if let refreshed = sessions.first(where: { $0.id == session.id }) {
            currentSession = refreshed
        }
    }

    /// Удалить сессию.
    func delete(_ session: Session) async {
        guard !session.isDraft else { return }
        _ = try? await api.send("DELETE", "/api/session/\(session.id)")
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            currentSession = nil
        }
    }

    func stopGeneration() async {
        guard let sessionID = workingSessionID ?? currentSession?.id else { return }
        _ = try? await api.send("POST", "/api/session/\(sessionID)/interrupt")
        isWorking = false
    }

    /// Новая сессия: открываем пустой чат, а сама сессия создастся
    /// при первом сообщении — так на компьютере не появляется мусор.
    func newSession() async {
        currentSession = Session.draft
        messages = []
        streamingText = ""
        streamingReasoning = ""
        permissions = []
        isWorking = false
        draft = ""
    }

    private func createSession(title: String) async -> String? {
        struct Body: Encodable {
            let title: String
            let location: [String: String]?
        }
        struct Created: Decodable {
            let data: Session
        }
        do {
            // Локацию не задаём — сервер возьмёт последний проект,
            // тот же, с которым работает компьютер.
            let created: Created = try await api.post(
                "/api/session",
                body: Body(title: title, location: nil)
            )
            currentSession = created.data
            await loadSessions()
            return created.data.id
        } catch {
            return nil
        }
    }

    /// Повторить последнее сообщение пользователя (после обрыва связи).
    func retryLast() async {
        guard let last = messages.last(where: { $0.isUser }) else { return }
        let text = last.userText
        guard !text.isEmpty else { return }
        draft = text
        await send()
    }

    // MARK: Разрешения

    func reply(_ permission: PermissionRequest, decision: String) async {
        guard let sessionID = permission.sessionID ?? currentSession?.id else { return }
        struct Body: Encodable { let decision: String }
        _ = try? await api.send(
            "POST",
            "/api/session/\(sessionID)/permission/\(permission.id)/reply",
            body: Body(decision: decision)
        )
        permissions.removeAll { $0.id == permission.id }
    }

    // MARK: Живой поток

    private func openEventStream() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    for try await event in self.api.events() {
                        await self.handle(event)
                    }
                    // Поток закрылся штатно — переподключаемся.
                } catch {
                    if Task.isCancelled { return }
                }
                if Task.isCancelled { return }
                // Пауза перед переподключением, с ростом задержки.
                let delay = min(0.6 * Double(self.reconnectAttempt + 1), 4)
                self.reconnectAttempt = min(self.reconnectAttempt + 1, 6)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func handle(_ event: ServerEvent) async {
        reconnectAttempt = 0
        let sessionID = currentSession?.id

        switch event.type {
        case "session.text.delta":
            guard event.data?.sessionID == sessionID else { return }
            streamingText += event.data?.delta ?? ""
            isWorking = true

        case "session.text.started":
            guard event.data?.sessionID == sessionID else { return }
            streamingText = ""
            isWorking = true

        case "session.text.ended":
            guard event.data?.sessionID == sessionID else { return }
            if let full = event.data?.text { streamingText = full }
            scheduleReload()

        case "session.reasoning.delta":
            guard event.data?.sessionID == sessionID else { return }
            streamingReasoning += event.data?.delta ?? ""

        case "session.reasoning.started":
            guard event.data?.sessionID == sessionID else { return }
            streamingReasoning = ""

        case "session.execution.started":
            if let id = event.data?.sessionID {
                activeSessions.insert(id)
            }
            guard event.data?.sessionID == sessionID else { return }
            isWorking = true
            workingSessionID = event.data?.sessionID

        case "session.execution.succeeded", "session.execution.failed",
             "session.execution.interrupted":
            if let id = event.data?.sessionID {
                activeSessions.remove(id)
            }
            guard event.data?.sessionID == sessionID else { return }
            isWorking = false
            streamingReasoning = ""
            scheduleReload()

        case "session.step.ended", "session.step.streamed":
            scheduleReload()

        case "permission.asked":
            scheduleReload()

        case "session.inbox.enqueued":
            if let id = event.data?.sessionID {
                activeSessions.insert(id)
            }
            scheduleReload()
            await loadSessions()

        case "session.created", "session.deleted", "session.updated",
             "session.archived", "session.moved":
            scheduleReload()
            await loadSessions()

        default:
            break
        }
    }

    /// Перезагрузка ленты с задержкой, чтобы не дёргать сервер на каждую букву.
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, let self else { return }
            guard let sessionID = self.currentSession?.id else { return }
            await self.loadMessages(for: sessionID)
            if !self.isWorking {
                self.streamingText = ""
            }
        }
    }

    /// Страховка: раз в несколько секунд сверяемся с сервером,
    /// даже если поток событий молчит (например, после сворачивания).
    private func startPolling() {
        polling?.cancel()
        polling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard let session = self.currentSession, !session.isDraft else { continue }
                if !self.isWorking {
                    await self.loadMessages(for: session.id)
                }
            }
        }
    }

    /// После возврата из фона: переподключиться и обновить всё.
    func refreshFromBackground() async {
        openEventStream()
        await loadSessions()
        if let sessionID = currentSession?.id {
            await loadMessages(for: sessionID)
        }
    }
}

// MARK: - Мелочи

extension ChatStore {
    /// Короткое имя сессии по первой фразе.
    static func title(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 46 { return cleaned }
        let cut = cleaned.prefix(46)
        if let space = cut.lastIndex(of: " ") {
            return String(cut[..<space]) + "…"
        }
        return String(cut) + "…"
    }
}

// MARK: - Тела запросов

private struct PromptBody: Encodable {
    let text: String
}
