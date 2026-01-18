import Foundation
import MapKit
import CoreLocation

struct Journey: Identifiable, Codable, Equatable {
    let id: UUID
    let departure: JourneyLocation
    let arrival: JourneyLocation
    let steps: [JourneyStep]
    let totalDuration: TimeInterval
    let totalDistance: Double
    let departureTime: Date
    let arrivalTime: Date
    let polylinePoints: [CoordinatePoint]
    
    var transportModes: Set<JourneyTransportMode> {
        Set(steps.compactMap { $0.transportMode })
    }
    
    var formattedDuration: String {
        let minutes = Int(totalDuration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h\(remainingMinutes)" : "\(hours)h"
        }
        return "\(minutes) min"
    }
    
    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.1f km", totalDistance / 1000)
        }
        return "\(Int(totalDistance)) m"
    }
    
    static func == (lhs: Journey, rhs: Journey) -> Bool {
        lhs.id == rhs.id
    }
}

struct JourneyLocation: Codable, Equatable {
    let name: String
    let coordinate: CoordinatePoint
    let address: String?
    let stopId: Int?
    
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    init(name: String, coordinate: CLLocationCoordinate2D, address: String? = nil, stopId: Int? = nil) {
        self.name = name
        self.coordinate = CoordinatePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        self.address = address
        self.stopId = stopId
    }
    
    init(name: String, coordinate: CoordinatePoint, address: String? = nil, stopId: Int? = nil) {
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.stopId = stopId
    }
}

struct CoordinatePoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

struct JourneyStep: Identifiable, Codable, Equatable {
    let id: UUID
    let type: JourneyStepType
    let instructions: String
    let distance: Double
    let duration: TimeInterval
    let polylinePoints: [CoordinatePoint]
    
    let transportMode: JourneyTransportMode?
    let lineName: String?
    let lineColor: String?
    let direction: String?
    let departureStopName: String?
    let arrivalStopName: String?
    let departureTime: Date?
    let arrivalTime: Date?
    let numberOfStops: Int?
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes == 0 {
            return "< 1 min"
        }
        return "\(minutes) min"
    }
    
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        }
        return "\(Int(distance)) m"
    }
    
    init(
        id: UUID = UUID(),
        type: JourneyStepType,
        instructions: String,
        distance: Double,
        duration: TimeInterval,
        polylinePoints: [CoordinatePoint] = [],
        transportMode: JourneyTransportMode? = nil,
        lineName: String? = nil,
        lineColor: String? = nil,
        direction: String? = nil,
        departureStopName: String? = nil,
        arrivalStopName: String? = nil,
        departureTime: Date? = nil,
        arrivalTime: Date? = nil,
        numberOfStops: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.instructions = instructions
        self.distance = distance
        self.duration = duration
        self.polylinePoints = polylinePoints
        self.transportMode = transportMode
        self.lineName = lineName
        self.lineColor = lineColor
        self.direction = direction
        self.departureStopName = departureStopName
        self.arrivalStopName = arrivalStopName
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.numberOfStops = numberOfStops
    }
}

enum JourneyStepType: String, Codable, Equatable {
    case walk
    case transit
    case drive
    case bike
    
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .transit: return "tram.fill"
        case .drive: return "car.fill"
        case .bike: return "bicycle"
        }
    }
}

enum JourneyTransportMode: String, Codable, Equatable, Hashable {
    case walk
    case bike
    case metro
    case tram
    case bus
    case train
    case ferry
    case other
    
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .metro: return "tram.fill"
        case .tram: return "tram"
        case .bus: return "bus.fill"
        case .train: return "train.side.front.car"
        case .ferry: return "ferry.fill"
        case .other: return "arrow.triangle.turn.up.right.diamond.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .walk: return "Marche"
        case .bike: return "Vélo"
        case .metro: return "Métro"
        case .tram: return "Tram"
        case .bus: return "Bus"
        case .train: return "Train"
        case .ferry: return "Ferry"
        case .other: return "Transport"
        }
    }
}

enum JourneyTimeOption: Equatable {
    case leaveNow
    case departAt(Date)
    case arriveBy(Date)
    
    var displayText: String {
        switch self {
        case .leaveNow:
            return "Partir maintenant"
        case .departAt(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Partir à \(formatter.string(from: date))"
        case .arriveBy(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Arriver à \(formatter.string(from: date))"
        }
    }
}

struct RecentJourney: Identifiable, Codable {
    let id: UUID
    let departure: JourneyLocation
    let arrival: JourneyLocation
    let lastUsed: Date
    
    init(from journey: Journey) {
        self.id = UUID()
        self.departure = journey.departure
        self.arrival = journey.arrival
        self.lastUsed = Date()
    }
    
    init(departure: JourneyLocation, arrival: JourneyLocation) {
        self.id = UUID()
        self.departure = departure
        self.arrival = arrival
        self.lastUsed = Date()
    }
}

struct FavoritePlace: Identifiable, Codable {
    let id: UUID
    let name: String
    let customName: String?
    let location: JourneyLocation
    let icon: String
    let createdAt: Date
    
    var displayName: String {
        customName ?? name
    }
    
    init(name: String, customName: String? = nil, location: JourneyLocation, icon: String = "mappin") {
        self.id = UUID()
        self.name = name
        self.customName = customName
        self.location = location
        self.icon = icon
        self.createdAt = Date()
    }
}
