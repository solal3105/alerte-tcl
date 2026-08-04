//
//  WidgetConfiguration.swift
//  AlerteTCLWidget
//
//  Configuration système pour les widgets
//

import AppIntents
import WidgetKit

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

    init(id: String, stopId: Int, stopName: String, lineName: String, direction: String) {
        self.id = id
        self.stopId = stopId
        self.stopName = stopName
        self.lineName = lineName
        self.direction = direction
    }

    /// Décodage du dictionnaire partagé via l'app group (source unique du parsing).
    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let stopId = dict["stopId"] as? Int,
              let stopName = dict["stopName"] as? String,
              let lineName = dict["lineName"] as? String,
              let direction = dict["direction"] as? String else { return nil }
        self.init(id: id, stopId: stopId, stopName: stopName, lineName: lineName, direction: direction)
    }
}

// MARK: - Lecture du stockage partagé

/// Sélections d'arrêts en cours (liste affichée dans l'app, susceptible d'évoluer).
private func loadWidgetStops() -> [[String: Any]] {
    AppGroup.defaults?.array(forKey: "widgetStops") as? [[String: Any]] ?? []
}

/// Index de résolution jamais purgé : un widget déjà configuré doit rester
/// résolvable même si l'arrêt a disparu de la liste courante.
private func loadWidgetStopsIndex() -> [String: [String: Any]] {
    AppGroup.defaults?.dictionary(forKey: "widgetStopsIndex") as? [String: [String: Any]] ?? [:]
}

struct StopEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StopEntity] {
        let fromCurrent = loadWidgetStops()
            .compactMap(StopEntity.init(dict:))
            .filter { identifiers.contains($0.id) }

        let resolved = Set(fromCurrent.map(\.id))
        guard resolved.count < identifiers.count else { return fromCurrent }

        // Secours : identifiants absents de la liste courante mais connus de l'index
        let index = loadWidgetStopsIndex()
        let fromIndex = identifiers
            .filter { !resolved.contains($0) }
            .compactMap { index[$0] }
            .compactMap(StopEntity.init(dict:))

        return fromCurrent + fromIndex
    }

    func suggestedEntities() async throws -> [StopEntity] {
        loadWidgetStops().prefix(20).compactMap(StopEntity.init(dict:))
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
        loadWidgetStops().prefix(30).compactMap(StopEntity.init(dict:))
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

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// Décodage du dictionnaire partagé via l'app group (source unique du parsing).
    init?(dict: [String: String]) {
        guard let id = dict["id"], let name = dict["name"] else { return nil }
        self.init(id: id, name: name)
    }
}

/// Parkings récemment consultés dans l'app.
private func loadRecentParkings() -> [[String: String]] {
    AppGroup.defaults?.array(forKey: "recentParkings") as? [[String: String]] ?? []
}

struct ParkingEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ParkingEntity] {
        loadRecentParkings()
            .compactMap(ParkingEntity.init(dict:))
            .filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ParkingEntity] {
        loadRecentParkings().prefix(10).compactMap(ParkingEntity.init(dict:))
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
        loadRecentParkings().prefix(20).compactMap(ParkingEntity.init(dict:))
    }

    func defaultResult() async -> ParkingEntity? {
        try? await results().first
    }
}
