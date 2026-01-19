//
//  WidgetConfiguration.swift
//  AlerteTCLWidget
//
//  Configuration système pour les widgets
//

import AppIntents
import WidgetKit

// MARK: - App Group

let appGroupIdentifier = "group.com.solal.alertetcl"

// MARK: - Stop Entity (for Next Departures Widget)

struct StopEntity: AppEntity {
    let id: String
    let stopId: Int
    let stopName: String
    let lineName: String
    let direction: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Arrêt")
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(stopName)",
            subtitle: "\(lineName) → \(direction)"
        )
    }
    
    static var defaultQuery = StopEntityQuery()
}

struct StopEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StopEntity] {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let savedStops = defaults?.array(forKey: "widgetStops") as? [[String: Any]] ?? []
        
        return savedStops.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let stopId = dict["stopId"] as? Int,
                  let stopName = dict["stopName"] as? String,
                  let lineName = dict["lineName"] as? String,
                  let direction = dict["direction"] as? String,
                  identifiers.contains(id) else { return nil }
            return StopEntity(id: id, stopId: stopId, stopName: stopName, lineName: lineName, direction: direction)
        }
    }
    
    func suggestedEntities() async throws -> [StopEntity] {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let savedStops = defaults?.array(forKey: "widgetStops") as? [[String: Any]] ?? []
        
        return savedStops.prefix(20).compactMap { dict in
            guard let id = dict["id"] as? String,
                  let stopId = dict["stopId"] as? Int,
                  let stopName = dict["stopName"] as? String,
                  let lineName = dict["lineName"] as? String,
                  let direction = dict["direction"] as? String else { return nil }
            return StopEntity(id: id, stopId: stopId, stopName: stopName, lineName: lineName, direction: direction)
        }
    }
    
    func defaultResult() async -> StopEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Next Departures Widget Configuration Intent

struct NextDeparturesConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Prochains passages"
    static var description = IntentDescription("Choisissez un arrêt et une ligne")
    
    @Parameter(title: "Arrêt", optionsProvider: StopOptionsProvider())
    var selectedStop: StopEntity?
    
    init() {}
    
    init(selectedStop: StopEntity?) {
        self.selectedStop = selectedStop
    }
}

struct StopOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [StopEntity] {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let savedStops = defaults?.array(forKey: "widgetStops") as? [[String: Any]] ?? []
        
        return savedStops.prefix(30).compactMap { dict in
            guard let id = dict["id"] as? String,
                  let stopId = dict["stopId"] as? Int,
                  let stopName = dict["stopName"] as? String,
                  let lineName = dict["lineName"] as? String,
                  let direction = dict["direction"] as? String else { return nil }
            return StopEntity(id: id, stopId: stopId, stopName: stopName, lineName: lineName, direction: direction)
        }
    }
    
    func defaultResult() async -> StopEntity? {
        try? await results().first
    }
}

// MARK: - Parking Entity

struct ParkingEntity: AppEntity {
    let id: String
    let name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Parking")
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = ParkingEntityQuery()
}

struct ParkingEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ParkingEntity] {
        let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
        let recentParkings = defaults?.array(forKey: "recentParkings") as? [[String: String]] ?? []
        
        return recentParkings.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"], identifiers.contains(id) else { return nil }
            return ParkingEntity(id: id, name: name)
        }
    }
    
    func suggestedEntities() async throws -> [ParkingEntity] {
        let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
        let recentParkings = defaults?.array(forKey: "recentParkings") as? [[String: String]] ?? []
        
        return recentParkings.prefix(10).compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return ParkingEntity(id: id, name: name)
        }
    }
    
    func defaultResult() async -> ParkingEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Parking Widget Configuration Intent

struct ParkingWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Parking"
    static var description = IntentDescription("Choisissez un parking")
    
    @Parameter(title: "Parking", optionsProvider: ParkingOptionsProvider())
    var selectedParking: ParkingEntity?
    
    init() {}
    
    init(selectedParking: ParkingEntity?) {
        self.selectedParking = selectedParking
    }
}

// MARK: - Options Providers

struct ParkingOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [ParkingEntity] {
        let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
        let recentParkings = defaults?.array(forKey: "recentParkings") as? [[String: String]] ?? []
        
        return recentParkings.prefix(20).compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return ParkingEntity(id: id, name: name)
        }
    }
    
    func defaultResult() async -> ParkingEntity? {
        try? await results().first
    }
}
