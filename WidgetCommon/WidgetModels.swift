import Foundation
import UIKit
import WidgetKit

/// État commun des entrées : prêtes, pas encore réglées, ou données indisponibles.
enum WidgetStatus: Equatable {
    case ready
    case notConfigured
    case unavailable
}

// MARK: - Passages

/// Un prochain passage à une heure absolue ; le texte affiché se calcule pour la date de l'entrée,
/// ce qui permet une entrée par minute sans nouvelle requête.
struct WidgetDeparture: Codable, Hashable, Identifiable {
    let time: Date
    /// Passage estimé en temps réel (« E ») plutôt qu'horaire théorique (« T »).
    let realTime: Bool

    var id: Date { time }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "fr_FR")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f
    }()

    /// Minutes entières avant le passage (négatif s'il est passé).
    func minutes(at date: Date) -> Int {
        Int(floor(time.timeIntervalSince(date) / 60))
    }

    private static var parisCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// Avant 4 h du matin, on est encore sur la journée de service de la veille (même règle que les fiches horaires).
    private static let serviceDayStartHour = 4

    private static func serviceDay(of date: Date) -> Date {
        let calendar = Self.parisCalendar
        let day = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < serviceDayStartHour,
              let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return day }
        return previous
    }

    /// « demain » quand le passage est le lendemain, le jour en abrégé au-delà ; rien le jour même ni
    /// dans la même journée de service (un passage à 01:20 vu à 23:50 est « cette nuit », pas demain).
    func dayLabel(at date: Date) -> String? {
        let calendar = Self.parisCalendar
        guard !calendar.isDate(time, inSameDayAs: date), Self.serviceDay(of: time) != Self.serviceDay(of: date) else { return nil }
        if calendar.isDate(time, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: date) ?? date) { return "demain" }
        return calendar.shortWeekdaySymbols[calendar.component(.weekday, from: time) - 1]
    }

    /// « À l'approche », « 4 min », l'heure au-delà de 59 minutes, « demain 05:12 » un autre jour.
    func label(at date: Date) -> String {
        let minutes = minutes(at: date)
        if minutes < 1 { return "À l'approche" }
        if minutes < 60 { return "\(minutes) min" }
        let hour = Self.timeFormatter.string(from: time)
        return dayLabel(at: date).map { "\($0) \(hour)" } ?? hour
    }

    /// Le chiffre seul pour les grands affichages ; « <1 » à l'approche, l'heure au-delà d'une heure.
    func figure(at date: Date) -> String {
        let minutes = minutes(at: date)
        if minutes < 1 { return "<1" }
        if minutes < 60 { return "\(minutes)" }
        return Self.timeFormatter.string(from: time)
    }

    /// Vrai quand le chiffre est en minutes (donc suivi de « min »).
    func isCountdown(at date: Date) -> Bool {
        minutes(at: date) < 60
    }

    var timeText: String { Self.timeFormatter.string(from: time) }
}

struct DeparturesEntry: TimelineEntry {
    let date: Date
    let status: WidgetStatus
    let stop: WidgetStop?
    let departures: [WidgetDeparture]
    /// Heure du dernier chargement réussi.
    let fetchedAt: Date?
    /// Données du dernier chargement réussi, faute de réseau.
    let stale: Bool
    /// Des passages viennent des fiches horaires théoriques (fin de service, lendemain).
    let theoretical: Bool

    static func notConfigured(date: Date = Date()) -> DeparturesEntry {
        DeparturesEntry(date: date, status: .notConfigured, stop: nil, departures: [], fetchedAt: nil, stale: false, theoretical: false)
    }

    static func unavailable(stop: WidgetStop, date: Date = Date()) -> DeparturesEntry {
        DeparturesEntry(date: date, status: .unavailable, stop: stop, departures: [], fetchedAt: nil, stale: false, theoretical: false)
    }
}

/// Une ligne du tableau de départs : un arrêt réglé et ses prochains passages.
struct BoardRow: Identifiable, Hashable {
    let stop: WidgetStop
    let departures: [WidgetDeparture]
    /// Chargement en échec, sans donnée récente en secours.
    let failed: Bool

    var id: String { stop.id }
}

struct BoardEntry: TimelineEntry {
    let date: Date
    let status: WidgetStatus
    let rows: [BoardRow]
    let fetchedAt: Date?

    static func notConfigured(date: Date = Date()) -> BoardEntry {
        BoardEntry(date: date, status: .notConfigured, rows: [], fetchedAt: nil)
    }
}

// MARK: - Parking

struct WidgetParkingSnapshot: Codable, Hashable {
    let id: String
    let name: String
    /// Absent quand l'exploitant ne transmet pas la disponibilité.
    let available: Int?
    let capacity: Int?
    let isParcRelais: Bool
    let open: Bool

    /// Même barème que l'application : gris sans temps réel ou fermé, vert sous 50 % de remplissage,
    /// orange sous 80 %, rouge au-delà.
    var availability: WidgetAvailability {
        guard let available, let capacity, capacity > 0, open else { return .unknown }
        let occupancy = Double(capacity - available) / Double(capacity)
        if occupancy < 0.5 { return .good }
        if occupancy < 0.8 { return .medium }
        return .low
    }

    /// Part des places libres, de 0 à 1.
    var freeFraction: Double {
        guard let available, let capacity, capacity > 0 else { return 0 }
        return min(1, max(0, Double(available) / Double(capacity)))
    }

