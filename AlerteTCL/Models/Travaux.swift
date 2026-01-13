import Foundation
import CoreLocation

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
        
        if nom.contains("tramway") || nom.contains("t10") || nom.contains("t1") || nom.contains("t2") || nom.contains("t3") || nom.contains("t4") || nom.contains("t5") || nom.contains("t6") || nom.contains("t7") {
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
        } else if nom.contains("voirie") || nom.contains("chaussée") || nom.contains("chaussee") || nom.contains("revêtement") || nom.contains("revetement") {
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
    let totalFeatures: Int
    let numberMatched: Int
    let numberReturned: Int
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
    let intervenant: String?
    let codeimportance: Int?
    let gid: Int
}

extension Travaux {
    init(from feature: TravauxFeature) {
        self.id = feature.id
        self.nom = feature.properties.nom ?? "Rue inconnue"
        self.nomChantier = feature.properties.nomchantier ?? "Travaux"
        self.commune = feature.properties.commune1 ?? "Lyon"
        self.codeInsee = feature.properties.insee ?? ""
        self.precisionLocalisation = feature.properties.precisionlocalisation
        self.description = feature.properties.descripchantierinternet
        self.avancement = TravauxAvancement(from: feature.properties.avancement)
        self.importance = TravauxImportance(from: feature.properties.codeimportance)
        self.typeperturbation = TravauxPerturbation(from: feature.properties.typeperturbation)
        self.intervenant = feature.properties.intervenant ?? "Non spécifié"
        self.type = TravauxType.detect(from: feature.properties.nomchantier ?? "")
        
        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let dateStr = feature.properties.debutchantier {
            self.debutChantier = dateFormatter.date(from: dateStr)
        } else {
            self.debutChantier = nil
        }
        
        if let dateStr = feature.properties.finchantier {
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
