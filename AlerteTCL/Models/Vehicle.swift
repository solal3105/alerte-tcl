import Foundation
import CoreLocation

struct Vehicle: Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let bearing: Double
    let lineRef: String
    let lineName: String
    let vehicleType: VehicleType
    let destination: String
    let delay: Int
    let status: String?
    let recordedAt: Date?
    let validUntil: Date?
    let nextStop: StopInfo?
    let onwardStops: [StopInfo]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var delayFormatted: String {
        if delay == 0 {
            return "À l'heure"
        } else if delay > 0 {
            let minutes = delay / 60
            if minutes > 0 {
                return "+\(minutes) min"
            } else {
                return "+\(delay) sec"
            }
        } else {
            let minutes = abs(delay) / 60
            if minutes > 0 {
                return "-\(minutes) min"
            } else {
                return "\(delay) sec"
            }
        }
    }
    
    var isDelayed: Bool {
        delay > 60
    }
    
    var isEarly: Bool {
        delay < -60
    }
    
    /// Description pour VoiceOver et accessibilité
    var accessibilityDescription: String {
        let type = vehicleType.rawValue
        let line = lineName
        let delay = delayFormatted
        let destination = destination.isEmpty ? "destination inconnue" : destination
        
        return "\(type) ligne \(line), direction \(destination), \(delay)"
    }
}

struct StopInfo: Identifiable, Hashable {
    let id: String
    let stopRef: String
    let stopName: String?
    let aimedArrivalTime: Date?
    let aimedDepartureTime: Date?
    let distanceFromStop: Int?
    let order: Int?
    
    var timeUntilArrival: TimeInterval? {
        guard let arrivalTime = aimedArrivalTime else { return nil }
        return arrivalTime.timeIntervalSinceNow
    }
    
    var arrivalFormatted: String {
        guard let timeUntil = timeUntilArrival else { return "?" }
        
        if timeUntil <= 0 {
            return "Maintenant"
        } else if timeUntil < 60 {
            return "\(Int(timeUntil))s"
        } else {
            let minutes = Int(timeUntil / 60)
            return "\(minutes)min"
        }
    }
}

enum VehicleType: String, CaseIterable {
    case tram = "Tramway"
    case bus = "Bus"
    case trolley = "Trolleybus"
    case funicular = "Funiculaire"
    case metro = "Métro"
    
    var icon: String {
        switch self {
        case .tram: return "tram"
        case .bus: return "bus.fill"
        case .trolley: return "bus.doubledecker.fill"
        case .funicular: return "cablecar.fill"
        case .metro: return "tram.fill"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .metro: return 0
        case .funicular: return 1
        case .tram: return 2
        case .trolley: return 3
        case .bus: return 4
        }
    }
}

struct SIRIResponse: Codable {
    let Siri: SIRIRoot
}

struct SIRIRoot: Codable {
    let ServiceDelivery: ServiceDelivery
}

struct ServiceDelivery: Codable {
    let ResponseTimestamp: String?
    let VehicleMonitoringDelivery: [VehicleMonitoringDelivery]?
}

struct VehicleMonitoringDelivery: Codable {
    let ResponseTimestamp: String?
    let VehicleActivity: [VehicleActivity]?
}

struct VehicleActivity: Codable {
    let RecordedAtTime: String?
    let ValidUntilTime: String?
    let VehicleMonitoringRef: RefValue?
    let MonitoredVehicleJourney: MonitoredVehicleJourney?
}

struct RefValue: Codable {
    let value: String?
}

struct MonitoredVehicleJourney: Codable {
    let LineRef: RefValue?
    let DirectionRef: RefValue?
    let DestinationRef: RefValue?
    let VehicleRef: RefValue?
    let VehicleLocation: VehicleLocation?
    let Bearing: Double?
    let Delay: String?
    let VehicleStatus: String?
    let MonitoredCall: MonitoredCall?
    let OnwardCalls: OnwardCalls?
}

struct MonitoredCall: Codable {
    let AimedArrivalTime: String?
    let ActualArrivalTime: String?
    let ArrivalStatus: String?
    let AimedDepartureTime: String?
    let ActualDepartureTime: String?
    let DepartureStatus: String?
    let DistanceFromStop: Int?
    let StopPointRef: RefValue?
    let Order: Int?
}

struct OnwardCalls: Codable {
    let OnwardCall: [OnwardCall]?
}

struct OnwardCall: Codable {
    let AimedArrivalTime: String?
    let AimedDepartureTime: String?
    let StopPointRef: RefValue?
    let Order: Int?
    let DistanceFromStop: Int?
}

struct VehicleLocation: Codable {
    let Longitude: Double?
    let Latitude: Double?
}
