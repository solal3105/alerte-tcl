import Foundation
import CoreLocation
import SwiftUI

// MARK: - Transit Stop Model

struct TransitStop: Identifiable, Hashable {
    let id: Int
    let nom: String
    let commune: String
    let adresse: String?
    let coordinate: CLLocationCoordinate2D
    let desserte: String // Lines serving this stop (e.g. "C20:A,C20E:A,JD975:R")
    let pmr: Bool
    var passages: [Passage] = []
    var isLoadingPassages: Bool = false
    var passagesLoaded: Bool = false
    
    /// Lignes pré-parsées (cached pour performance)
    private let _lines: [String]
    
    var lines: [String] { _lines }
    
    init(id: Int, nom: String, commune: String, adresse: String?, coordinate: CLLocationCoordinate2D, desserte: String, pmr: Bool) {
        self.id = id
        self.nom = nom
        self.commune = commune
        self.adresse = adresse
        self.coordinate = coordinate
        self.desserte = desserte
        self.pmr = pmr
        // Parse desserte une seule fois à l'init
        self._lines = desserte.split(separator: ",").compactMap { part in
            let linePart = part.split(separator: ":")
            return linePart.first.map { String($0) }
        }.unique()
    }
    
    var nextPassage: Passage? {
        passages.first
    }
    
    var hasPassages: Bool {
        !passages.isEmpty
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TransitStop, rhs: TransitStop) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Passage Model

struct Passage: Identifiable, Hashable, Codable {
    var id: String { "\(stopId)-\(ligne)-\(heurepassage)" }
    
    let stopId: Int
    let ligne: String
    let direction: String
    let delaipassage: String
    let heurepassage: String
    let type: String // T = Théorique, R = Temps réel
    
    var isRealTime: Bool {
        type == "R"
    }
    
    var lineColor: Color {
        TransportMode.detectFromLine(ligne).color
    }
    
    var formattedTime: String {
        // Parse heurepassage to get just the time
        let parts = heurepassage.split(separator: " ")
        if parts.count >= 2 {
            let timeParts = parts[1].split(separator: ":")
            if timeParts.count >= 2 {
                return "\(timeParts[0]):\(timeParts[1])"
            }
        }
        return heurepassage
    }
    
    enum CodingKeys: String, CodingKey {
        case stopId = "id"
        case ligne
        case direction
        case delaipassage
        case heurepassage
        case type
    }
}

// MARK: - API Response Models

struct TransitStopResponse: Codable {
    let type: String
    let features: [TransitStopFeature]
    let numberMatched: Int?
}

struct TransitStopFeature: Codable {
    let id: String
    let geometry: TransitStopGeometry
    let properties: TransitStopProperties
}

struct TransitStopGeometry: Codable {
    let type: String
    let coordinates: [Double]
    
    var coordinate: CLLocationCoordinate2D? {
        CLLocationCoordinate2D.fromGeoJSON(coordinates)
    }
}

struct TransitStopProperties: Codable {
    let id: Int
    let nom: String
    let desserte: String?
    let pmr: Bool?
    let adresse: String?
    let commune: String?
}

struct PassagesResponse: Codable {
    let fields: [String]
    let values: [PassageValue]
    let nb_results: Int?
}

struct PassageValue: Codable {
    let id: Int
    let ligne: String
    let direction: String
    let delaipassage: String
    let heurepassage: String
    let type: String
    
