//
//  SecretsManager.swift
//  AlerteTCL
//
//  Gestionnaire sécurisé des secrets et identifiants API
//  Utilise le Keychain pour stocker les données sensibles
//

import Foundation
import Security

enum SecretsManager {
    
    // MARK: - Keychain Keys
    
    private static let service = "com.solal.AlerteTCL"
    private static let usernameKey = "grandlyon_username"
    private static let passwordKey = "grandlyon_password"
    
    // MARK: - Public API
    
    /// Récupère les identifiants Grand Lyon
    static var grandLyonCredentials: (username: String, password: String)? {
        guard let username = getString(forKey: usernameKey),
              let password = getString(forKey: passwordKey) else {
            // Migration depuis Info.plist si présent (première exécution)
            return migrateFromInfoPlist()
        }
        return (username, password)
    }
    
    /// Sauvegarde les identifiants Grand Lyon
    static func saveGrandLyonCredentials(username: String, password: String) -> Bool {
        let usernameSuccess = setString(username, forKey: usernameKey)
        let passwordSuccess = setString(password, forKey: passwordKey)
        return usernameSuccess && passwordSuccess
    }
    
    /// Supprime les identifiants Grand Lyon
    static func deleteGrandLyonCredentials() {
        deleteItem(forKey: usernameKey)
        deleteItem(forKey: passwordKey)
    }
    
    /// Vérifie si les identifiants sont configurés
    static var hasCredentials: Bool {
        grandLyonCredentials != nil
    }
    
    // MARK: - Migration
    
    private static func migrateFromInfoPlist() -> (username: String, password: String)? {
        // Lire depuis Info.plist (legacy)
        guard let infoPlist = Bundle.main.infoDictionary,
              let username = infoPlist["GrandLyonUsername"] as? String,
              let password = infoPlist["GrandLyonPassword"] as? String,
              !username.isEmpty, !password.isEmpty else {
            return nil
        }
        
        // Migrer vers Keychain
        if saveGrandLyonCredentials(username: username, password: password) {
            print("✅ SecretsManager: Identifiants migrés vers Keychain")
        }
        
        return (username, password)
    }
    
    // MARK: - Keychain Helpers
    
    private static func setString(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Supprimer l'ancienne valeur si existante
        deleteItem(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private static func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private static func deleteItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
