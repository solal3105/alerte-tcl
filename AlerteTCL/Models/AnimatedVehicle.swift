import Foundation
import CoreLocation
import SwiftUI

class AnimatedVehicle: Identifiable, ObservableObject {
    let id: String
    let vehicle: Vehicle
    
    @Published var animatedCoordinate: CLLocationCoordinate2D
    @Published var animatedBearing: Double
    
    private var previousCoordinate: CLLocationCoordinate2D?
    private var targetCoordinate: CLLocationCoordinate2D
    private var previousBearing: Double
    private var targetBearing: Double
    
    private var animationTimer: Timer?
    private var animationStartTime: Date?
    private let animationDuration: TimeInterval = 30.0
    
    init(vehicle: Vehicle, previousVehicle: Vehicle? = nil) {
        self.id = vehicle.id
        self.vehicle = vehicle
        self.targetCoordinate = vehicle.coordinate
        self.targetBearing = vehicle.bearing
        
        if let prev = previousVehicle {
            self.previousCoordinate = prev.coordinate
            self.previousBearing = prev.bearing
            self.animatedCoordinate = prev.coordinate
            self.animatedBearing = prev.bearing
        } else {
            self.previousCoordinate = nil
            self.previousBearing = vehicle.bearing
            self.animatedCoordinate = vehicle.coordinate
            self.animatedBearing = vehicle.bearing
        }
    }
    
    func startAnimation() {
        guard previousCoordinate != nil else {
            animatedCoordinate = targetCoordinate
            animatedBearing = targetBearing
            return
        }
        
        animationStartTime = Date()
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimation() {
        guard let startTime = animationStartTime,
              let prevCoord = previousCoordinate else {
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / animationDuration, 1.0)
        
        let easedProgress = easeInOutCubic(progress)
        
        let newLat = prevCoord.latitude + (targetCoordinate.latitude - prevCoord.latitude) * easedProgress
        let newLon = prevCoord.longitude + (targetCoordinate.longitude - prevCoord.longitude) * easedProgress
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.animatedCoordinate = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
            
            var bearingDiff = self.targetBearing - self.previousBearing
            if bearingDiff > 180 { bearingDiff -= 360 }
            if bearingDiff < -180 { bearingDiff += 360 }
            self.animatedBearing = self.previousBearing + bearingDiff * easedProgress
        }
        
        if progress >= 1.0 {
            stopAnimation()
        }
    }
    
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            return 1 - pow(-2 * t + 2, 3) / 2
        }
    }
    
    deinit {
        stopAnimation()
    }
}

struct VehicleCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let vehicles: [Vehicle]
    let dominantType: VehicleType
    
    var count: Int { vehicles.count }
    
    init(vehicles: [Vehicle]) {
        self.id = UUID().uuidString
        self.vehicles = vehicles
        
        let avgLat = vehicles.map { $0.latitude }.reduce(0, +) / Double(vehicles.count)
        let avgLon = vehicles.map { $0.longitude }.reduce(0, +) / Double(vehicles.count)
        self.coordinate = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        
        let typeCounts = Dictionary(grouping: vehicles, by: { $0.vehicleType })
        self.dominantType = typeCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .bus
    }
}
