import Foundation
import CoreLocation
import UIKit

/// Données d'interpolation pour un véhicule sur la carte.
/// Aucune ressource lourde (pas de CADisplayLink, pas de Timer).
/// L'interpolation est calculée à la demande via `coordinateAt(_:)` / `bearingAt(_:)`,
/// appelées par la vue à chaque frame du driver d'animation partagé (~15 fps).
@MainActor
final class AnimatedVehicle: Identifiable {
    let id: String

    private var sourceCoordinate: CLLocationCoordinate2D
    private var targetCoordinate: CLLocationCoordinate2D
    private var sourceBearing: Double
    private var targetBearing: Double
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 5.0

    /// Dernier objet Vehicle reçu de l'API (permet de réinjecter les véhicules en période de grâce).
    private(set) var lastVehicle: Vehicle

    var lastSeenAt: Date = Date()
    var isActive: Bool = true

    /// Suppression après ~2 cycles sans données (API publie toutes les ~15 s, on poll toutes les 15 s).
    /// 25 s = 1 cycle manqué sans qu'un fantôme reste trop longtemps à l'écran.
    static let gracePeriod: TimeInterval = 25.0

    var shouldBeRemoved: Bool {
        !isActive && Date().timeIntervalSince(lastSeenAt) > Self.gracePeriod
    }

    // MARK: - Init

    init(vehicle: Vehicle) {
        self.id = vehicle.id
        self.lastVehicle = vehicle
        self.sourceCoordinate = vehicle.coordinate
        self.targetCoordinate = vehicle.coordinate
        self.sourceBearing = vehicle.bearing
        self.targetBearing = vehicle.bearing
    }

    // MARK: - Update

    /// Enregistre une nouvelle position cible avec handoff fluide depuis la position interpolée actuelle.
    /// `reduceMotion` doit être lu UNE fois par cycle de fetch par l'appelant (évite N lookups cross-process).
    func updateTarget(vehicle: Vehicle, duration: TimeInterval, currentTime: CFTimeInterval, reduceMotion: Bool) {
        guard vehicle.coordinate.latitude != 0,
              vehicle.coordinate.longitude != 0,
              vehicle.coordinate.latitude.isFinite,
              vehicle.coordinate.longitude.isFinite else { return }

        let dist = fastDistance(from: targetCoordinate, to: vehicle.coordinate)

        lastVehicle = vehicle

        // Saut > 500 m → téléportation (erreur GPS probable)
        if dist > 500 {
            sourceCoordinate = vehicle.coordinate
            targetCoordinate = vehicle.coordinate
            sourceBearing = vehicle.bearing
            targetBearing = vehicle.bearing
            startTime = 0
            return
        }

        // Bruit < 1 m → ignorer
        if dist < 1 { return }

        if reduceMotion {
            sourceCoordinate = vehicle.coordinate
            targetCoordinate = vehicle.coordinate
            sourceBearing = vehicle.bearing
            targetBearing = vehicle.bearing
            startTime = 0
            return
        }

        // Handoff fluide : partir de la position interpolée actuelle
        sourceCoordinate = coordinateAt(currentTime)
        sourceBearing = bearingAt(currentTime)
        targetCoordinate = vehicle.coordinate
        targetBearing = vehicle.bearing
        startTime = currentTime
        self.duration = duration
    }

    // MARK: - Interpolation (pure computation, aucun side-effect)

    func coordinateAt(_ time: CFTimeInterval) -> CLLocationCoordinate2D {
        let t = easedProgress(at: time)
        return CLLocationCoordinate2D(
            latitude:  sourceCoordinate.latitude  + (targetCoordinate.latitude  - sourceCoordinate.latitude)  * t,
            longitude: sourceCoordinate.longitude + (targetCoordinate.longitude - sourceCoordinate.longitude) * t
        )
    }

    func bearingAt(_ time: CFTimeInterval) -> Double {
        let t = easedProgress(at: time)
        var diff = targetBearing - sourceBearing
        if diff > 180  { diff -= 360 }
        if diff < -180 { diff += 360 }
        return sourceBearing + diff * t
    }

    // MARK: - Private

    private func easedProgress(at time: CFTimeInterval) -> Double {
        guard duration > 0, startTime > 0 else { return 1.0 }
        let raw = min(max((time - startTime) / duration, 0), 1)
        // easeOutQuad : décélération douce, parfait pour un handoff continu
        return 1 - (1 - raw) * (1 - raw)
    }

    /// Distance approximative en mètres (Haversine simplifié, précis < 1 km).
    @inline(__always)
    private func fastDistance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let dlat = (b.latitude  - a.latitude)  * 111_320
        let dlon = (b.longitude - a.longitude) * 111_320 * cos(a.latitude * .pi / 180)
        return (dlat * dlat + dlon * dlon).squareRoot()
    }
}

