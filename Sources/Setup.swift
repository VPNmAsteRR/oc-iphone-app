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
                    VStack(spacing: 16) {
                        BrandMark3D(size: 92)
                        VStack(spacing: 7) {
                            Text("OpenCode")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.brandText)
                            Text("Свои диалоги на телефоне")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(.top, 46)
                    .padding(.bottom, 4)

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
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Palette.danger.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Palette.danger.opacity(0.32), lineWidth: 1)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        focused = nil
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                AuroraBackground()

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