    func toPassage() -> Passage {
        Passage(
            stopId: id,
            ligne: ligne,
            direction: direction,
            delaipassage: delaipassage,
            heurepassage: heurepassage,
            type: type
        )
    }
}

// MARK: - Extensions

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension TransportMode {
    static func detectFromLine(_ ligne: String) -> TransportMode {
        let upper = ligne.uppercased()

        // Métro : lettres seules A/B/C/D (codes GeoServer) ou préfixe M (MA/MB…)
        if upper == "A" || upper == "B" || upper == "C" || upper == "D" { return .metro }
        if upper.hasPrefix("M") && upper.count <= 3 { return .metro }

        // Tramways : T + chiffre unique (T1…T9) ou TGS — exclut T36, TB11, etc.
        if upper == "TGS" { return .tramway }
        if upper.hasPrefix("T") && upper.count == 2 && (upper.last?.isNumber ?? false) { return .tramway }

        // Funiculaires : F1, F2
        if upper.hasPrefix("F") && upper.count <= 3 { return .funiculaire }

        // Chronobus : C suivi d'un chiffre (C1, C7, C15E, C200, C20E, etc.)
        // "C" seul = métro C, déjà traité ci-dessus
        if upper.hasPrefix("C"), let second = upper.dropFirst().first, second.isNumber { return .busC }

        // RhôneExpress
        if upper == "RX" || upper == "RHONEXPRESS" { return .tramway }

        return .bus
    }
}

// MARK: - Line Color Helper

struct LineColorHelper {
    /// Couleur de fond pour une ligne
    static func backgroundColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        // Metro - couleurs officielles TCL
        if upper == "MA" || upper == "A" {
            return Color(red: 238/255, green: 56/255, blue: 152/255) // Rose/fuchsia rgb(238, 56, 152)
        }
        else if upper == "MB" || upper == "B" {
            return Color(red: 0/255, green: 125/255, blue: 197/255) // Bleu rgb(0, 125, 197)
        }
        else if upper == "MC" || upper == "C" {
            return Color(red: 249/255, green: 157/255, blue: 29/255) // Orange rgb(249, 157, 29)
        }
        else if upper == "MD" || upper == "D" {
            return Color(red: 0/255, green: 172/255, blue: 77/255) // Vert rgb(0, 172, 77)
        }
        // Rhônexpress - fond C92B21
        else if upper == "RX" || upper.contains("RHONEXPRESS") {
            return Color(red: 201/255, green: 43/255, blue: 33/255) // C92B21
        }
        // Tramway - fond 673877
        else if upper.hasPrefix("T") && upper.count <= 3 {
            return Color(red: 103/255, green: 56/255, blue: 119/255) // 673877
        }
        // Trolleybus TB - jaune
        else if upper.hasPrefix("TB") {
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Jaune
        }
        // Funiculaire - orange
        else if upper.hasPrefix("F") && upper.count <= 3 {
            return .orange
        }
        // Bus C - gris (inchangé)
        else if upper.hasPrefix("C") && upper.count <= 4 {
            return Color(.systemGray)
        }
        // Bus JD - fond 2A2475
        else if upper.hasPrefix("JD") {
            return Color(red: 42/255, green: 36/255, blue: 117/255) // 2A2475
        }
        // Bus régulier (non-C, non-JD) - fond blanc
        return .white
    }
    
    /// Couleur du texte pour une ligne
    static func textColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        // Bus JD - texte EBCA2F sur fond 2A2475
        if upper.hasPrefix("JD") {
            return Color(red: 235/255, green: 202/255, blue: 47/255) // EBCA2F
        }
        // Bus C - texte blanc sur fond gris
        else if upper.hasPrefix("C") && upper.count <= 4 {
            return .white
        }
        // Trams - texte blanc sur fond 673877
        else if upper.hasPrefix("T") && upper.count <= 3 {
            return .white
        }
        // Bus classiques - couleurs spécifiques
        else if !upper.hasPrefix("M") && 
                !upper.hasPrefix("F") &&
                !upper.hasPrefix("TB") &&
                upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
                !upper.contains("RHONEXPRESS") && upper != "RX" {
            // Bus qui commencent par N - texte DC7921
            if upper.hasPrefix("N") {
                return Color(red: 220/255, green: 121/255, blue: 33/255) // DC7921
            }
            // Bus qui finissent par E - texte 5E3A18
            else if upper.hasSuffix("E") {
                return Color(red: 94/255, green: 58/255, blue: 24/255) // 5E3A18
            }
            // Autres bus classiques - texte rouge
            return .red
        }
        // Métro - texte blanc sur fond de couleur
        return .white
    }
    
    /// Style de bordure nécessaire (pour les fonds blancs)
    static func needsBorder(for ligne: String) -> Bool {
        let upper = ligne.uppercased()
        // Bordure uniquement pour les fonds blancs (bus classiques)
        return !upper.hasPrefix("M") && 
               !upper.hasPrefix("F") &&
               !upper.hasPrefix("C") &&
               !upper.hasPrefix("T") &&
               !upper.hasPrefix("TB") &&
               !upper.hasPrefix("JD") &&
               upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
               !upper.contains("RHONEXPRESS") && upper != "RX"
    }
}