    /// « 42 places », « Complet », « Fermé », « Sans temps réel » : le plus court qui reste juste.
    var statusText: String {
        if !open { return "Fermé" }
        guard let available else { return "Sans temps réel" }
        if available <= 0 { return "Complet" }
        return available == 1 ? "1 place" : "\(available) places"
    }
}

struct ParkingEntry: TimelineEntry {
    let date: Date
    let status: WidgetStatus
    let parking: WidgetParkingSnapshot?
    let fetchedAt: Date?
    let stale: Bool

    static func notConfigured(date: Date = Date()) -> ParkingEntry {
        ParkingEntry(date: date, status: .notConfigured, parking: nil, fetchedAt: nil, stale: false)
    }
}

// MARK: - Vélo'v

struct WidgetVelovSnapshot: Codable, Hashable {
    let id: Int
    let name: String
    let bikes: Int
    let ebikes: Int
    let stands: Int
    let capacity: Int
    let open: Bool
    /// Dernière mise à jour transmise par l'exploitant, affichée à la place de l'heure du chargement.
    let updated: Date?
    /// Distance depuis la position, quand le widget suit la station la plus proche.
    let distanceMeters: Double?

    /// Vert dès 3 vélos, orange à 1 ou 2, rouge sans vélo, gris quand la station est fermée.
    var availability: WidgetAvailability {
        if !open { return .unknown }
        if bikes <= 0 { return .low }
        if bikes <= 2 { return .medium }
        return .good
    }

    var distanceText: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 { return "à \(Int(distanceMeters.rounded(.up) / 10) * 10) m" }
        return String(format: "à %.1f km", distanceMeters / 1000).replacingOccurrences(of: ".", with: ",")
    }
}

struct VelovEntry: TimelineEntry {
    let date: Date
    let status: WidgetStatus
    let station: WidgetVelovSnapshot?
    /// Position refusée ou inconnue alors que le widget suit la station la plus proche.
    let needsLocation: Bool
    let fetchedAt: Date?
    let stale: Bool

    static func notConfigured(needsLocation: Bool, date: Date = Date()) -> VelovEntry {
        VelovEntry(date: date, status: .notConfigured, station: nil, needsLocation: needsLocation, fetchedAt: nil, stale: false)
    }
}

// MARK: - Travaux

struct WidgetWork: Codable, Hashable, Identifiable {
    let id: String
    /// Nature du chantier (« Aménagements cyclables »).
    let title: String
    let address: String
    let commune: String
    /// Avancement, de 0 à 100.
    let progress: Double
    let distanceMeters: Double

    var distanceText: String {
        if distanceMeters < 1000 { return "\(Int(distanceMeters.rounded(.up) / 10) * 10) m" }
        return String(format: "%.1f km", distanceMeters / 1000).replacingOccurrences(of: ".", with: ",")
    }
}

struct WorksEntry: TimelineEntry {
    let date: Date
    let status: WidgetStatus
    /// Chantiers du plus proche au plus lointain.
    let works: [WidgetWork]
    let radiusMeters: Int
    /// Position connue ; sinon la carte est centrée sur le centre de Lyon.
    let hasLocation: Bool
    let mapLight: UIImage?
    let mapDark: UIImage?
    let fetchedAt: Date?

    var radiusText: String {
        radiusMeters < 1000 ? "\(radiusMeters) m" : "\(radiusMeters / 1000) km"
    }

}

// MARK: - Trafic

struct WidgetTrafficLine: Codable, Hashable, Identifiable {
    let line: String
    let severity: WidgetSeverity
    /// Titre de l'alerte la plus grave de la ligne.
    let title: String

    var id: String { line }
}

struct TrafficEntry: TimelineEntry {
    let date: Date
    let status: WidgetStatus
    /// Lignes suivies dans l'application, dans l'ordre alphabétique.
    let subscribed: [String]
    /// Lignes suivies en perturbation, la plus grave en premier.
    let disrupted: [WidgetTrafficLine]
    /// Perturbations majeures sur tout le réseau.
    let networkMajor: Int
    let fetchedAt: Date?
    let stale: Bool

    static func notConfigured(date: Date = Date()) -> TrafficEntry {
        TrafficEntry(date: date, status: .notConfigured, subscribed: [], disrupted: [], networkMajor: 0, fetchedAt: nil, stale: false)
    }

    var hasMajor: Bool { disrupted.contains { $0.severity == .major } }

    /// Le titre de l'état : « Vos lignes circulent normalement », « 2 lignes perturbées »…
    var headline: String {
        if disrupted.isEmpty { return "Tout roule" }
        let major = disrupted.filter { $0.severity == .major }.count
        if major > 0 {
            return major == 1 ? "1 ligne en alerte majeure" : "\(major) lignes en alerte majeure"
        }
        return disrupted.count == 1 ? "1 ligne perturbée" : "\(disrupted.count) lignes perturbées"
    }

    var detail: String? {
        if disrupted.isEmpty {
            guard networkMajor > 0 else { return nil }
            return networkMajor == 1 ? "1 alerte majeure ailleurs sur le réseau" : "\(networkMajor) alertes majeures ailleurs sur le réseau"
        }
        let others = disrupted.filter { $0.severity != .major }.count
        guard disrupted.contains(where: { $0.severity == .major }), others > 0 else { return nil }
        return others == 1 ? "et 1 autre ligne perturbée" : "et \(others) autres lignes perturbées"
    }
}
