import Foundation
import CoreLocation
import SwiftUI

enum ParkingType: String, Codable, CaseIterable {
    case car = "Voiture"
    case bike = "Vélo"
    case motorized2Wheel = "2 roues motorisé"
    
    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .bike: return "bicycle"
        case .motorized2Wheel: return "motorcycle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .car: return "blue"
        case .bike: return "green"
        case .motorized2Wheel: return "orange"
        }
    }
}

struct ParkingResponse: Codable {
    let type: String
    let features: [ParkingFeature]
}

struct ParkingFeature: Codable {
    let type: String
    let id: String
    let geometry: ParkingGeometry
    let properties: ParkingProperties
}

struct ParkingGeometry: Codable {
    let type: String
    let coordinates: [Double]
    
    var coordinate: CLLocationCoordinate2D? {
        CLLocationCoordinate2D.fromGeoJSON(coordinates)
    }
}

struct ParkingProperties: Codable {
    let gid: Int
    let id: String?
    let nom: String
    let gestionnaire: String?
    let idGestionnaire: String?
    let insee: String?
    let adresse: String?
    let url: String?
    let typeUsagers: String?
    let gratuit: Bool?
    let nbPlaces: Int?
    let nbPr: Int?
    let nbPmr: Int?
    let nbVoituresElectriques: Int?
    let nbVelo: Int?
    let nb2rEl: Int?
    let nbAutopartage: Int?
    let nb2Rm: Int?
    let nbCovoit: Int?
    let hauteurMax: String?
    let numSiret: String?
    let tarifPmr: Double?
    let tarif1h: Double?
    let tarif2h: Double?
    let tarif3h: Double?
    let tarif4h: Double?
    let tarif24h: Double?
    let aboResident: Double?
    let aboNonResident: Double?
    let typeOuvrage: String?
    let info: String?
    let placesDisponibles: Int?
    let etat: String?
    let lastUpdate: String?
    
    let commune: String?
    let codeinsee: String?
    let avancement: String?
    let mobiliervelo: String?
    let localisation: String?
    let abrite: Bool?
    let duree: String?
    let nbarceaux: Int?
    let capacite: Int?
    let anneerealisation: Int?
    let arceauxprojetes: Int?
    let pole: String?
    let observation: String?
    let validite: String?
    
    let numeroVoie: String?
    let arrondissement: String?
    let longueur: Double?  // Double car l'API peut renvoyer des valeurs décimales (ex: 7.5)
    let datemaj: String?
    
    enum CodingKeys: String, CodingKey {
        case gid, id, nom, gestionnaire, insee, adresse, url, gratuit, info, etat
        case idGestionnaire = "id_gestionnaire"
        case typeUsagers = "type_usagers"
        case nbPlaces = "nb_places"
        case nbPr = "nb_pr"
        case nbPmr = "nb_pmr"
        case nbVoituresElectriques = "nb_voitures_electriques"
        case nbVelo = "nb_velo"
        case nb2rEl = "nb_2r_el"
        case nbAutopartage = "nb_autopartage"
        case nb2Rm = "nb_2_rm"
        case nbCovoit = "nb_covoit"
        case hauteurMax = "hauteur_max"
        case numSiret = "num_siret"
        case tarifPmr = "tarif_pmr"
        case tarif1h = "tarif_1h"
        case tarif2h = "tarif_2h"
        case tarif3h = "tarif_3h"
        case tarif4h = "tarif_4h"
        case tarif24h = "tarif_24h"
        case aboResident = "abo_resident"
        case aboNonResident = "abo_non_resident"
        case typeOuvrage = "type_ouvrage"
        case placesDisponibles = "places_disponibles"
        case lastUpdate = "last_update"
        
        case commune, codeinsee, avancement, mobiliervelo, localisation, abrite, duree, nbarceaux, capacite, anneerealisation, arceauxprojetes, pole, observation, validite
        case numeroVoie = "numero_voie"
        case arrondissement, longueur, datemaj
    }
}

struct Parking: Identifiable, Hashable, Sendable {
    let id: String
    let gid: Int
    let nom: String
    let gestionnaire: String
    let adresse: String
    let coordinate: CLLocationCoordinate2D
    let capaciteTotale: Int
    let placesDisponibles: Int
    let etat: ParkingState
    let lastUpdate: Date?
    let parkingType: ParkingType

    // Parc Relais
    let isParcRelais: Bool
    let horaires: String?
    let surveille: Bool?
    /// false = pas de données temps réel (P+R sans flux temps réel)
    let hasRealtimeData: Bool

    // Détails optionnels
    let url: String?
    let hauteurMax: String?
    let nbPmr: Int?
    let nbVoituresElectriques: Int?
    let nbVelo: Int?
    let nb2Rm: Int?
    let nbAutopartage: Int?

    // Tarifs
    let tarif1h: Double?
    let tarif2h: Double?
    let tarif3h: Double?
    let tarif4h: Double?
    let tarif24h: Double?
    let aboResident: Double?
    let aboNonResident: Double?
    let gratuit: Bool

    var tauxOccupation: Double {
        guard hasRealtimeData, capaciteTotale > 0 else { return 0 }
        return Double(capaciteTotale - placesDisponibles) / Double(capaciteTotale)
    }

    /// Couleur de disponibilité unifiée : gris si pas de données, sinon vert → rouge.
    var availabilityColor: Color {
        guard hasRealtimeData else { return .gray }
        if !isParcRelais, etat != .ouvert { return .gray }
        switch tauxOccupation {
        case ..<0.5:  return .green
        case 0.5..<0.8: return .orange
        default:        return .red
        }
    }