// MARK: - Clusterable Conformance (for viewport filtering)

extension TransitStop: Clusterable {
    // coordinate is already defined in the struct
    
    var clusterColor: Color {
        if let firstPassage = nextPassage {
            return TransportMode.detectFromLine(firstPassage.ligne).color
        }
        return .gray
    }
    
    var clusterIcon: String {
        "bus.fill"
    }
}

// MARK: - Merged Stop (groups stops within 30m)

struct MergedStop: Identifiable, Hashable {
    let id: String
    let nom: String
    let coordinate: CLLocationCoordinate2D
    let stops: [TransitStop]
    let directions: [String] // Directions uniques des arrêts fusionnés
    
    /// Lignes pré-calculées (cached)
    let allLines: [String]
    
    /// PMR pré-calculé (cached)
    let pmr: Bool
    
    init(id: String, nom: String, coordinate: CLLocationCoordinate2D, stops: [TransitStop], directions: [String]) {
        self.id = id
        self.nom = nom
        self.coordinate = coordinate
        self.stops = stops
        self.directions = directions
        // Pré-calculer à l'init pour éviter recalculs
        self.allLines = stops.flatMap { $0.lines }.unique()
        self.pmr = stops.contains { $0.pmr }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MergedStop, rhs: MergedStop) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Stop Merging Engine

struct StopMergingEngine {
    /// Distance maximale en mètres pour fusionner des arrêts
    static let mergeDistanceMeters: Double = 30.0
    
    /// Seuil de distance au carré (évite sqrt coûteux)
    private static let mergeDistanceSquared: Double = mergeDistanceMeters * mergeDistanceMeters
    
    /// Taille de cellule de grille en degrés (~50m à Lyon)
    private static let gridCellSize: Double = 0.0005
    
    /// Conversion degrés → mètres approximative à Lyon (latitude ~45.76°)
    /// 1° latitude ≈ 111,320m, 1° longitude ≈ 78,710m à cette latitude
    private static let metersPerDegreeLat: Double = 111_320.0
    private static let metersPerDegreeLon: Double = 78_710.0
    
