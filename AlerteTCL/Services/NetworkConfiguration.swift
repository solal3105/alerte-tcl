//
//  NetworkConfiguration.swift
//  AlerteTCL
//
//  Configuration réseau partagée avec timeouts courts pour éviter les blocages
//

import Foundation

/// Configuration réseau partagée pour tous les services
enum NetworkConfiguration {
    // MARK: - Timeout values (en secondes)
    /// Timeout rapide pour véhicules/alertes (données légères, critiques)
    /// Note: 12s au lieu de 8s pour absorber le cold start réseau (DNS + TLS handshake)
    static let fastTimeout: TimeInterval = 12
    
    /// Timeout standard pour lignes/parkings
    static let sharedTimeout: TimeInterval = 12
    
    /// Timeout long pour arrêts (données lourdes)
    static let heavyTimeout: TimeInterval = 18
    
    // MARK: - Common Configuration
    
    /// Configuration de base optimisée partagée par toutes les sessions
    private static func baseConfig(timeout: TimeInterval, cacheMemoryMB: Int = 10, cacheDiskMB: Int = 30) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default

        // Timeouts
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 10

        // Cache: explicitly disabled — nous demandons toujours du temps réel.
        // Allouer un URLCache non utilisé gaspille RAM + disque.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        // Connexion
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 4
        
        // Compression automatique (gzip/deflate)
        // Note: iOS gère automatiquement Accept-Encoding et décompression
        
        // Multiplexing HTTP/2 si disponible
        config.httpShouldUsePipelining = true
        
        // Headers par défaut pour toutes les requêtes
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate",
            "User-Agent": "AlerteTCL/1.0"
        ]
        
        return config
    }
    
    // MARK: - URLSessions
    
    /// URLSession pour les données légères (alertes, véhicules) - timeout très court
    static let fast: URLSession = {
        URLSession(configuration: baseConfig(timeout: fastTimeout, cacheMemoryMB: 5, cacheDiskMB: 10))
    }()
    
    /// URLSession partagée avec timeouts standards
    static let shared: URLSession = {
        URLSession(configuration: baseConfig(timeout: sharedTimeout, cacheMemoryMB: 15, cacheDiskMB: 40))
    }()
    
    /// URLSession pour les données lourdes (arrêts, lignes) - timeout plus long
    static let heavy: URLSession = {
        URLSession(configuration: baseConfig(timeout: heavyTimeout, cacheMemoryMB: 25, cacheDiskMB: 60))
    }()
    
    // MARK: - Helper pour créer une URLRequest avec le bon timeout
    
    /// Crée une URLRequest avec le timeout spécifié (IMPORTANT: URLRequest.timeoutInterval override la config session!)
    static func request(url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        return request
    }
    
    /// Crée une URLRequest optimisée avec headers de compression
    static func optimizedRequest(url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }
}

// MARK: - URLRequest Basic Auth

extension URLRequest {
    /// Ajoute l'authentification Basic Auth à la requête
    mutating func setBasicAuth(username: String, password: String) {
        let credString = "\(username):\(password)"
        if let credentialsData = credString.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
    }
    
    /// Ajoute l'authentification Basic Auth depuis un tuple credentials
    mutating func setBasicAuth(_ credentials: (username: String, password: String)?) {
        guard let creds = credentials else { return }
        setBasicAuth(username: creds.username, password: creds.password)
    }
}
