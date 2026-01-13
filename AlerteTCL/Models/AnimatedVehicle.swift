import Foundation
import CoreLocation
import SwiftUI
import Combine

/// Gère l'animation fluide d'un véhicule entre deux positions GPS
/// Optimisé pour les données SIRI qui arrivent toutes les 15 secondes
@MainActor
class AnimatedVehicle: Identifiable, ObservableObject {
    let id: String
    @Published var animatedCoordinate: CLLocationCoordinate2D
    @Published var animatedBearing: Double
    
    private var sourceCoordinate: CLLocationCoordinate2D
    private var targetCoordinate: CLLocationCoordinate2D
    private var sourceBearing: Double
    private var targetBearing: Double
    
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private let animationDuration: TimeInterval = 15.0 // Durée SIRI entre deux updates
    
    private var isAnimating = false
    
    init(vehicle: Vehicle) {
        self.id = vehicle.id
        self.sourceCoordinate = vehicle.coordinate
        self.targetCoordinate = vehicle.coordinate
        self.animatedCoordinate = vehicle.coordinate
        self.sourceBearing = vehicle.bearing
        self.targetBearing = vehicle.bearing
        self.animatedBearing = vehicle.bearing
    }
    
    /// Met à jour la cible d'animation sans recréer l'objet
    func updateTarget(newVehicle: Vehicle, previousCoordinate: CLLocationCoordinate2D?, previousBearing: Double?) {
        // Vérifier que les coordonnées sont valides
        guard newVehicle.coordinate.latitude != 0,
              newVehicle.coordinate.longitude != 0,
              newVehicle.coordinate.latitude.isFinite,
              newVehicle.coordinate.longitude.isFinite else {
            return
        }
        
        // Calculer la distance du mouvement
        let distance = calculateDistance(from: targetCoordinate, to: newVehicle.coordinate)
        
        // Si le mouvement est trop grand (>500m), c'est probablement une erreur GPS
        if distance > 0.5 {
            // Téléporter directement sans animation
            self.sourceCoordinate = newVehicle.coordinate
            self.targetCoordinate = newVehicle.coordinate
            self.animatedCoordinate = newVehicle.coordinate
            self.sourceBearing = newVehicle.bearing
            self.targetBearing = newVehicle.bearing
            self.animatedBearing = newVehicle.bearing
            stopAnimation()
            return
        }
        
        // Si le mouvement est trop petit (<1m), ignorer
        if distance < 0.000001 {
            return
        }
        
        // Utiliser la position actuelle animée comme source
        self.sourceCoordinate = self.animatedCoordinate
        self.sourceBearing = self.animatedBearing
        
        // Nouvelle cible
        self.targetCoordinate = newVehicle.coordinate
        self.targetBearing = newVehicle.bearing
        
        // Redémarrer l'animation
        startAnimation()
    }
    
    private func startAnimation() {
        stopAnimation()
        
        // Respecter la préférence de réduction d'animations
        if UIAccessibility.isReduceMotionEnabled {
            // Mode réduit : téléportation directe
            animatedCoordinate = targetCoordinate
            animatedBearing = targetBearing
            return
        }
        
        isAnimating = true
        animationStartTime = CACurrentMediaTime()
        
        // Utiliser CADisplayLink pour une animation 60 FPS synchronisée avec l'écran
        let displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    func stopAnimation() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateAnimation() {
        guard isAnimating else { return }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        let progress = min(elapsed / animationDuration, 1.0)
        
        // Arrêter l'animation quand terminée AVANT de calculer les coordonnées
        if progress >= 1.0 {
            animatedCoordinate = targetCoordinate
            animatedBearing = targetBearing
            stopAnimation()
            return
        }
        
        // Fonction d'easing pour un mouvement naturel
        let easedProgress = easeInOutQuad(progress)
        
        // Interpolation de la position
        let newLat = sourceCoordinate.latitude + (targetCoordinate.latitude - sourceCoordinate.latitude) * easedProgress
        let newLon = sourceCoordinate.longitude + (targetCoordinate.longitude - sourceCoordinate.longitude) * easedProgress
        
        animatedCoordinate = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
        
        // Interpolation du bearing (gestion du wrap 0-360)
        var bearingDiff = targetBearing - sourceBearing
        if bearingDiff > 180 { bearingDiff -= 360 }
        if bearingDiff < -180 { bearingDiff += 360 }
        animatedBearing = sourceBearing + bearingDiff * easedProgress
    }
    
    private func easeInOutQuad(_ t: Double) -> Double {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - pow(-2 * t + 2, 2) / 2
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location2.distance(from: location1) / 1000.0 // en km
    }
    
    deinit {
        // Nettoyer manuellement le displayLink sans capturer self
        displayLink?.invalidate()
        displayLink = nil
    }
}

struct VehicleCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let vehicles: [Vehicle]
    let dominantType: VehicleType
    
    var count: Int { vehicles.count }
    
    init(vehicles: [Vehicle]) {
        let sortedIds = vehicles.map { $0.id }.sorted().joined(separator: "-")
        self.id = "cluster-\(sortedIds.hashValue)"
        self.vehicles = vehicles
        
        let avgLat = vehicles.map { $0.latitude }.reduce(0, +) / Double(vehicles.count)
        let avgLon = vehicles.map { $0.longitude }.reduce(0, +) / Double(vehicles.count)
        self.coordinate = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        
        let typeCounts = Dictionary(grouping: vehicles, by: { $0.vehicleType })
        self.dominantType = typeCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .bus
    }
}
