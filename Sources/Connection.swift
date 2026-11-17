import UIKit
import SwiftUI
import WebKit

// MARK: - Настройки подключения

struct Connection: Codable, Equatable {
    var baseURL: String = "https://oc.13.143.161.69.sslip.io:8443"
    var username: String = "opencode"
    var password: String = ""

    var url: URL? { URL(string: baseURL) }
    var isComplete: Bool { url != nil && !username.isEmpty && !password.isEmpty }
}

// MARK: - Keychain

enum Keychain {
    private static let service = "dev.opencode2.connection"

    static func save(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class ConnectionStore: ObservableObject {
    private static let account = "connection.v1"

    @Published var connection: Connection {
        didSet { persist() }
    }

    init() {
        #if DEBUG
        // Только для отладочных сборок: позволяет прогнать приложение
        // в симуляторе без ручного ввода настроек.
        let env = ProcessInfo.processInfo.environment
        if let password = env["OC_PASSWORD"], !password.isEmpty {
            var seeded = Connection()
            if let url = env["OC_URL"], !url.isEmpty { seeded.baseURL = url }
            if let user = env["OC_USER"], !user.isEmpty { seeded.username = user }
            seeded.password = password
            connection = seeded
            return
        }
        #endif

        if let data = Keychain.load(account: Self.account),
           let saved = try? JSONDecoder().decode(Connection.self, from: data) {
            connection = saved
        } else {
            connection = Connection()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(connection) else { return }
        Keychain.save(data, account: Self.account)
    }
}