    /// Fusionne les arrêts qui sont à moins de 30m ET ont EXACTEMENT les mêmes lignes
    /// Optimisé O(n) avec spatial hashing + Haversine approximatif + Union-Find par rang
    static func mergeNearbyStops(_ stops: [TransitStop]) -> [MergedStop] {
        guard !stops.isEmpty else { return [] }
        
        // 1. Pré-calculer les Sets de lignes pour TOUS les arrêts (évite recalculs)
        let stopLinesSets: [Int: Set<String>] = Dictionary(
            uniqueKeysWithValues: stops.map { ($0.id, Set($0.lines)) }
        )
        
        // 2. Créer une grille spatiale pour O(1) lookup
        var grid: [GridKey: [TransitStop]] = [:]
        grid.reserveCapacity(stops.count / 2) // Pré-allouer
        
        for stop in stops {
            let key = GridKey(coordinate: stop.coordinate, cellSize: gridCellSize)
            grid[key, default: []].append(stop)
        }
        
        // 3. Union-Find avec compression de chemin ET union par rang
        var parent: [Int: Int] = [:]
        var rank: [Int: Int] = [:]
        parent.reserveCapacity(stops.count)
        rank.reserveCapacity(stops.count)
        
        @inline(__always)
        func find(_ id: Int) -> Int {
            if parent[id] == nil {
                parent[id] = id
                rank[id] = 0
            }
            // Compression de chemin itérative (plus rapide que récursif)
            var root = id
            while parent[root] != root {
                root = parent[root]!
            }
            // Compresser le chemin
            var current = id
            while parent[current] != root {
                let next = parent[current]!
                parent[current] = root
                current = next
            }
            return root
        }
        
        @inline(__always)
        func union(_ a: Int, _ b: Int) {
            let rootA = find(a)
            let rootB = find(b)
            guard rootA != rootB else { return }
            
            // Union par rang
            let rankA = rank[rootA] ?? 0
            let rankB = rank[rootB] ?? 0
            if rankA < rankB {
                parent[rootA] = rootB
            } else if rankA > rankB {
                parent[rootB] = rootA
            } else {
                parent[rootB] = rootA
                rank[rootA] = rankA + 1
            }
        }
        
        // 4. Pour chaque arrêt, vérifier seulement les cellules voisines (9 cellules max)
        for stop in stops {
            let baseKey = GridKey(coordinate: stop.coordinate, cellSize: gridCellSize)
            guard let baseLines = stopLinesSets[stop.id] else { continue }
            
            // Vérifier les 9 cellules voisines (incluant la cellule actuelle)
            for dx in -1...1 {
                for dy in -1...1 {
                    let neighborKey = GridKey(x: baseKey.x + dx, y: baseKey.y + dy)
                    guard let neighbors = grid[neighborKey] else { continue }
                    
                    for neighbor in neighbors {
                        guard stop.id < neighbor.id else { continue } // Évite comparaisons doubles
                        guard let neighborLines = stopLinesSets[neighbor.id] else { continue }
                        
                        // Vérifier d'abord les lignes (moins coûteux que distance)
                        guard baseLines == neighborLines else { continue }
                        
                        // Distance approximative rapide (sans CLLocation ni sqrt)
                        let distSq = distanceSquaredMeters(from: stop.coordinate, to: neighbor.coordinate)
                        if distSq <= mergeDistanceSquared {
                            union(stop.id, neighbor.id)
                        }
                    }
                }
            }
        }
        
        // 5. Grouper les arrêts par leur root parent
        var groups: [Int: [TransitStop]] = [:]
        groups.reserveCapacity(stops.count / 2)
        for stop in stops {
            let root = find(stop.id)
            groups[root, default: []].append(stop)
        }
        
        // 6. Créer les MergedStop en parallèle pour les gros groupes
        let groupsArray = Array(groups.values)
        
        return groupsArray.map { group in
            // Extraire directions avec Set pour dédupliquer automatiquement
            var directions: Set<String> = []
            directions.reserveCapacity(group.count * 2)
            for stop in group {
                for dir in extractDirections(from: stop.desserte) {
                    directions.insert(dir)
                }
            }
            
            // Calculer le centre avec une seule passe
            var sumLat = 0.0, sumLon = 0.0
            for stop in group {
                sumLat += stop.coordinate.latitude
                sumLon += stop.coordinate.longitude
            }
            let count = Double(group.count)
            
            return MergedStop(
                id: group.map { String($0.id) }.sorted().joined(separator: "-"),
                nom: group[0].nom,
                coordinate: CLLocationCoordinate2D(latitude: sumLat / count, longitude: sumLon / count),
                stops: group,
                directions: directions.sorted()
            )
        }
    }
    
    /// Extrait les directions depuis le champ desserte (ex: "C20:A,C20E:R" -> ["A", "R"])
    @inline(__always)
    private static func extractDirections(from desserte: String) -> [String] {
        desserte.split(separator: ",").compactMap { part in
            let components = part.split(separator: ":")
            return components.count >= 2 ? String(components[1]) : nil
        }
    }
    
    /// Distance au carré en mètres (approximation plate, parfait pour <100m)
    /// Évite: 1) Création de CLLocation, 2) Calcul sqrt, 3) Trigonométrie complexe
    @inline(__always)
    private static func distanceSquaredMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLat = (to.latitude - from.latitude) * metersPerDegreeLat
        let dLon = (to.longitude - from.longitude) * metersPerDegreeLon
        return dLat * dLat + dLon * dLon
    }
    
    /// Clé de grille pour spatial hashing
    private struct GridKey: Hashable {
        let x: Int
        let y: Int
        
        @inline(__always)
        init(coordinate: CLLocationCoordinate2D, cellSize: Double) {
            self.x = Int(coordinate.latitude / cellSize)
            self.y = Int(coordinate.longitude / cellSize)
        }
        
        @inline(__always)
        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }
}
