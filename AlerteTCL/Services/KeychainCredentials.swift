//
//  KeychainCredentials.swift
//  AlerteTCL
//
//  Shared credentials store accessible from the main app AND the widget
//  extension via the keychain access group. Credentials are never bundled;
//  the user supplies them once in settings.
//

import Foundation
import Security

enum KeychainCredentials {

    struct Credentials: Equatable {
        let username: String
        let password: String
    }

    // MARK: Configuration

    /// Must match the `keychain-access-groups` entitlement on both targets.
    /// The `$(AppIdentifierPrefix)` (team ID) is resolved at runtime.
    private static let accessGroup: String? = {
        #if targetEnvironment(simulator)
        return nil // access groups are ignored in the simulator; skip the prefix
        #else
        return "\(teamIdentifierPrefix)group.com.solal.alertetcl"
        #endif
    }()

    private static let service = "com.solal.alertetcl.grandlyon"
    private static let usernameKey = "username"
    private static let passwordKey = "password"

    // MARK: Public API

    static var current: Credentials? {
        guard let username = read(usernameKey),
              let password = read(passwordKey),
              !username.isEmpty, !password.isEmpty else {
            return nil
        }
        return Credentials(username: username, password: password)
    }

    static var hasCredentials: Bool { current != nil }

    @discardableResult
    static func save(_ credentials: Credentials) -> Bool {
        write(credentials.username, key: usernameKey)
            && write(credentials.password, key: passwordKey)
    }

    static func clear() {
        delete(usernameKey)
        delete(passwordKey)
    }

    // MARK: Keychain primitives

    private static func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    private static func read(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    private static func write(_ value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        var query = baseQuery(for: key)

        // Try update first; if nothing to update, add.
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    private static func delete(_ key: String) -> Bool {
        SecItemDelete(baseQuery(for: key) as CFDictionary) == errSecSuccess
    }
}

// MARK: - Team identifier prefix resolution

/// Returns the current app's team identifier prefix (e.g. "ABCD1234.") required
/// to scope keychain access groups across bundles sharing the same team.
private var teamIdentifierPrefix: String = {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "bundleSeedIDProbe",
        kSecAttrService as String: "bundleSeedIDProbe",
        kSecReturnAttributes as String: true
    ]
    var out: AnyObject?
    var status = SecItemCopyMatching(query as CFDictionary, &out)
    if status == errSecItemNotFound {
        status = SecItemAdd(query as CFDictionary, &out)
    }
    guard status == errSecSuccess,
          let attrs = out as? [String: Any],
          let group = attrs[kSecAttrAccessGroup as String] as? String,
          let dot = group.firstIndex(of: ".") else {
        return ""
    }
    return String(group[..<group.index(after: dot)])
}()
