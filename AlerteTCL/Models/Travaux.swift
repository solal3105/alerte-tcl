import Foundation
import CoreLocation
import SwiftUI

/// Type de chantier basé sur nature_chantier du dataset
enum TravauxNatureChantier: String, CaseIterable {
    case transportsCommun = "Transports en commun"
    case cyclab = "Aménagements cyclables"
    case espacePublic = "Espace public"
    case carrefour = "Carrefours"
    case assainissement = "Assainissement"
    case autre = "Autre"
    
    var icon: String {
        switch self {
        case .transportsCommun: return "tram.fill"
        case .cyclab: return "bicycle"
        case .espacePublic: return "building.2.fill"
        case .carrefour: return "arrow.triangle.branch"
        case .assainissement: return "pipe.and.drop.fill"
        case .autre: return "hammer.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .transportsCommun: return .purple
        case .cyclab: return .green
        case .espacePublic: return .blue
        case .carrefour: return .orange
        case .assainissement: return .brown
        case .autre: return .gray
        }
    }
    
    static func detect(from natureChantier: String?) -> TravauxNatureChantier {
        guard let nature = natureChantier?.lowercased() else { return .autre }
        
        if nature.contains("transport") || nature.contains("bus") || nature.contains("tram") {
            return .transportsCommun
        } else if nature.contains("cyclable") || nature.contains("vélo") || nature.contains("velo") || nature.contains("edp") {
            return .cyclab
        } else if nature.contains("espace public") || nature.contains("aménagement") {
            return .espacePublic
        } else if nature.contains("carrefour") {
            return .carrefour
        } else if nature.contains("assainissement") {
            return .assainissement
        }
        return .autre
    }
}

/// Type de travaux ancien (gardé pour compatibilité)
enum TravauxType: String, CaseIterable {
    case tramway = "Tramway"
    case metro = "Métro"
    case voirie = "Voirie"
    case eau = "Eau"
    case gaz = "Gaz"
    case electricite = "Électricité"
    case assainissement = "Assainissement"
    case telecom = "Télécom"
    case chauffage = "Chauffage"
    case pisteCyclable = "Piste cyclable"
    case autre = "Autre"
    
    var icon: String {
        switch self {
        case .tramway: return "tram.fill"
        case .metro: return "train.side.front.car"
        case .voirie: return "road.lanes"
        case .eau: return "drop.fill"
        case .gaz: return "flame.fill"
        case .electricite: return "bolt.fill"
        case .assainissement: return "pipe.and.drop.fill"
        case .telecom: return "antenna.radiowaves.left.and.right"
        case .chauffage: return "thermometer.medium"
        case .pisteCyclable: return "bicycle"
        case .autre: return "hammer.fill"
        }
    }
    
    var color: String {
        switch self {
        case .tramway: return "blue"
        case .metro: return "purple"
        case .voirie: return "gray"
        case .eau: return "cyan"
        case .gaz: return "orange"
        case .electricite: return "yellow"
        case .assainissement: return "brown"
        case .telecom: return "green"
        case .chauffage: return "red"
        case .pisteCyclable: return "mint"
        case .autre: return "gray"
        }
    }
    
    static func detect(from nomChantier: String) -> TravauxType {
        let nom = nomChantier.lowercased()
        
        if nom.contains("tramway") || nom.contains("tram") || nom.contains("bus") {
            return .tramway
        } else if nom.contains("métro") || nom.contains("metro") {
            return .metro
        } else if nom.contains("piste cyclable") || nom.contains("vélo") || nom.contains("velo") || nom.contains("cyclable") {
            return .pisteCyclable
        } else if nom.contains("eau") || nom.contains("aep") {
            return .eau
        } else if nom.contains("gaz") {
            return .gaz
        } else if nom.contains("électr") || nom.contains("electr") || nom.contains("éclairage") || nom.contains("eclairage") {
            return .electricite
        } else if nom.contains("assainissement") || nom.contains("égout") || nom.contains("egout") {
            return .assainissement
        } else if nom.contains("télécom") || nom.contains("telecom") || nom.contains("fibre") || nom.contains("réseau") {
            return .telecom
        } else if nom.contains("chauffage") || nom.contains("thermique") {
            return .chauffage
        } else if nom.contains("voirie") || nom.contains("chaussée") || nom.contains("chaussee") || nom.contains("revêtement") || nom.contains("revetement") || nom.contains("requalification") {
            return .voirie
        } else {
            return .autre
        }
    }
}

