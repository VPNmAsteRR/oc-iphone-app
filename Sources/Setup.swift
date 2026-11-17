import SwiftUI
import UIKit

// MARK: - Первичная настройка

struct SetupView: View {
    @EnvironmentObject private var store: ConnectionStore
    @State private var checking = false
    @State private var errorText: String?
    @FocusState private var focused: Field?
    let onDone: () -> Void

    enum Field { case url, user, password }

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 14) {
                        BrandMark(size: 84)
                        VStack(spacing: 6) {
                            Text("OpenCode")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.text)
                            Text("Тот же интерфейс, что на ноутбуке")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(.top, 42)

                    VStack(spacing: 10) {
                        FieldCard(title: "Адрес сервера", systemImage: "globe") {
                            TextField("https://…", text: $store.connection.baseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .focused($focused, equals: .url)
                                .submitLabel(.next)
                                .onSubmit { focused = .user }
                        }

                        FieldCard(title: "Логин", systemImage: "person") {
                            TextField("opencode", text: $store.connection.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focused, equals: .user)
                                .submitLabel(.next)
                                .onSubmit { focused = .password }
                        }

                        FieldCard(title: "Пароль", systemImage: "key") {
                            SecureField("••••••••", text: $store.connection.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focused, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { Task { await check() } }
                        }
                    }

                    if let errorText {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                            Text(errorText)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Palette.danger)
                        .padding(13)
                        .background(Palette.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Palette.danger.opacity(0.28), lineWidth: 1)
                        )
                    }

                    Button {
                        focused = nil
                        Task { await check() }
                    } label: {
                        HStack(spacing: 9) {
                            if checking {
                                ProgressView().tint(.white).scaleEffect(0.85)
                            }
                            Text(checking ? "Проверяю связь…" : "Подключиться")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: store.connection.isComplete && !checking))
                    .disabled(checking || !store.connection.isComplete)

                    Text("Пароль хранится только в связке ключей iPhone.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted.opacity(0.8))
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 22)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func check() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        guard let url = store.connection.url else { errorText = "Неверный адрес"; return }
        do {
            _ = try await ConnectionProbe.info(url: url,
                                               username: store.connection.username,
                                               password: store.connection.password)
            errorText = nil
            onDone()
        } catch let error as ConnectionProbe.Failure {
            errorText = error.message
        } catch {
            errorText = "Нет связи: \(error.localizedDescription)"
        }
    }
}

// MARK: - Проверка подключения

enum ConnectionProbe {
    struct Failure: Error { let message: String }

    struct Info {
        let version: String?
        let pid: Int?
    }

    static func info(url: URL, username: String, password: String) async throws -> Info {
        var request = URLRequest(url: url.appendingPathComponent("api/info"))
        let raw = "\(username):\(password)".data(using: .utf8) ?? Data()
        request.setValue("Basic " + raw.base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure(message: "Нет связи: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw Failure(message: "Сервер не ответил")
        }
        if http.statusCode == 401 {
            throw Failure(message: "Сервер отклонил логин или пароль")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Failure(message: "Сервер ответил \(http.statusCode)")
        }

        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Info(version: object?["version"] as? String,
                    pid: object?["pid"] as? Int)
    }
}

// MARK: - Панель управления

struct ControlPanel: View {
    @EnvironmentObject private var store: ConnectionStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    let reload: () -> Void
    let openSettings: () -> Void

    @State private var status: String?
    @State private var checking = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        connectionCard
                        zoomCard
                        actionsCard
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Управление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Circle()
                    .fill(status == nil ? Palette.muted : Palette.mint)
                    .frame(width: 8, height: 8)
                Text(status ?? "Проверяю…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if checking { ProgressView().scaleEffect(0.7) }
            }

            Divider().overlay(Color.white.opacity(0.07))

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Text(store.connection.baseURL)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .task { await refreshStatus() }
    }

    private var zoomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Масштаб интерфейса")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(Int(settings.zoom * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.violet)
            }

            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Slider(value: $settings.zoom, in: 0.55...1.35, step: 0.05)
                    .tint(Palette.violet)
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.muted)
            }

            Text("Если текст на телефоне мелкий — увеличь или уменьши здесь.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted.opacity(0.85))
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button {
                dismiss()
                reload()
            } label: {
                Label("Перезагрузить интерфейс", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GhostButtonStyle())

            Button {
                dismiss()
                openSettings()
            } label: {
                Label("Сервер и пароль", systemImage: "gearshape")
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private func refreshStatus() async {
        checking = true
        defer { checking = false }
        guard let url = store.connection.url else { status = "Неверный адрес"; return }
        do {
            let info = try await ConnectionProbe.info(url: url,
                                                      username: store.connection.username,
                                                      password: store.connection.password)
            var parts = ["Связь есть"]
            if let version = info.version { parts.append("OpenCode \(version)") }
            status = parts.joined(separator: " · ")
        } catch let error as ConnectionProbe.Failure {
            status = error.message
        } catch {
            status = "Нет связи"
        }
    }
}

// MARK: - Настройки сервера

struct SettingsSheet: View {
    @EnvironmentObject private var store: ConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var testing = false
    @State private var result: String?
    @State private var failed = false

    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(spacing: 10) {
                            FieldCard(title: "Адрес сервера", systemImage: "globe") {
                                TextField("https://…", text: $store.connection.baseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                            }
                            FieldCard(title: "Логин", systemImage: "person") {
                                TextField("opencode", text: $store.connection.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            FieldCard(title: "Пароль", systemImage: "key") {
                                SecureField("••••••••", text: $store.connection.password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }

                        if let result {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(result)
                                    .font(.system(size: 13))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(failed ? Palette.danger : Palette.mint)
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                (failed ? Palette.danger : Palette.mint).opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                        }

                        Button {
                            Task { await test() }
                        } label: {
                            HStack(spacing: 9) {
                                if testing { ProgressView().tint(.white).scaleEffect(0.85) }
                                Text(testing ? "Проверяю…" : "Проверить связь")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(enabled: !testing))
                        .disabled(testing)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Сервер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        guard let url = store.connection.url else {
            result = "Неверный адрес"
            failed = true
            return
        }
        do {
            let info = try await ConnectionProbe.info(url: url,
                                                      username: store.connection.username,
                                                      password: store.connection.password)
            failed = false
            if let version = info.version {
                result = "Связь есть, OpenCode \(version)"
            } else {
                result = "Связь есть"
            }
        } catch let error as ConnectionProbe.Failure {
            failed = true
            result = error.message
        } catch {
            failed = true
            result = "Нет связи: \(error.localizedDescription)"
        }
    }
}
