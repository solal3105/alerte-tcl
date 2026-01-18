import Foundation

// MARK: - Widget Stop Selection Model

struct WidgetStopSelection: Codable, Identifiable, Equatable {
    let id: String
    let stopId: Int
    let stopName: String
    let line: String
    let direction: String
    let dateAdded: Date
    
    init(stopId: Int, stopName: String, line: String, direction: String) {
        self.id = "\(stopId)|\(line)|\(direction)"
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

class WidgetStopStorage {
    static let shared = WidgetStopStorage()
    
    private let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
    private let storageKey = "widgetStopSelections"
    private let maxSelections = 10
    
    private init() {}
    
    // MARK: - Public API
    
    func getAllSelections() -> [WidgetStopSelection] {
        guard let data = defaults?.data(forKey: storageKey),
              let selections = try? JSONDecoder().decode([WidgetStopSelection].self, from: data) else {
            return []
        }
        return selections.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func addSelection(_ selection: WidgetStopSelection) {
        var selections = getAllSelections()
        
        // Supprimer si déjà existant (pour le remonter)
        selections.removeAll { $0.id == selection.id }
        
        // Ajouter en tête
        selections.insert(selection, at: 0)
        
        // Limiter le nombre
        if selections.count > maxSelections {
            selections = Array(selections.prefix(maxSelections))
        }
        
        save(selections)
    }
    
    func removeSelection(withId id: String) {
        var selections = getAllSelections()
        selections.removeAll { $0.id == id }
        save(selections)
    }
    
    func hasSelection(stopId: Int, line: String, direction: String) -> Bool {
        let id = "\(stopId)|\(line)|\(direction)"
        return getAllSelections().contains { $0.id == id }
    }
    
    func clearAll() {
        defaults?.removeObject(forKey: storageKey)
    }
    
    // MARK: - Private
    
    private func save(_ selections: [WidgetStopSelection]) {
        guard let data = try? JSONEncoder().encode(selections) else { return }
        defaults?.set(data, forKey: storageKey)
    }
}
