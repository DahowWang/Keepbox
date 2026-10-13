import Foundation
import Security

/// 同步伺服器設定：網址放 UserDefaults，token 放 Keychain。
enum SyncSettings {
    private static let urlKey = "keepbox.sync.serverURL"
    private static let cursorKey = "keepbox.sync.cursor"
    private static let lastSyncKey = "keepbox.sync.lastSyncAt"
    private static let keychainService = "com.dahow.keepbox.sync"
    private static let keychainAccount = "token"

    static var serverURL: URL? {
        get { UserDefaults.standard.string(forKey: urlKey).flatMap(URL.init(string:)) }
        set {
            let old = UserDefaults.standard.string(forKey: urlKey)
            UserDefaults.standard.set(newValue?.absoluteString, forKey: urlKey)
            // 換伺服器就從頭拉
            if old != newValue?.absoluteString { cursor = 0 }
        }
    }

    static var cursor: Int {
        get { UserDefaults.standard.integer(forKey: cursorKey) }
        set { UserDefaults.standard.set(newValue, forKey: cursorKey) }
    }

    static var lastSyncAt: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    static var isConfigured: Bool { serverURL != nil && token != nil }

    static var token: String? {
        get {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(baseQuery as CFDictionary)
            guard let newValue, !newValue.isEmpty else { return }
            var query = baseQuery
            query[kSecValueData as String] = Data(newValue.utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }
}
