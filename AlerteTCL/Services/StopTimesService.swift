import Foundation
import SwiftUI
import MapKit

// Service pour récupérer les horaires temps réel depuis les données véhicules
actor StopTimesService {
    static let shared = StopTimesService()
    
    private init() {}
    
    // Récupère les prochains passages pour un arrêt spécifique
    func fetchNextPassages(for stopRef: String, lineFilter: String? = nil) async -> [StopPassage] {
        do {
            let vehicles = try await SIRILiteService.shared.fetchVehiclePositions()
            return extractPassages(for: stopRef, from: vehicles, lineFilter: lineFilter)
        } catch {
            print("❌ Erreur récupération passages: \(error)")
            return []
        }
    }
    
    // Extrait les passages depuis les véhicules
    private func extractPassages(for stopRef: String, from vehicles: [Vehicle], lineFilter: String?) -> [StopPassage] {
        var passages: [StopPassage] = []
        
        for vehicle in vehicles {
            // Vérifier le prochain arrêt du véhicule
            if let nextStop = vehicle.nextStop,
               nextStop.stopRef.contains(stopRef) || stopRef.contains(nextStop.stopRef) {
                
                if let lineFilter = lineFilter, vehicle.lineName != lineFilter {
                    continue
                }
                
                let passage = StopPassage(
                    lineName: vehicle.lineName,
                    vehicleType: vehicle.vehicleType,
                    destination: vehicle.destination,
                    aimedTime: nextStop.aimedArrivalTime,
                    delay: vehicle.delay,
                    distance: nextStop.distanceFromStop,
                    vehicleId: vehicle.id
                )
                passages.append(passage)
            }
            
            // Vérifier les arrêts suivants
            for onwardStop in vehicle.onwardStops {
                if onwardStop.stopRef.contains(stopRef) || stopRef.contains(onwardStop.stopRef) {
                    
                    if let lineFilter = lineFilter, vehicle.lineName != lineFilter {
                        continue
                    }
                    
                    let passage = StopPassage(
                        lineName: vehicle.lineName,
                        vehicleType: vehicle.vehicleType,
                        destination: vehicle.destination,
                        aimedTime: onwardStop.aimedArrivalTime,
                        delay: vehicle.delay,
                        distance: onwardStop.distanceFromStop,
                        vehicleId: vehicle.id
                    )
                    passages.append(passage)
                }
            }
        }
        
        // Trier par temps d'arrivée
        return passages.sorted { passage1, passage2 in
            guard let time1 = passage1.aimedTime, let time2 = passage2.aimedTime else {
                return false
            }
            return time1 < time2
        }
    }
    
    // Récupère tous les arrêts GTFS dans la région et les enrichit avec les véhicules
    func fetchStopsWithVehicles(in region: MKCoordinateRegion) async -> [StopWithVehicles] {
        do {
            // Charger tous les arrêts GTFS dans la région
            let gtfsStops = try await GTFSStopsService.shared.getStopsInRegion(region)
            
            // Charger les véhicules en temps réel
            let vehicles = try await SIRILiteService.shared.fetchVehiclePositions()
            
            // Créer un dictionnaire des passages par arrêt
            var stopPassages: [String: [Vehicle]] = [:]
            
            for vehicle in vehicles {
                // Vérifier le prochain arrêt
                if let nextStop = vehicle.nextStop {
                    let stopId = extractStopId(from: nextStop.stopRef)
                    stopPassages[stopId, default: []].append(vehicle)
                }
                
                // Vérifier les arrêts suivants
                for onwardStop in vehicle.onwardStops {
                    let stopId = extractStopId(from: onwardStop.stopRef)
                    stopPassages[stopId, default: []].append(vehicle)
                }
            }
            
            // Créer les StopWithVehicles pour tous les arrêts GTFS
            return gtfsStops.map { gtfsStop in
                let vehiclesForStop = stopPassages[gtfsStop.id] ?? []
                let passages = createPassages(from: vehiclesForStop, stopId: gtfsStop.id)
                
                return StopWithVehicles(
                    stopRef: gtfsStop.id,
                    stopName: gtfsStop.name,
                    coordinate: gtfsStop.coordinate,
                    vehicles: vehiclesForStop,
                    passages: passages
                )
            }
        } catch {
            print("❌ Erreur récupération arrêts: \(error)")
            return []
        }
    }
    
    private func extractStopId(from stopRef: String) -> String {
        // Extraire l'ID depuis "ActIV:StopArea:SP:2206:SYTRAL" -> "2206"
        let components = stopRef.components(separatedBy: ":")
        if components.count >= 4 {
            return components[3]
        }
        return stopRef
    }
    
    private func createPassages(from vehicles: [Vehicle], stopId: String) -> [StopPassage] {
        var passages: [StopPassage] = []
        
        for vehicle in vehicles {
            // Chercher dans nextStop
            if let nextStop = vehicle.nextStop,
               extractStopId(from: nextStop.stopRef) == stopId {
                let passage = StopPassage(
                    lineName: vehicle.lineName,
                    vehicleType: vehicle.vehicleType,
                    destination: vehicle.destination,
                    aimedTime: nextStop.aimedArrivalTime,
                    delay: vehicle.delay,
                    distance: nextStop.distanceFromStop,
                    vehicleId: vehicle.id
                )
                passages.append(passage)
            }
            
            // Chercher dans onwardStops
            for onwardStop in vehicle.onwardStops {
                if extractStopId(from: onwardStop.stopRef) == stopId {
                    let passage = StopPassage(
                        lineName: vehicle.lineName,
                        vehicleType: vehicle.vehicleType,
                        destination: vehicle.destination,
                        aimedTime: onwardStop.aimedArrivalTime,
                        delay: vehicle.delay,
                        distance: onwardStop.distanceFromStop,
                        vehicleId: vehicle.id
                    )
                    passages.append(passage)
                }
            }
        }
        
        // Trier par temps d'arrivée
        return passages.sorted { passage1, passage2 in
            guard let time1 = passage1.aimedTime, let time2 = passage2.aimedTime else {
                return false
            }
            return time1 < time2
        }
    }
    
    private func groupVehiclesByStop(vehicles: [Vehicle], region: MKCoordinateRegion) -> [StopWithVehicles] {
        var stopGroups: [String: (vehicles: [Vehicle], coordinate: CLLocationCoordinate2D, name: String)] = [:]
        
        for vehicle in vehicles {
            // Vérifier si le véhicule est dans la région
            guard isVehicleInRegion(vehicle, region: region) else { continue }
            
            // Ajouter le prochain arrêt
            if let nextStop = vehicle.nextStop {
                let stopKey = nextStop.stopRef
                
                if stopGroups[stopKey] == nil {
                    stopGroups[stopKey] = (
                        vehicles: [],
                        coordinate: vehicle.coordinate,
                        name: nextStop.stopName ?? nextStop.stopRef
                    )
                }
                
                stopGroups[stopKey]?.vehicles.append(vehicle)
            }
        }
        
        // Convertir en StopWithVehicles avec passages
        return stopGroups.map { (stopRef, data) in
            let stopId = extractStopId(from: stopRef)
            let passages = createPassages(from: data.vehicles, stopId: stopId)
            
            return StopWithVehicles(
                stopRef: stopRef,
                stopName: data.name,
                coordinate: data.coordinate,
                vehicles: data.vehicles,
                passages: passages
            )
        }.sorted { $0.stopName < $1.stopName }
    }
    
    private func isVehicleInRegion(_ vehicle: Vehicle, region: MKCoordinateRegion) -> Bool {
        let lat = vehicle.latitude
        let lon = vehicle.longitude
        
        return lat >= region.center.latitude - region.span.latitudeDelta &&
               lat <= region.center.latitude + region.span.latitudeDelta &&
               lon >= region.center.longitude - region.span.longitudeDelta &&
               lon <= region.center.longitude + region.span.longitudeDelta
    }
}

