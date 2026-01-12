//
//  WidgetConfiguration.swift
//  AlerteTCLWidget
//
//  Configuration système pour les widgets
//

import AppIntents
import WidgetKit

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
