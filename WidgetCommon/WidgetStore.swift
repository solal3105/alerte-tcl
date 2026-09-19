import Foundation

/// Arrêt choisi dans l'application pour les widgets de passages : un quai, une ligne, un sens.
struct WidgetStop: Codable, Identifiable, Hashable {
    let stopId: Int
    let stopName: String
    let line: String
    /// Terminus du sens, tel qu'il est affiché dans la fiche de l'arrêt.
    let direction: String

    var id: String { "\(stopId)|\(line)|\(direction)" }
}

/// Jetons de couleur publiés par l'application (valeurs de `AppColors`, module partagé), pour que
/// l'extension, qui ne lie pas le module Kotlin, dessine exactement avec les mêmes couleurs.
struct WidgetThemeTokens: Codable, Equatable {
    struct Themed: Codable, Equatable {
        let light: String
        let dark: String
    }

    let accent: Themed
    let success: Themed
    let warning: Themed
    let error: Themed
    let neutral: Themed
    let neutralFill: Themed
    let neutralBorder: Themed
    let velov: Themed
    /// Avancement d'un chantier : onze paliers, de 0 % à 100 %.
    let worksProgress: [String]
}

/// Ce que l'application dépose dans le conteneur partagé et ce que l'extension y relit.
///
/// Tout passe par du JSON `Codable` : arrêts choisis, lignes suivies, couleurs, et les derniers
/// chargements réussis de chaque widget (pour rester utile quand le réseau manque).
enum WidgetStore {
    private enum Key {
        static let stops = "widget.stops"
        /// Index jamais purgé : un widget déjà réglé sur un arrêt retiré de la liste reste lisible.
        static let stopsIndex = "widget.stopsIndex"
        /// Enregistrements d'avant la refonte (dictionnaires) : liste des arrêts et index des identifiants « quai-ligne-sens ».
        static let legacyStops = "widgetStops"
        static let legacyStopsIndex = "widgetStopsIndex"
        static let subscribedLines = "widget.subscribedLines"
        static let theme = "widget.theme"
        static let cachePrefix = "widget.cache."
    }

    private static var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - Lecture et écriture génériques

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults?.set(data, forKey: key)
    }

    // MARK: - Arrêts des widgets de passages

    static var stops: [WidgetStop] {
        get {
            if let current = load([WidgetStop].self, key: Key.stops) { return current }
            // Première lecture après la mise à jour : les arrêts enregistrés avant la refonte sont repris tels quels.
            let migrated = (defaults?.array(forKey: Key.legacyStops) as? [[String: Any]] ?? []).compactMap(legacyStop)
            if !migrated.isEmpty { save(migrated, key: Key.stops) }
            return migrated
        }
        set {
            save(newValue, key: Key.stops)
            var index = load([String: WidgetStop].self, key: Key.stopsIndex) ?? [:]
            for stop in newValue { index[stop.id] = stop }
            save(index, key: Key.stopsIndex)
        }
    }

    /// L'arrêt d'un identifiant, dans la liste courante, dans l'index, puis dans l'index d'avant la refonte
    /// (un widget posé avant la mise à jour garde son réglage).
    static func stop(id: String) -> WidgetStop? {
        if let current = stops.first(where: { $0.id == id }) { return current }
        if let indexed = load([String: WidgetStop].self, key: Key.stopsIndex)?[id] { return indexed }
        let legacyIndex = defaults?.dictionary(forKey: Key.legacyStopsIndex) as? [String: [String: Any]] ?? [:]
        return legacyIndex[id].flatMap(legacyStop)
    }

    private static func legacyStop(_ dict: [String: Any]) -> WidgetStop? {
        guard let stopId = dict["stopId"] as? Int, let stopName = dict["stopName"] as? String,
              let line = dict["lineName"] as? String, let direction = dict["direction"] as? String else { return nil }
        return WidgetStop(stopId: stopId, stopName: stopName, line: line, direction: direction)
    }

    // MARK: - Lignes suivies (abonnements aux notifications)

    static var subscribedLines: [String] {
        get { load([String].self, key: Key.subscribedLines) ?? [] }
        set { save(newValue, key: Key.subscribedLines) }
    }

    // MARK: - Couleurs

    static var theme: WidgetThemeTokens? {
        get { load(WidgetThemeTokens.self, key: Key.theme) }
        set {
            if let newValue { save(newValue, key: Key.theme) } else { defaults?.removeObject(forKey: Key.theme) }
        }
    }

    // MARK: - Derniers chargements réussis

    private struct Cached<T: Codable>: Codable {
        let savedAt: Date
        let value: T
    }

    static func cache<T: Codable>(_ value: T, key: String) {
        save(Cached(savedAt: Date(), value: value), key: Key.cachePrefix + key)
    }

    /// La valeur enregistrée sous `key` si elle a moins de `maxAge` secondes, avec son âge.
    static func cached<T: Codable>(_ type: T.Type, key: String, maxAge: TimeInterval) -> (value: T, savedAt: Date)? {
        guard let cached = load(Cached<T>.self, key: Key.cachePrefix + key) else { return nil }
        guard Date().timeIntervalSince(cached.savedAt) <= maxAge else { return nil }
        return (cached.value, cached.savedAt)
    }
}