// Modèles pour les passages d'arrêts
struct StopPassage: Identifiable, Hashable {
    let id = UUID()
    let lineName: String
    let vehicleType: VehicleType
    let destination: String
    let aimedTime: Date?
    let delay: Int
    let distance: Int?
    let vehicleId: String
    
    var timeUntilArrival: TimeInterval? {
        guard let arrivalTime = aimedTime else { return nil }
        let timeInterval = arrivalTime.timeIntervalSinceNow
        // Ajouter le délai pour avoir le temps réel
        return timeInterval + Double(delay)
    }
    
    var arrivalFormatted: String {
        guard let timeUntil = timeUntilArrival else { return "?" }
        
        if timeUntil <= 60 {
            return "Proche"
        } else if timeUntil < 120 {
            return "1min"
        } else {
            let minutes = Int(timeUntil / 60)
            return "\(minutes)min"
        }
    }
    
    var delayFormatted: String {
        if delay == 0 {
            return "À l'heure"
        } else if delay > 0 {
            let minutes = delay / 60
            return "+\(minutes)min"
        } else {
            let minutes = abs(delay) / 60
            return "-\(minutes)min"
        }
    }
}

struct StopWithVehicles: Identifiable, Hashable {
    let id = UUID()
    let stopRef: String
    let stopName: String
    let coordinate: CLLocationCoordinate2D
    var vehicles: [Vehicle]
    var passages: [StopPassage]
    
    var nextPassages: [StopPassage] {
        return passages
    }
    
    // Custom Hashable and Equatable to avoid requiring CLLocationCoordinate2D to conform
    static func == (lhs: StopWithVehicles, rhs: StopWithVehicles) -> Bool {
        // Consider two entries equal if they refer to the same stopRef
        // You can add stopName if needed, but stopRef should be stable/unique.
        return lhs.stopRef == rhs.stopRef
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stopRef)
    }
}
