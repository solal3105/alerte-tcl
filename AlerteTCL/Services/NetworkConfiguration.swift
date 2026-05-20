//
//  NetworkConfiguration.swift
//  AlerteTCL
//
//  Configuration réseau partagée avec timeouts courts pour éviter les blocages
//

import Foundation

/// Configuration réseau partagée pour tous les services
enum NetworkConfiguration {
    // MARK: - Proxy URL
    /// URL du proxy Cloudflare Worker qui détient les credentials Grand Lyon.
    /// Mise à jour automatiquement par cloudflare-worker/deploy.sh au déploiement.
    static let proxyBaseURL = "https://tcl-proxy.solalgendrin.workers.dev"

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
    private static func baseConfig(timeout: TimeInterval) -> URLSessionConfiguration {
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
    
    // MARK: - URLSession
    
    /// Session partagée unique — le timeout par requête est défini via URLRequest.timeoutInterval.
    /// timeoutIntervalForResource = heavyTimeout + 10 couvre le pire cas (arrêts TCL).
    static let session: URLSession = {
        URLSession(configuration: baseConfig(timeout: heavyTimeout))
    }()
    
    // MARK: - Helper pour créer une URLRequest avec le bon timeout
    
    /// Crée une URLRequest avec le timeout spécifié (IMPORTANT: URLRequest.timeoutInterval override la config session!)
    static func request(url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        return request
    }
}

