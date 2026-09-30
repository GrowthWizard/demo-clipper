import Foundation
import Security

/// App-owned credentials. The API key is never written to preferences or logs.
struct RequestyCredentials: Codable, Sendable {
    var apiKey = ""
    var baseURL = "https://router.eu.requesty.ai/v1"
    var model = "glm-5.3-flash@eu"

    func configuration() throws -> RequestyConfiguration {
        try RequestyConfiguration(apiKey: apiKey, baseURL: baseURL, model: model)
    }

    static func from(environment: [String: String]) -> Self {
        var credentials = Self()
        credentials.apiKey = environment["REQUESTY_API_KEY"] ?? ""
        credentials.baseURL = environment["REQUESTY_BASE_URL"] ?? credentials.baseURL
        credentials.model = environment["REQUESTY_MODEL"] ?? credentials.model
        return credentials
    }
}

/// One generic-password item in the login Keychain, with no iCloud syncing.
/// A custom service is used only by tests to isolate their disposable fixture.
struct RequestyKeychain: Sendable {
    var service = "de.65creative.clipper.requesty.credentials"

    enum Failure: LocalizedError {
        case read, save, remove
        var errorDescription: String? {
            switch self {
            case .read: "Could not read the saved Requesty access. Unlock the login Keychain or enter the key for this session."
            case .save: "Could not save Requesty access in the login Keychain. You can use the key for this session instead."
            case .remove: "Could not remove this app's saved Requesty access from the login Keychain."
            }
        }
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "requesty",
         kSecAttrSynchronizable as String: false]
    }

    func load() throws -> RequestyCredentials? {
        var match = query
        match[kSecReturnData as String] = true
        match[kSecMatchLimit as String] = kSecMatchLimitOne
        // A locked or inaccessible Keychain must not prevent local clipping.
        match[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        var result: CFTypeRef?
        let status = SecItemCopyMatching(match as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let credentials = try? JSONDecoder().decode(RequestyCredentials.self, from: data)
        else { throw Failure.read }
        return credentials
    }

    func save(_ credentials: RequestyCredentials) throws {
        // JSON lives only in memory and in Keychain-encrypted item data.
        let data = try JSONEncoder().encode(credentials)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw Failure.save }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = "Clipper Requesty API access"
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw Failure.save }
    }

    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.remove }
    }
}
