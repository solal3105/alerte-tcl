import Foundation
import WidgetKit

/// Les widgets de Lyon Pocket : identifiant WidgetKit, textes de la galerie et tailles proposées.
///
/// La même liste sert à l'extension (déclaration des widgets, rechargement des chronologies)
/// et à l'application (galerie « Widgets » de l'onglet Info).
enum WidgetKind: String, CaseIterable, Identifiable {
    case departures = "LyonPocket.Departures"
    case board = "LyonPocket.Board"
    case parking = "LyonPocket.Parking"
    case velov = "LyonPocket.Velov"
    case works = "LyonPocket.Works"
    case traffic = "LyonPocket.Traffic"

    var id: String { rawValue }

    /// Nom affiché dans la galerie de widgets d'iOS.
    var title: String {
        switch self {
        case .departures: "Prochains passages"
        case .board: "Tableau de départs"
        case .parking: "Places de parking"
        case .velov: "Station Vélo'v"
        case .works: "Travaux autour de moi"
        case .traffic: "Trafic sur mes lignes"
        }
    }

    /// Une phrase qui dit ce que le widget montre.
    var summary: String {
        switch self {
        case .departures: "Les prochains passages d'une ligne à votre arrêt, dans le sens que vous prenez."
        case .board: "Le prochain départ de plusieurs arrêts, comme un tableau en gare."
        case .parking: "Les places libres d'un parking ou d'un parc relais, en direct."
        case .velov: "Les vélos et les places d'une station Vélo'v, ou de la plus proche de vous."
        case .works: "La carte des chantiers autour de votre position, avec les plus proches."
        case .traffic: "L'état des lignes que vous suivez et les perturbations en cours."
        }
    }

    /// Comment on le règle, expliqué dans la galerie de l'application.
    var setupHint: String {
        switch self {
        case .departures, .board:
            "Enregistrez d'abord un arrêt depuis sa fiche dans Lyon Pocket, puis choisissez-le en maintenant le widget appuyé."
        case .parking:
            "Maintenez le widget appuyé pour choisir le parking : tous les parkings et parcs relais de la Métropole sont proposés."
        case .velov:
            "Sans réglage, le widget suit la station la plus proche de vous. Maintenez-le appuyé pour fixer une station."
        case .works:
            "Il utilise votre position, avec votre accord, et se règle sur 500 m, 1 km ou 2 km autour de vous."
        case .traffic:
            "Il suit les lignes auxquelles vous êtes abonné dans Lyon Pocket ; abonnez-vous depuis le trafic de la carte."
        }
    }

    var symbol: String {
        switch self {
        case .departures: "clock.fill"
        case .board: "list.bullet.rectangle.fill"
        case .parking: "parkingsign"
        case .velov: "bicycle"
        case .works: "hammer.fill"
        case .traffic: "exclamationmark.triangle.fill"
        }
    }

    var families: [WidgetFamily] {
        switch self {
        case .departures: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .board: [.systemMedium, .systemLarge]
        case .parking: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .velov: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .works: [.systemSmall, .systemMedium, .systemLarge]
        case .traffic: [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
        }
    }

    /// Les tailles, en mots, pour la galerie de l'application.
    var familiesText: String {
        var parts: [String] = []
        if families.contains(.systemSmall) { parts.append("petit") }
        if families.contains(.systemMedium) { parts.append("moyen") }
        if families.contains(.systemLarge) { parts.append("grand") }
        if families.contains(.accessoryRectangular) { parts.append("écran verrouillé") }
        return parts.joined(separator: ", ")
    }
}

/// Lien profond entre un widget et l'application (`alertetcl://…`).
///
/// L'extension construit l'adresse, l'application la relit : une seule grammaire pour les deux.
enum WidgetLink: Equatable {
    /// Fiche d'un arrêt (quai) sur la carte Transport.
    case stop(Int)
    /// Fiche d'un parking ou d'un parc relais (identifiant du jeu de données).
    case parking(String)
    /// Fiche d'une station Vélo'v (numéro de station).
    case velov(Int)
    /// Carte des chantiers, éventuellement centrée sur l'un d'eux.
    case works(String?)
    /// Feuille du trafic sur la carte Transport.
    case traffic
    /// Galerie des widgets, dans l'onglet Info.
    case widgets

    static let scheme = "alertetcl"

    private static let parkingIdPattern = /^[A-Za-z0-9_-]{1,64}$/
    private static let worksIdPattern = /^[A-Za-z0-9_.-]{1,64}$/

    var url: URL {
        let path: String
        switch self {
        case .stop(let id): path = "arret/\(id)"
        case .parking(let id): path = "parking/\(id)"
        case .velov(let id): path = "velov/\(id)"
        case .works(let id): path = id.map { "travaux/\($0)" } ?? "travaux"
        case .traffic: path = "trafic"
        case .widgets: path = "widgets"
        }
        // Les identifiants sont validés à la construction ; l'adresse est donc toujours formée.
        return URL(string: "\(Self.scheme)://\(path)") ?? URL(fileURLWithPath: "/")
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host else { return nil }
        let argument = url.pathComponents.dropFirst().first
        switch host {
        case "arret":
            guard let argument, let id = Int(argument), id > 0 else { return nil }
            self = .stop(id)
        case "parking":
            guard let argument, (try? Self.parkingIdPattern.wholeMatch(in: argument)) != nil else { return nil }
            self = .parking(argument)
        case "velov":
            guard let argument, let id = Int(argument), id > 0 else { return nil }
            self = .velov(id)
        case "travaux":
            if let argument {
                guard (try? Self.worksIdPattern.wholeMatch(in: argument)) != nil else { return nil }
                self = .works(argument)
            } else {
                self = .works(nil)
            }
        case "trafic":
            self = .traffic
        case "widgets":
            self = .widgets
        default:
            return nil
        }
    }
}