struct Travaux: Identifiable, Hashable {
    let id: String
    let nom: String
    let nomChantier: String
    let commune: String
    let codeInsee: String
    let precisionLocalisation: String?
    let debutChantier: Date?
    let finChantier: Date?
    let description: String?
    let avancement: TravauxAvancement
    let importance: TravauxImportance
    let typeperturbation: TravauxPerturbation
    let intervenant: String
    let coordinates: [[CLLocationCoordinate2D]]
    let centroid: CLLocationCoordinate2D
    let type: TravauxType
    let natureChantier: TravauxNatureChantier
    
    var isActive: Bool {
        guard let fin = finChantier else { return true }
        return fin >= Date()
    }
    
    var durationText: String {
        guard let debut = debutChantier else { return "Date inconnue" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        
        if let fin = finChantier {
            return "Du \(formatter.string(from: debut)) au \(formatter.string(from: fin))"
        } else {
            return "Depuis le \(formatter.string(from: debut))"
        }
    }
    
    var remainingDays: Int? {
        guard let fin = finChantier else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: fin)
        return components.day
    }
    
    /// Pourcentage de réalisation du chantier (0-100)
    /// Basé sur les dates de début et fin
    var completionPercentage: Double {
        guard let debut = debutChantier, let fin = finChantier else {
            // Si pas de dates, utiliser l'avancement
            switch avancement {
            case .termine: return 100
            case .enCours: return 50
            case .prevu: return 0
            case .inconnu: return 0
            }
        }
        
        let now = Date()
        
        // Pas encore commencé
        if now < debut {
            return 0
        }
        
        // Terminé
        if now >= fin {
            return 100
        }
        
        // En cours : calculer le pourcentage
        let totalDuration = fin.timeIntervalSince(debut)
        let elapsed = now.timeIntervalSince(debut)
        let percentage = (elapsed / totalDuration) * 100
        
        return min(max(percentage, 0), 100)
    }
    
    /// Couleur basée sur le pourcentage de réalisation
    /// Rouge (0%) -> Vert (100%) par paliers de 10%
    var progressColor: Color {
        let percentage = completionPercentage
        
        // Paliers de 10%
        switch percentage {
        case 0..<10:
            return Color(red: 220/255, green: 38/255, blue: 38/255) // Rouge vif
        case 10..<20:
            return Color(red: 239/255, green: 68/255, blue: 68/255) // Rouge
        case 20..<30:
            return Color(red: 249/255, green: 115/255, blue: 22/255) // Orange-rouge
        case 30..<40:
            return Color(red: 251/255, green: 146/255, blue: 60/255) // Orange
        case 40..<50:
            return Color(red: 251/255, green: 191/255, blue: 36/255) // Orange clair
        case 50..<60:
            return Color(red: 234/255, green: 179/255, blue: 8/255) // Jaune-orange
        case 60..<70:
            return Color(red: 202/255, green: 138/255, blue: 4/255) // Jaune foncé
        case 70..<80:
            return Color(red: 132/255, green: 204/255, blue: 22/255) // Jaune-vert
        case 80..<90:
            return Color(red: 101/255, green: 163/255, blue: 13/255) // Vert clair
        case 90..<100:
            return Color(red: 34/255, green: 197/255, blue: 94/255) // Vert
        default: // 100%
            return Color(red: 22/255, green: 163/255, blue: 74/255) // Vert foncé
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Travaux, rhs: Travaux) -> Bool {
        lhs.id == rhs.id
    }
}

enum TravauxAvancement: String, CaseIterable {
    case enCours = "Chantier en cours"
    case prevu = "Chantier prévu"
    case termine = "Chantier terminé"
    case inconnu = "Inconnu"
    
    var displayName: String {
        switch self {
        case .enCours: return "En cours"
        case .prevu: return "Prévu"
        case .termine: return "Terminé"
        case .inconnu: return "Inconnu"
        }
    }
    
    var icon: String {
        switch self {
        case .enCours: return "hammer.fill"
        case .prevu: return "calendar"
        case .termine: return "checkmark.circle.fill"
        case .inconnu: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .enCours: return "orange"
        case .prevu: return "blue"
        case .termine: return "green"
        case .inconnu: return "gray"
        }
    }
    
    init(from string: String?) {
        guard let string = string else {
            self = .inconnu
            return
        }
        self = TravauxAvancement(rawValue: string) ?? .inconnu
    }
}

enum TravauxImportance: Int, CaseIterable, Comparable {
    case tresPerturbant = 1
    case perturbant = 2
    case peuPerturbant = 3
    case inconnu = 0
    
