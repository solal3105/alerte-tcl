import Foundation
import CoreLocation
import Shared

#if DEBUG
/// Mode démo piloté par argument de lancement, pour provoquer à la demande les
/// états particuliers de l'interface (capture d'écran, revue visuelle) sans
/// dépendre de l'état réel du réseau TCL. Inactif en build Release.
///
/// Usage : lancer l'app avec `-demo <cas>` :
///   ages          véhicules aux fraîcheurs variées (vert / orange, le troisième a quitté la carte)
///   fiche         fiche véhicule ouverte, position fraîche
///   fiche-vieille fiche véhicule ouverte, position obsolète (véhicule parti de la carte)
///   vide          flux véhicules vide → capsule "TCL ne transmet aucune position"
///   erreur401     la source refuse l'accès → capsule erreur + feuille détaillée
///   fige          1er fetch OK puis pannes → capsule "Dernières données reçues il y a X"
///   arret         fiche arrêt avec passages estimés (pastille verte) et théoriques
///   bus-arret     carte filtrée sur les bus de la première ligne de l'arrêt de démo
///   horaires      recherche d'une ligne dans les fiches horaires théoriques
///   horaires-ligne  choix du sens d'une ligne à deux sens
///   horaires-arrets liste des arrêts d'un sens de cette ligne
///   horaires-arret  fiche arrêt puis fiche horaire de sa première ligne
///   horaires-course détail de la prochaine course depuis cette fiche horaire
///   parking       fiche du parc relais St-Genis (pas de disponibilité temps réel)
///   alertes       écran des alertes avec deux abonnements et des perturbations simulées
///   alertes-ligne fiche d'une ligne abonnée (C12) depuis cet écran
///   alertes-options feuille « Options de notification » de cette ligne
///   suivi         fiche arrêt avec « où est mon bus », puis suivi du premier bus dans l'activité en direct
///   velov         stations Vélo'v affichées sur la carte
///   velov-station fiche d'une station Vélo'v
enum DemoShowcase {
    static let current: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return nil }
        // Le module partagé simule aussi ses données (stations Vélo'v) dans le même cas.
        Shared.DemoShowcase.shared.current = args[i + 1]
        return args[i + 1]
    }()

    static var isActive: Bool { current != nil }

    /// `-ouvrir-arret <id>` : ouvre la fiche de cet arrêt avec les vraies données dès que les arrêts sont chargés.
    static let stopToOpen: Int? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-ouvrir-arret"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }()

    /// Délai avant d'enchaîner un écran sur un autre : la transition précédente doit être terminée.
    static let pushDelayNanoseconds: UInt64 = 900_000_000

    /// Place Bellecour — centre de la scène démo.
    static let center = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)

    /// Compteur de fetchs pour le cas "fige" (1er OK, suivants en panne).
    static var vehicleFetchCount = 0

    /// Cas « alertes », « alertes-ligne », « alertes-options » : écran des alertes avec abonnements.
    static var isAlertsCase: Bool { current?.hasPrefix("alertes") == true }

    /// Alertes factices, les mêmes que côté Kotlin (`DemoShowcase.alerts`).
    static func alerts() -> [TCLAlert] {
        Shared.DemoShowcase.shared.alerts().map { a in
            TCLAlert(
                id: a.id, type: a.type, cause: a.cause,
                debut: a.debutEpoch.map { Date(timeIntervalSince1970: TimeInterval($0.int64Value)) },
                fin: a.finEpoch.map { Date(timeIntervalSince1970: TimeInterval($0.int64Value)) },
                mode: TransportMode(rawValue: a.mode.displayName) ?? .bus,
                ligneCom: a.ligneCom, ligneCli: a.ligneCli, titre: a.titre, message: a.message
            )
        }
    }

    /// Abonnements factices : C12 (tous les types) et T1 (sans les informations).
    static func subscriptions() -> [String: LineSubscription] {
        Shared.DemoShowcase.shared.subscriptions()
    }

    /// Véhicules factices : un frais (vert), un vieillissant (orange),
    /// un obsolète (parti de la carte, sa fiche le signale), un tram frais.
    static func vehicles() -> [Vehicle] {
        let now = Date()
        func make(_ fleet: String, _ line: String, _ type: VehicleType,
                  _ dLat: Double, _ dLon: Double, ageSeconds: TimeInterval,
                  bearing: Double, destination: String) -> Vehicle {
            Vehicle(
                id: "ActIV:Vehicle:Bus:\(fleet):LOC",
                latitude: center.latitude + dLat,
                longitude: center.longitude + dLon,
                bearing: bearing,
                lineRef: "ActIV:Line::\(line):SYTRAL",
                lineName: line,
                vehicleType: type,
                destination: destination,
                direction: "",
                delay: 120,
                status: nil,
                recordedAt: now.addingTimeInterval(-ageSeconds),
                validUntil: now.addingTimeInterval(60 - ageSeconds),
                nextStop: StopInfo(
                    id: "ActIV:StopArea:SP:11518:SYTRAL",
                    stopRef: "ActIV:StopArea:SP:11518:SYTRAL",
                    stopName: "Bellecour A. Poncet",
                    aimedArrivalTime: now.addingTimeInterval(180),
                    aimedDepartureTime: now.addingTimeInterval(200),
                    distanceFromStop: 350,
                    order: 4
                )
            )
        }
        return [
            make("2101", "C12", .bus,     0.0006,  0.0008, ageSeconds: 12,  bearing: 45,  destination: "Hôpital Feyzin Vénissieux"),
            make("2102", "C25", .bus,    -0.0007,  0.0010, ageSeconds: 75,  bearing: 190, destination: "Saint-Genis 2"),
            make("2103", "27",  .bus,     0.0009, -0.0009, ageSeconds: 200, bearing: 300, destination: "Gare Saint-Paul"),
            make("881",  "T1",  .tram,   -0.0004, -0.0012, ageSeconds: 20,  bearing: 10,  destination: "IUT Feyssine"),
        ]
    }

    /// Le véhicule à ouvrir dans la fiche selon le cas ("fiche" ou "fiche-vieille").
    static func vehicleForSheet() -> Vehicle? {
        let all = vehicles()
        switch current {
        case "fiche":         return all[0]
        case "fiche-vieille": return all[2]
        default:              return nil
        }
    }

    /// Passages factices : deux estimés en temps réel (E) et deux théoriques (T).
    static func passages(stopId: Int) -> [Passage] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "fr_FR")
        func at(_ minutes: Int) -> String { formatter.string(from: Date().addingTimeInterval(TimeInterval(minutes * 60))) }
        return [
            Passage(stopId: stopId, ligne: "C12", direction: "Hôpital Feyzin Vénissieux", delaipassage: "3 min",  heurepassage: at(3),  type: "E"),
            Passage(stopId: stopId, ligne: "C12", direction: "Hôpital Feyzin Vénissieux", delaipassage: "12 min", heurepassage: at(12), type: "E"),
            Passage(stopId: stopId, ligne: "C12", direction: "Hôpital Feyzin Vénissieux", delaipassage: "25 min", heurepassage: at(25), type: "T"),
            Passage(stopId: stopId, ligne: "C12", direction: "Hôpital Feyzin Vénissieux", delaipassage: "40 min", heurepassage: at(40), type: "T"),
        ]
    }

    /// Filtre « bus de cet arrêt » pour la première ligne de l'arrêt de démo.
    static func stopLineFocus() -> StopLineFocus {
        let stop = mergedStop()
        let passage = passages(stopId: stop.stops[0].id)[0]
        return StopLineFocus(line: passage.ligne, direction: "A", destination: passage.direction,
                             stopName: stop.nom, latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude, vehicleId: nil)
    }

    /// Arrêt fusionné factice pointant sur un vrai id d'arrêt (11518, Bellecour A. Poncet),
    /// pour que le chargement des passages passe par le circuit normal.
    static func mergedStop() -> MergedStop {
        let stop = TransitStop(
            id: 11518,
            nom: "Bellecour A. Poncet",
            commune: "Lyon 2ème",
            adresse: nil,
            coordinate: center,
            desserte: "C12:A",
            pmr: true
        )
        return MergedStop(
            id: "demo-11518",
            nom: "Bellecour A. Poncet",
            coordinate: center,
            stops: [stop],
            directions: ["Hôpital Feyzin Vénissieux"]
        )
    }
}
#endif