    var isFull: Bool {
        guard hasRealtimeData else { return false }
        return placesDisponibles == 0 || etat == .complet
    }

    static func == (lhs: Parking, rhs: Parking) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Init depuis l'API parking standard

    init?(from feature: ParkingFeature, type: ParkingType = .car) {
        guard let coordinate = feature.geometry.coordinate else { return nil }
        self.id = feature.properties.id ?? "\(feature.properties.gid)"
        self.gid = feature.properties.gid
        self.nom = feature.properties.nom
        self.parkingType = type
        self.isParcRelais = false
        self.horaires = nil
        self.surveille = nil
        self.hasRealtimeData = true

        switch type {
        case .car:
            self.gestionnaire = feature.properties.gestionnaire ?? "Non spécifié"
            self.adresse = feature.properties.adresse ?? "Adresse non disponible"
            self.capaciteTotale = feature.properties.nbPlaces ?? 0
            self.placesDisponibles = feature.properties.placesDisponibles ?? 0
            self.etat = ParkingState(rawValue: feature.properties.etat ?? "inconnu") ?? .inconnu
        case .bike:
            self.gestionnaire = feature.properties.gestionnaire ?? "Ville de Lyon"
            self.adresse = feature.properties.adresse ?? feature.properties.nom
            self.capaciteTotale = feature.properties.capacite ?? (feature.properties.nbarceaux ?? 0) * 2
            self.placesDisponibles = self.capaciteTotale
            self.etat = .ouvert
        case .motorized2Wheel:
            self.gestionnaire = "Ville de Lyon"
            let arrondissement = feature.properties.arrondissement ?? ""
            let numeroVoie = feature.properties.numeroVoie ?? ""
            self.adresse = numeroVoie.isEmpty ? feature.properties.nom : "\(numeroVoie) \(feature.properties.nom), \(arrondissement)e arr."
            self.capaciteTotale = Int(feature.properties.longueur ?? 0)
            self.placesDisponibles = self.capaciteTotale
            self.etat = .ouvert
        }

        self.coordinate = coordinate

        if let lastUpdateStr = feature.properties.lastUpdate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.lastUpdate = formatter.date(from: lastUpdateStr) ?? ISO8601DateFormatter().date(from: lastUpdateStr)
        } else {
            self.lastUpdate = nil
        }

        self.url = feature.properties.url
        self.hauteurMax = feature.properties.hauteurMax
        self.nbPmr = feature.properties.nbPmr
        self.nbVoituresElectriques = feature.properties.nbVoituresElectriques
        self.nbVelo = feature.properties.nbVelo
        self.nb2Rm = feature.properties.nb2Rm
        self.nbAutopartage = feature.properties.nbAutopartage

        self.tarif1h = feature.properties.tarif1h
        self.tarif2h = feature.properties.tarif2h
        self.tarif3h = feature.properties.tarif3h
        self.tarif4h = feature.properties.tarif4h
        self.tarif24h = feature.properties.tarif24h
        self.aboResident = feature.properties.aboResident
        self.aboNonResident = feature.properties.aboNonResident
        self.gratuit = feature.properties.gratuit ?? false
    }

    // MARK: - Init Parc Relais

    init(
        parcRelaisId: String,
        nom: String,
        coordinate: CLLocationCoordinate2D,
        capacite: Int,
        placesHandicap: Int,
        horaires: String?,
        surveille: Bool,
        placesDisponibles: Int?
    ) {
        self.id = "parc-relais-\(parcRelaisId)"
        self.gid = 0
        self.nom = nom
        self.gestionnaire = "SYTRAL"
        self.adresse = ""
        self.coordinate = coordinate
        self.parkingType = .car
        self.isParcRelais = true
        self.horaires = horaires
        self.surveille = surveille
        self.hasRealtimeData = placesDisponibles != nil
        self.capaciteTotale = capacite
        self.placesDisponibles = placesDisponibles ?? 0
        self.etat = .ouvert
        self.lastUpdate = nil
        self.url = nil
        self.hauteurMax = nil
        self.nbPmr = placesHandicap
        self.nbVoituresElectriques = nil
        self.nbVelo = nil
        self.nb2Rm = nil
        self.nbAutopartage = nil
        self.tarif1h = nil
        self.tarif2h = nil
        self.tarif3h = nil
        self.tarif4h = nil
        self.tarif24h = nil
        self.aboResident = nil
        self.aboNonResident = nil
        self.gratuit = true
    }
}

enum ParkingState: String, Codable {
    case ouvert = "ouvert"
    case ferme = "ferme"
    case complet = "complet"
    case inconnu = "inconnu"
    
    var displayName: String {
        switch self {
        case .ouvert: return "Ouvert"
        case .ferme: return "Fermé"
        case .complet: return "Complet"
        case .inconnu: return "Inconnu"
        }
    }
    
    var icon: String {
        switch self {
        case .ouvert: return "checkmark.circle.fill"
        case .ferme: return "xmark.circle.fill"
        case .complet: return "exclamationmark.circle.fill"
        case .inconnu: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Clusterable Conformance

extension Parking: Clusterable {
    var clusterColor: Color {
        switch parkingType {
        case .bike:          return .green
        case .motorized2Wheel: return .orange
        case .car:           return availabilityColor
        }
    }

    var clusterIcon: String {
        isParcRelais ? "car.fill" : parkingType.icon
    }
}
