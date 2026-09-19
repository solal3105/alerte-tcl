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

    /// « À l'approche », « 4 min », ou l'heure au-delà de 59 minutes.
    func label(at date: Date) -> String {
        let minutes = minutes(at: date)
        if minutes < 1 { return "À l'approche" }
        if minutes < 60 { return "\(minutes) min" }
        return Self.timeFormatter.string(from: time)
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

    static func notConfigured(date: Date = Date()) -> DeparturesEntry {
        DeparturesEntry(date: date, status: .notConfigured, stop: nil, departures: [], fetchedAt: nil, stale: false)
    }

    static func unavailable(stop: WidgetStop, date: Date = Date()) -> DeparturesEntry {
        DeparturesEntry(date: date, status: .unavailable, stop: stop, departures: [], fetchedAt: nil, stale: false)
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

    var kindLabel: String { isParcRelais ? "Parc relais TCL" : "Parking" }

    /// « 42 places libres », « Complet », « Fermé », « Disponibilité inconnue ».
    var statusText: String {
        if !open { return "Fermé" }
        guard let available else { return "Disponibilité inconnue" }
        if available <= 0 { return "Complet" }
        return available == 1 ? "1 place libre" : "\(available) places libres"
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
    let address: String
    let bikes: Int
    let ebikes: Int
    let mbikes: Int
    let stands: Int
    let capacity: Int
    let open: Bool
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

    var bikesText: String {
        if !open { return "Station fermée" }
        if bikes <= 0 { return "Aucun vélo disponible" }
        return bikes == 1 ? "1 vélo disponible" : "\(bikes) vélos disponibles"
    }

    var standsText: String {
        if stands <= 0 { return "Aucune place libre" }
        return stands == 1 ? "1 place libre" : "\(stands) places libres"
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
    /// Le widget suit la station la plus proche de la position.
    let nearest: Bool
    /// Position refusée ou inconnue alors que le widget suit la station la plus proche.
    let needsLocation: Bool
    let fetchedAt: Date?
    let stale: Bool

    static func notConfigured(nearest: Bool, needsLocation: Bool, date: Date = Date()) -> VelovEntry {
        VelovEntry(date: date, status: .notConfigured, station: nil, nearest: nearest, needsLocation: needsLocation, fetchedAt: nil, stale: false)
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
    /// 1 très perturbant, 2 perturbant, 3 peu perturbant, 0 non renseigné.
    let importance: Int
    let distanceMeters: Double
    let end: Date?

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

    var countText: String {
        switch works.count {
        case 0: "Aucun chantier"
        case 1: "1 chantier"
        default: "\(works.count) chantiers"
        }
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
        if disrupted.isEmpty {
            return networkMajor == 0 ? "Vos lignes circulent normalement" : "Vos lignes sont normales"
        }
        let major = disrupted.filter { $0.severity == .major }.count
        if major > 0 {
            return major == 1 ? "1 ligne en alerte majeure" : "\(major) lignes en alerte majeure"
        }
        return disrupted.count == 1 ? "1 ligne perturbée" : "\(disrupted.count) lignes perturbées"
    }

    var detail: String? {
        if disrupted.isEmpty {
            guard networkMajor > 0 else { return nil }
            return networkMajor == 1 ? "1 perturbation majeure sur le réseau" : "\(networkMajor) perturbations majeures sur le réseau"
        }
        let others = disrupted.filter { $0.severity != .major }.count
        guard disrupted.contains(where: { $0.severity == .major }), others > 0 else { return nil }
        return others == 1 ? "et 1 autre ligne perturbée" : "et \(others) autres lignes perturbées"
    }
}
