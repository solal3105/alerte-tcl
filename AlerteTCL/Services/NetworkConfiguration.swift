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
    static let fastTimeout: TimeInterval = 8
    
    /// Timeout standard pour lignes/parkings
    static let sharedTimeout: TimeInterval = 12
    
    /// Timeout long pour arrêts (données lourdes)
    static let heavyTimeout: TimeInterval = 18
    
    // MARK: - URLSessions
    /// URLSession pour les données légères (alertes, véhicules) - timeout très court
    static let fast: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = fastTimeout
        config.timeoutIntervalForResource = fastTimeout + 5
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    /// URLSession partagée avec timeouts standards
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = sharedTimeout
        config.timeoutIntervalForResource = sharedTimeout + 5
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 30 * 1024 * 1024)
        return URLSession(configuration: config)
    }()
    
    /// URLSession pour les données lourdes (arrêts, lignes) - timeout plus long
    static let heavy: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = heavyTimeout
        config.timeoutIntervalForResource = heavyTimeout + 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        return URLSession(configuration: config)
    }()
    
    // MARK: - Helper pour créer une URLRequest avec le bon timeout
    /// Crée une URLRequest avec le timeout spécifié (IMPORTANT: URLRequest.timeoutInterval override la config session!)
    static func request(url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        return request
    }
}
