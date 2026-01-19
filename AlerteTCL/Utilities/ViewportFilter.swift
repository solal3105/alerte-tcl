import Foundation
import CoreLocation
import MapKit

// MARK: - Viewport Filtering Utility

/// Utilitaire pour filtrer les éléments selon la région visible de la carte
/// avec un buffer pour optimiser les performances
enum ViewportFilter {
    
    /// Configuration du buffer de viewport
    struct BufferConfig {
        let multiplier: Double
        
        /// Buffer standard (1.5x la région visible)
        static let standard = BufferConfig(multiplier: 1.5)
        
        /// Buffer large (2.0x la région visible) - pour données moins denses
        static let large = BufferConfig(multiplier: 2.0)
        
        /// Buffer extra large (3.0x la région visible) - pour données très dispersées
        static let extraLarge = BufferConfig(multiplier: 3.0)
        
        /// Buffer petit (1.2x la région visible) - pour données très denses
        static let small = BufferConfig(multiplier: 1.2)
    }
    
    /// Vérifie si une coordonnée est dans la région visible (avec buffer)
    @inline(__always)
    static func isCoordinateVisible(
        _ coordinate: CLLocationCoordinate2D,
        in region: MKCoordinateRegion,
        buffer: BufferConfig = .standard
    ) -> Bool {
        let latDelta = region.span.latitudeDelta * buffer.multiplier
        let lonDelta = region.span.longitudeDelta * buffer.multiplier
        
        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2
        
        return coordinate.latitude >= minLat &&
               coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon &&
               coordinate.longitude <= maxLon
    }
    
    /// Filtre une collection d'éléments selon leur visibilité dans la région
    /// Optimisé: pré-calcule les bornes une seule fois
    static func filterVisible<T>(
        items: [T],
        in region: MKCoordinateRegion?,
        buffer: BufferConfig = .standard,
        coordinateProvider: (T) -> CLLocationCoordinate2D
    ) -> [T] {
        guard let region = region else { return items }
        
        // Pré-calculer les bornes une seule fois (évite recalcul par item)
        let latDelta = region.span.latitudeDelta * buffer.multiplier
        let lonDelta = region.span.longitudeDelta * buffer.multiplier
        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2
        
        return items.filter { item in
            let coord = coordinateProvider(item)
            return coord.latitude >= minLat &&
                   coord.latitude <= maxLat &&
                   coord.longitude >= minLon &&
                   coord.longitude <= maxLon
        }
    }
}

// MARK: - Clusterable Extension

extension Array where Element: Clusterable {
    /// Filtre les éléments visibles dans la région avec buffer
    func visibleIn(
        region: MKCoordinateRegion?,
        buffer: ViewportFilter.BufferConfig = .standard
    ) -> [Element] {
        ViewportFilter.filterVisible(
            items: self,
            in: region,
            buffer: buffer,
            coordinateProvider: { $0.coordinate }
        )
    }
}

// MARK: - Generic Coordinate Provider Extension

extension Array {
    /// Filtre les éléments visibles dans la région avec un provider de coordonnées personnalisé
    func visibleIn(
        region: MKCoordinateRegion?,
        buffer: ViewportFilter.BufferConfig = .standard,
        coordinateProvider: (Element) -> CLLocationCoordinate2D
    ) -> [Element] {
        ViewportFilter.filterVisible(
            items: self,
            in: region,
            buffer: buffer,
            coordinateProvider: coordinateProvider
        )
    }
}
