//
//  SecretsManager.swift
//  AlerteTCL
//
//  Ordre de priorité des credentials Grand Lyon :
//  1. Secrets.swift (constantes compile-time, fichier gitignored — source principale)
//  2. Variables d'environnement Xcode (override debug via scheme)
//  3. Keychain (stockage persistant sur l'appareil)
//

import Foundation

enum SecretsManager {

    /// Returns credentials typed as a tuple to match existing call sites.
    static var grandLyonCredentials: (username: String, password: String)? {
        // 1. Constantes compile-time depuis Secrets.swift (gitignored)
        let compiledUser = Secrets.grandLyonUsername
        let compiledPass = Secrets.grandLyonPassword
        if !compiledUser.isEmpty,
           !compiledUser.hasPrefix("METTRE_"),
           !compiledPass.isEmpty,
           !compiledPass.hasPrefix("METTRE_") {
            return (compiledUser, compiledPass)
        }

        // 2. Variables d'environnement (override debug via scheme Xcode)
        let env = ProcessInfo.processInfo.environment
        if let u = env["GRANDLYON_USERNAME"], let p = env["GRANDLYON_PASSWORD"],
           !u.isEmpty, !p.isEmpty {
            return (u, p)
        }

        // 3. Keychain
        return KeychainCredentials.current.map { ($0.username, $0.password) }
    }

    static var hasCredentials: Bool {
        grandLyonCredentials != nil
    }

    @discardableResult
    static func saveGrandLyonCredentials(username: String, password: String) -> Bool {
        KeychainCredentials.save(.init(username: username, password: password))
    }

    static func deleteGrandLyonCredentials() {
        KeychainCredentials.clear()
    }
}

