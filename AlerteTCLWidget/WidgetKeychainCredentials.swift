//
//  WidgetKeychainCredentials.swift
//  AlerteTCLWidget
//
//  Widget-side entry point that reads the same keychain item written by the
//  main app via the shared keychain-access-group.
//  Kept as a thin facade so WidgetServices.swift does not import the main
//  app's KeychainCredentials type.
//

import Foundation
import Security

enum WidgetKeychainCredentials {

    struct Credentials {
        let username: String
        let password: String
    }

    private static let service = "com.solal.alertetcl.grandlyon"
    private static let usernameKey = "username"
    private static let passwordKey = "password"
    private static let accessGroup: String? = {
        #if targetEnvironment(simulator)
        return nil
        #else
        return "\(teamIdentifierPrefix)group.com.solal.alertetcl"
        #endif
    }()

    static var current: Credentials? {
        guard let username = read(usernameKey),
              let password = read(passwordKey),
              !username.isEmpty, !password.isEmpty else {
            return nil
        }
        return Credentials(username: username, password: password)
    }

    private static func read(_ key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }
}

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
