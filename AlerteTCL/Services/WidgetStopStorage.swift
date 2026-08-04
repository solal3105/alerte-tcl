import Foundation
import WidgetKit

// MARK: - Widget Stop Selection Model

struct WidgetStopSelection: Codable, Identifiable, Equatable {
    let id: String
    let stopId: Int
    let stopName: String
    let line: String
    let direction: String
    let terminusName: String

    init(stopId: Int, stopName: String, line: String, direction: String, terminusName: String = "") {
        self.id = "\(stopId)-\(line)-\(direction)"
        self.stopId = stopId
        self.stopName = stopName
        self.line = line
        self.direction = direction
        self.terminusName = terminusName
    }
}

// MARK: - Widget Stop Storage Service

@MainActor
class WidgetStopStorage: ObservableObject {
    static let shared = WidgetStopStorage()
    
    private let defaults = AppGroup.defaults
    private let storageKey = "widgetStops"
    private let maxSelections = 30
    
    @Published private(set) var selections: [WidgetStopSelection] = []
    
    private init() {
        loadSelections()
    }
    
    // MARK: - Public API
    
    func addSelection(_ selection: WidgetStopSelection) {
        // Supprimer si déjà existant (pour le remonter)
        selections.removeAll { $0.id == selection.id }
        
        // Ajouter en tête
        selections.insert(selection, at: 0)
        
        // Limiter le nombre
        if selections.count > maxSelections {
            selections = Array(selections.prefix(maxSelections))
        }
        
        save()
        reloadWidgets()
    }
    
    func moveSelection(from source: IndexSet, to destination: Int) {
        selections.move(fromOffsets: source, toOffset: destination)
        save()
        reloadWidgets()
    }
    
    func hasSelection(stopId: Int, line: String, direction: String) -> Bool {
        let id = "\(stopId)-\(line)-\(direction)"
        return selections.contains { $0.id == id }
    }
    
    // MARK: - Private
    
    private func loadSelections() {
        guard let data = defaults?.array(forKey: storageKey) as? [[String: Any]] else {
            selections = []
            return
        }
        
        selections = data.compactMap { dict in
            guard let stopId = dict["stopId"] as? Int,
                  let stopName = dict["stopName"] as? String,
                  let lineName = dict["lineName"] as? String,
                  let direction = dict["direction"] as? String else {
                return nil
            }
            return WidgetStopSelection(stopId: stopId, stopName: stopName, line: lineName, direction: direction, terminusName: dict["terminusName"] as? String ?? "")
        }
    }
    
    private func save() {
        let data: [[String: Any]] = selections.map { selection in
            [
                "id": selection.id,
                "stopId": selection.stopId,
                "stopName": selection.stopName,
                "lineName": selection.line,
                "direction": selection.direction,
                "terminusName": selection.terminusName
            ]
        }
        
        defaults?.set(data, forKey: storageKey)

        // Index de résolution jamais purgé : permet à l'extension widget de
        // résoudre une StopEntity même si la sélection a été évincée/supprimée
        var index = defaults?.dictionary(forKey: "widgetStopsIndex") as? [String: [String: Any]] ?? [:]
        for dict in data {
            if let id = dict["id"] as? String {
                index[id] = dict
            }
        }
        defaults?.set(index, forKey: "widgetStopsIndex")
        defaults?.synchronize()
    }
    
    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NextDeparturesWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TCLBoardWidget")
    }
}
