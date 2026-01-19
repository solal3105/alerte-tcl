import Foundation
import WidgetKit

// MARK: - Widget Stop Selection Model

struct WidgetStopSelection: Codable, Identifiable, Equatable {
    let id: String
    let stopId: Int
    let stopName: String
    let line: String
    let direction: String
    let dateAdded: Date
    
    init(stopId: Int, stopName: String, line: String, direction: String) {
        self.id = "\(stopId)-\(line)-\(direction)"
        self.stopId = stopId
        self.stopName = stopName
        self.line = line
        self.direction = direction
        self.dateAdded = Date()
    }
    
    var displayTitle: String {
        "\(line) → \(direction)"
    }
    
    var displaySubtitle: String {
        stopName
    }
}

// MARK: - Widget Stop Storage Service

class WidgetStopStorage: ObservableObject {
    static let shared = WidgetStopStorage()
    
    private let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
    private let storageKey = "widgetStops"
    private let maxSelections = 30
    
    @Published private(set) var selections: [WidgetStopSelection] = []
    
    private init() {
        loadSelections()
    }
    
    // MARK: - Public API
    
    func getAllSelections() -> [WidgetStopSelection] {
        return selections
    }
    
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
    
    func removeSelection(withId id: String) {
        selections.removeAll { $0.id == id }
        save()
        reloadWidgets()
    }
    
    func removeSelection(at index: Int) {
        guard index < selections.count else { return }
        selections.remove(at: index)
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
    
    func clearAll() {
        selections.removeAll()
        defaults?.removeObject(forKey: storageKey)
        reloadWidgets()
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
            return WidgetStopSelection(stopId: stopId, stopName: stopName, line: lineName, direction: direction)
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
                "addedAt": selection.dateAdded.timeIntervalSince1970
            ]
        }
        
        defaults?.set(data, forKey: storageKey)
        defaults?.synchronize()
    }
    
    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NextDeparturesWidget")
    }
}
