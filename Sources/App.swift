import SwiftUI

@main
struct OpenCodeApp: App {
    @StateObject private var store = ConnectionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @State private var setupDone: Bool
    @State private var reloadToken = 0
    @State private var state: WebState = .loading
    @State private var showSettings = false

    init() {
        _setupDone = State(initialValue: ConnectionStore().connection.isComplete)
    }

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.063, blue: 0.078).ignoresSafeArea()

            if setupDone, let url = store.connection.url {
                WebContainer(
                    url: url,
                    username: store.connection.username,
                    password: store.connection.password,
                    reloadToken: reloadToken,
                    state: $state,
                    onSettings: { showSettings = true }
                )
                .ignoresSafeArea(.container, edges: .bottom)
            } else {
                SetupView {
                    setupDone = true
                    reloadToken += 1
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(onApply: {
                reloadToken += 1
                state = .loading
            })
            .environmentObject(store)
        }
    }
}

// MARK: - Контейнер с индикаторами

struct WebContainer: View {
    let url: URL
    let username: String
    let password: String
    let reloadToken: Int
    @Binding var state: WebState
    let onSettings: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            WebView(url: url,
                    username: username,
                    password: password,
                    reloadToken: reloadToken,
                    onStateChange: { state = $0 })
                .ignoresSafeArea()

            if case .loading = state {
                LoadingBar()
            }

            if case let .failed(message) = state {
                ErrorBanner(message: message) {
                    state = .loading
                }
            }

            if case .unauthorized = state {
                ErrorBanner(message: "Неверный логин или пароль — открой настройки") {
                    onSettings()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct LoadingBar: View {
    @State private var progress: CGFloat = 0.12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear.frame(height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.55))
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: progress)
            }
        }
        .frame(height: 2)
        .onAppear { progress = 0.85 }
        .transition(.opacity)
    }
}

struct ErrorBanner: View {
    let message: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                Text(message)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.red.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Первичная настройка

struct SetupView: View {
    @EnvironmentObject private var store: ConnectionStore
    @State private var checking = false
    @State private var errorText: String?
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenCode")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Тот же интерфейс, что на ноутбуке — целиком.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 40)

                field("Адрес сервера", text: $store.connection.baseURL, keyboard: .URL)
                field("Логин", text: $store.connection.username, keyboard: .default)
                secure("Пароль", text: $store.connection.password)

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    Task { await check() }
                } label: {
                    HStack(spacing: 8) {
                        if checking { ProgressView().tint(.black) }
                        Text(checking ? "Проверяю…" : "Открыть")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.black)
                }
                .disabled(checking || !store.connection.isComplete)
                .opacity(store.connection.isComplete ? 1 : 0.4)
            }
            .padding(20)
        }
        .background(Color(red: 0.055, green: 0.063, blue: 0.078).ignoresSafeArea())
    }

    private func check() async {
        checking = true
        defer { checking = false }
        guard let url = store.connection.url else { errorText = "Неверный адрес"; return }

        var request = URLRequest(url: url.appendingPathComponent("api/info"))
        let raw = "\(store.connection.username):\(store.connection.password)".data(using: .utf8) ?? Data()
        request.setValue("Basic " + raw.base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 {
                errorText = "Сервер отклонил логин или пароль"
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                errorText = "Сервер ответил \(http.statusCode)"
                return
            }
            errorText = nil
            onDone()
        } catch {
            errorText = "Нет связи: \(error.localizedDescription)"
        }
    }

    private func field(_ label: String, text: Binding<String>,
                       keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.45))
            TextField("", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }

    private func secure(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.45))
            SecureField("", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Настройки

struct SettingsSheet: View {
    @EnvironmentObject private var store: ConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var testing = false
    @State private var result: String?
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер") {
                    TextField("Адрес", text: $store.connection.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Логин", text: $store.connection.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Пароль", text: $store.connection.password)
                }
                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack(spacing: 8) {
                            if testing { ProgressView() }
                            Text(testing ? "Проверяю…" : "Проверить связь")
                        }
                    }
                } footer: {
                    if let result { Text(result) }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await reloadPage() }
                    } label: {
                        Text("Перезагрузить интерфейс")
                    }
                }
            }
            .navigationTitle("Настройки")
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

    private func reloadPage() async {
        onApply()
        dismiss()
    }

    private func test() async {
        testing = true
        defer { testing = false }
        guard let url = store.connection.url else { result = "Неверный адрес"; return }
        var request = URLRequest(url: url.appendingPathComponent("api/info"))
        let raw = "\(store.connection.username):\(store.connection.password)".data(using: .utf8) ?? Data()
        request.setValue("Basic " + raw.base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { result = "Нет ответа"; return }
            if http.statusCode == 401 { result = "Логин или пароль не подходят"; return }
            if (200..<300).contains(http.statusCode) {
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let version = obj["version"] as? String {
                    result = "Связь есть, OpenCode \(version)"
                } else {
                    result = "Связь есть"
                }
            } else {
                result = "Сервер ответил \(http.statusCode)"
            }
        } catch {
            result = "Нет связи: \(error.localizedDescription)"
        }
    }
}