    var displayName: String {
        switch self {
        case .tresPerturbant: return "Très perturbant"
        case .perturbant: return "Perturbant"
        case .peuPerturbant: return "Peu perturbant"
        case .inconnu: return "Non défini"
        }
    }
    
    var icon: String {
        switch self {
        case .tresPerturbant: return "exclamationmark.3"
        case .perturbant: return "exclamationmark.2"
        case .peuPerturbant: return "exclamationmark"
        case .inconnu: return "minus"
        }
    }
    
    var color: String {
        switch self {
        case .tresPerturbant: return "red"
        case .perturbant: return "orange"
        case .peuPerturbant: return "yellow"
        case .inconnu: return "gray"
        }
    }
    
    static func < (lhs: TravauxImportance, rhs: TravauxImportance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    init(from code: Int?) {
        guard let code = code else {
            self = .inconnu
            return
        }
        self = TravauxImportance(rawValue: code) ?? .inconnu
    }
}

enum TravauxPerturbation: String, CaseIterable {
    case circulationInterdite = "Circulation interdite"
    case circulationReduite = "Circulation réduite"
    case circulationAlternee = "Circulation alternée"
    case genePonctuelle = "Gêne ponctuelle"
    case autre = "Autre"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .circulationInterdite: return "xmark.circle.fill"
        case .circulationReduite: return "arrow.left.arrow.right"
        case .circulationAlternee: return "arrow.triangle.swap"
        case .genePonctuelle: return "exclamationmark.triangle"
        case .autre: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .circulationInterdite: return "red"
        case .circulationReduite: return "orange"
        case .circulationAlternee: return "yellow"
        case .genePonctuelle: return "blue"
        case .autre: return "gray"
        }
    }
    
    init(from string: String?) {
        guard let string = string else {
            self = .autre
            return
        }
        self = TravauxPerturbation(rawValue: string) ?? .autre
    }
}

// MARK: - API Response Models

struct TravauxResponse: Decodable {
    let type: String
    let features: [TravauxFeature]
    let numberMatched: Int?
    let numberReturned: Int?
}

struct TravauxFeature: Decodable {
    let type: String
    let id: String
    let geometry: TravauxGeometry
    let properties: TravauxProperties
}

struct TravauxGeometry: Decodable {
    let type: String
    let coordinates: [[[[Double]]]]
}

struct TravauxProperties: Decodable {
    // Champs du nouveau dataset "Travaux engagés"
    let numero: String?
    let intervenant: String?
    let nature_chantier: String?
    let nature_travaux: String?
    let etat: String?
    let date_debut: String?
    let date_fin: String?
    let mesures_police: String?
    let adresse: String?
    let commune: String?
    let code_insee: Int?
    let gid: Int
    
    // Anciens champs (pour compatibilité)
    let nom: String?
    let nomchantier: String?
    let commune1: String?
    let insee: String?
    let precisionlocalisation: String?
    let debutchantier: String?
    let finchantier: String?
    let descripchantierinternet: String?
    let avancement: String?
    let importance: String?
    let typeperturbation: String?
    let codeimportance: Int?
    
    enum CodingKeys: String, CodingKey {
        case numero, intervenant, nature_chantier, nature_travaux, etat
        case date_debut, date_fin, mesures_police, adresse, commune, code_insee, gid
        case nom, nomchantier, commune1, insee, precisionlocalisation
        case debutchantier, finchantier, descripchantierinternet
        case avancement, importance, typeperturbation, codeimportance
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Nouveaux champs
        numero = try container.decodeIfPresent(String.self, forKey: .numero)
        intervenant = try container.decodeIfPresent(String.self, forKey: .intervenant)
        nature_chantier = try container.decodeIfPresent(String.self, forKey: .nature_chantier)
        nature_travaux = try container.decodeIfPresent(String.self, forKey: .nature_travaux)
        etat = try container.decodeIfPresent(String.self, forKey: .etat)
        date_debut = try container.decodeIfPresent(String.self, forKey: .date_debut)
        date_fin = try container.decodeIfPresent(String.self, forKey: .date_fin)
        mesures_police = try container.decodeIfPresent(String.self, forKey: .mesures_police)
        adresse = try container.decodeIfPresent(String.self, forKey: .adresse)
        commune = try container.decodeIfPresent(String.self, forKey: .commune)
        code_insee = try container.decodeIfPresent(Int.self, forKey: .code_insee)
        gid = try container.decode(Int.self, forKey: .gid)
        
