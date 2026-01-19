//
//  SpatialTileCache.swift
//  AlerteTCL
//
//  Cache spatial par tuiles pour optimiser le chargement des données géographiques
//  Évite de recharger les données lors du pan/zoom en réutilisant les tuiles déjà chargées
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Tile Key

/// Clé unique pour identifier une tuile spatiale
struct TileKey: Hashable, CustomStringConvertible {
    let x: Int
    let y: Int
    let zoom: Int
    
    var description: String {
        "Tile(\(x),\(y),z\(zoom))"
    }
}

// MARK: - Tile Cache Configuration

/// Configuration pour le cache spatial par tuiles
struct TileCacheConfiguration {
    /// Taille d'une tuile en degrés (latitude)
    let tileSizeDegrees: Double
    
    /// Durée de validité du cache en secondes
    let expirationSeconds: TimeInterval
    
    /// Nombre maximum de tuiles en cache
    let maxTiles: Int
    
    /// Buffer autour de la région visible (multiplicateur)
    let viewportBuffer: Double
    
    /// Configuration par défaut pour données statiques (vélos, 2-roues)
    static let staticData = TileCacheConfiguration(
        tileSizeDegrees: 0.01,  // ~1km tuiles
        expirationSeconds: 3600, // 1 heure
        maxTiles: 100,
        viewportBuffer: 1.5
    )
    
    /// Configuration pour données temps réel (parkings voiture)
    static let realTimeData = TileCacheConfiguration(
        tileSizeDegrees: 0.02,  // ~2km tuiles
        expirationSeconds: 30,   // 30 secondes
        maxTiles: 50,
        viewportBuffer: 1.3
    )
    
    /// Configuration agressive pour grands datasets
    static let largeDataset = TileCacheConfiguration(
        tileSizeDegrees: 0.015,
        expirationSeconds: 1800, // 30 min
        maxTiles: 150,
        viewportBuffer: 1.2
    )
}

// MARK: - Spatial Tile Cache

/// Cache générique par tuiles spatiales avec expiration et limite de mémoire
actor SpatialTileCache<T: Identifiable & Sendable> {
    
    // Type alias pour compatibilité
    typealias Configuration = TileCacheConfiguration
    
    // MARK: - Cache Entry
    
    private struct CacheEntry {
        let items: [T]
        let timestamp: Date
        let itemIds: Set<AnyHashable>
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > expirationDuration
        }
        
        private let expirationDuration: TimeInterval
        
        init(items: [T], expirationDuration: TimeInterval) {
            self.items = items
            self.timestamp = Date()
            self.expirationDuration = expirationDuration
            self.itemIds = Set(items.map { AnyHashable($0.id) })
        }
    }
    
    // MARK: - Properties
    
    private var cache: [TileKey: CacheEntry] = [:]
    private var accessOrder: [TileKey] = []
    private let config: Configuration
    
    // MARK: - Stats
    
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
    
    // MARK: - Init
    
    init(config: Configuration = .staticData) {
        self.config = config
    }
    
    // MARK: - Tile Calculation
    
    /// Calcule la clé de tuile pour une coordonnée donnée
    func tileKey(for coordinate: CLLocationCoordinate2D, zoomLevel: Double = 0) -> TileKey {
        let zoomAdjustedSize = config.tileSizeDegrees * max(1, zoomLevel * 10)
        let x = Int(floor(coordinate.longitude / zoomAdjustedSize))
        let y = Int(floor(coordinate.latitude / zoomAdjustedSize))
        let zoom = Int(zoomLevel * 100)
        return TileKey(x: x, y: y, zoom: zoom)
    }
    
    /// Calcule toutes les tuiles nécessaires pour couvrir une région
    func tilesForRegion(_ region: MKCoordinateRegion) -> [TileKey] {
        let buffer = config.viewportBuffer
        let latDelta = region.span.latitudeDelta * buffer
        let lonDelta = region.span.longitudeDelta * buffer
        
        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2
        
        let tileSize = config.tileSizeDegrees
        let zoom = Int(region.span.latitudeDelta * 100)
        
        var tiles: [TileKey] = []
        
        var lat = minLat
        while lat <= maxLat {
            var lon = minLon
            while lon <= maxLon {
                let x = Int(floor(lon / tileSize))
                let y = Int(floor(lat / tileSize))
                tiles.append(TileKey(x: x, y: y, zoom: zoom))
                lon += tileSize
            }
            lat += tileSize
        }
        
        return tiles
    }
    
    // MARK: - Cache Operations
    
    /// Récupère les items d'une tuile si en cache et non expirée
    func get(tile: TileKey) -> [T]? {
        guard let entry = cache[tile], !entry.isExpired else {
            missCount += 1
            return nil
        }
        
        hitCount += 1
        updateAccessOrder(tile)
        return entry.items
    }
    
    /// Stocke les items pour une tuile
    func set(tile: TileKey, items: [T]) {
        // Éviction LRU si nécessaire
        while cache.count >= config.maxTiles {
            evictLRU()
        }
        
        cache[tile] = CacheEntry(items: items, expirationDuration: config.expirationSeconds)
        updateAccessOrder(tile)
    }
    
    /// Récupère tous les items pour une région, retourne les tuiles manquantes
    func getItemsForRegion(_ region: MKCoordinateRegion) -> (items: [T], missingTiles: [TileKey]) {
        let tiles = tilesForRegion(region)
        var allItems: [T] = []
        var missingTiles: [TileKey] = []
        var seenIds: Set<AnyHashable> = []
        
        for tile in tiles {
            if let items = get(tile: tile) {
                for item in items {
                    let id = AnyHashable(item.id)
                    if !seenIds.contains(id) {
                        seenIds.insert(id)
                        allItems.append(item)
                    }
                }
            } else {
                missingTiles.append(tile)
            }
        }
        
        return (allItems, missingTiles)
    }
    
    /// Invalide toutes les tuiles expirées
    func pruneExpired() {
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        if !expiredKeys.isEmpty {
            print("🧹 SpatialTileCache: \(expiredKeys.count) tuiles expirées supprimées")
        }
    }
    
    /// Vide entièrement le cache
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        hitCount = 0
        missCount = 0
    }
    
    /// Statistiques du cache
    var stats: String {
        "Cache: \(cache.count)/\(config.maxTiles) tuiles, hit rate: \(String(format: "%.1f", hitRate * 100))%"
    }
    
    // MARK: - Private
    
    private func updateAccessOrder(_ tile: TileKey) {
        accessOrder.removeAll { $0 == tile }
        accessOrder.append(tile)
    }
    
    private func evictLRU() {
        guard let oldest = accessOrder.first else { return }
        cache.removeValue(forKey: oldest)
        accessOrder.removeFirst()
    }
}

// MARK: - BBox Helper

/// Utilitaire pour générer des paramètres bbox pour l'API OGC Features
enum BBoxHelper {
    
    /// Génère une chaîne bbox pour l'API OGC Features
    static func bboxString(for region: MKCoordinateRegion, buffer: Double = 1.3) -> String {
        let latDelta = region.span.latitudeDelta * buffer / 2
        let lonDelta = region.span.longitudeDelta * buffer / 2
        
        let minLon = region.center.longitude - lonDelta
        let maxLon = region.center.longitude + lonDelta
        let minLat = region.center.latitude - latDelta
        let maxLat = region.center.latitude + latDelta
        
        return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
    }
    
    /// Génère une chaîne bbox pour un ensemble de tuiles
    static func bboxString(for tiles: [TileKey], tileSizeDegrees: Double) -> String {
        guard !tiles.isEmpty else { return "" }
        
        let minX = tiles.map { $0.x }.min()!
        let maxX = tiles.map { $0.x }.max()!
        let minY = tiles.map { $0.y }.min()!
        let maxY = tiles.map { $0.y }.max()!
        
        let minLon = Double(minX) * tileSizeDegrees
        let maxLon = Double(maxX + 1) * tileSizeDegrees
        let minLat = Double(minY) * tileSizeDegrees
        let maxLat = Double(maxY + 1) * tileSizeDegrees
        
        return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
    }
    
    /// Calcule la limite optimale basée sur le niveau de zoom
    static func optimalLimit(for zoomLevel: Double, baseLimit: Int = 500) -> Int {
        // Plus on est zoomé (petit zoomLevel), plus on peut charger
        // Plus on est dézoomé (grand zoomLevel), moins on charge
        if zoomLevel < 0.01 {
            return baseLimit  // Vue très zoomée
        } else if zoomLevel < 0.03 {
            return min(baseLimit, 300)
        } else if zoomLevel < 0.1 {
            return min(baseLimit, 200)
        } else {
            return min(baseLimit, 100)  // Vue très large
        }
    }
}