        // Anciens champs (optionnels)
        nom = try container.decodeIfPresent(String.self, forKey: .nom)
        nomchantier = try container.decodeIfPresent(String.self, forKey: .nomchantier)
        commune1 = try container.decodeIfPresent(String.self, forKey: .commune1)
        insee = try container.decodeIfPresent(String.self, forKey: .insee)
        precisionlocalisation = try container.decodeIfPresent(String.self, forKey: .precisionlocalisation)
        debutchantier = try container.decodeIfPresent(String.self, forKey: .debutchantier)
        finchantier = try container.decodeIfPresent(String.self, forKey: .finchantier)
        descripchantierinternet = try container.decodeIfPresent(String.self, forKey: .descripchantierinternet)
        avancement = try container.decodeIfPresent(String.self, forKey: .avancement)
        importance = try container.decodeIfPresent(String.self, forKey: .importance)
        typeperturbation = try container.decodeIfPresent(String.self, forKey: .typeperturbation)
        codeimportance = try container.decodeIfPresent(Int.self, forKey: .codeimportance)
    }
}

// MARK: - Clusterable Conformance

extension Travaux: Clusterable {
    var coordinate: CLLocationCoordinate2D {
        centroid
    }
    
    var clusterColor: Color {
        switch importance {
        case .tresPerturbant: return .red
        case .perturbant: return .orange
        case .peuPerturbant: return .yellow
        case .inconnu: return .gray
        }
    }
    
    var clusterIcon: String {
        type.icon
    }
}

extension Travaux {
    init(from feature: TravauxFeature) {
        self.id = feature.id
        
        // Utiliser les nouveaux champs en priorité, sinon les anciens
        self.nom = feature.properties.adresse ?? feature.properties.nom ?? "Rue inconnue"
        self.nomChantier = feature.properties.nature_chantier ?? feature.properties.nomchantier ?? "Travaux"
        self.commune = feature.properties.commune ?? feature.properties.commune1 ?? "Lyon"
        self.codeInsee = feature.properties.code_insee.map { String($0) } ?? feature.properties.insee ?? ""
        self.precisionLocalisation = feature.properties.nature_travaux ?? feature.properties.precisionlocalisation
        self.description = feature.properties.mesures_police ?? feature.properties.descripchantierinternet
        
        // État du nouveau dataset -> avancement
        let etat = feature.properties.etat?.lowercased() ?? ""
        if etat.contains("ouvert") || etat.contains("en cours") {
            self.avancement = .enCours
        } else if etat.contains("termin") {
            self.avancement = .termine
        } else {
            self.avancement = TravauxAvancement(from: feature.properties.avancement)
        }
        
        self.importance = TravauxImportance(from: feature.properties.codeimportance)
        self.typeperturbation = TravauxPerturbation(from: feature.properties.typeperturbation)
        self.intervenant = feature.properties.intervenant ?? "Non spécifié"
        self.type = TravauxType.detect(from: feature.properties.nature_chantier ?? feature.properties.nomchantier ?? "")
        self.natureChantier = TravauxNatureChantier.detect(from: feature.properties.nature_chantier)
        
        // Parse dates (nouveau format ou ancien)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let debutStr = feature.properties.date_debut ?? feature.properties.debutchantier
        if let dateStr = debutStr {
            self.debutChantier = dateFormatter.date(from: dateStr)
        } else {
            self.debutChantier = nil
        }
        
        let finStr = feature.properties.date_fin ?? feature.properties.finchantier
        if let dateStr = finStr {
            self.finChantier = dateFormatter.date(from: dateStr)
        } else {
            self.finChantier = nil
        }
        
        // Parse coordinates
        var allCoordinates: [[CLLocationCoordinate2D]] = []
        var allLats: [Double] = []
        var allLons: [Double] = []
        
        for polygon in feature.geometry.coordinates {
            for ring in polygon {
                var coords: [CLLocationCoordinate2D] = []
                for point in ring {
                    if point.count >= 2 {
                        let lon = point[0]
                        let lat = point[1]
                        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        allLats.append(lat)
                        allLons.append(lon)
                    }
                }
                if !coords.isEmpty {
                    allCoordinates.append(coords)
                }
            }
        }
        
        self.coordinates = allCoordinates
        
        // Calculate centroid
        if !allLats.isEmpty && !allLons.isEmpty {
            let avgLat = allLats.reduce(0, +) / Double(allLats.count)
            let avgLon = allLons.reduce(0, +) / Double(allLons.count)
            self.centroid = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        } else {
            self.centroid = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
        }
    }
}
