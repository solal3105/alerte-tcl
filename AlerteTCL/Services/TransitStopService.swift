import Foundation
import CoreLocation
import MapKit

actor TransitStopService {
    static let shared = TransitStopService()
    
    private let stopsEndpoint = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/sytral:tcl_sytral.tclarret/items"
    private let passagesEndpoint = "https://download.data.grandlyon.com/ws/rdata/tcl_sytral.tclpassagearret/all.json"
    
    private var cachedStops: [Int: TransitStop] = [:]
    private var lastStopsFetch: Date?
    private let stopsCacheExpiration: TimeInterval = 300 // 5 minutes
    
    private var credentials: (username: String, password: String)? {
        SecretsManager.grandLyonCredentials
    }
    
    private init() {}
    
    // MARK: - Fetch Stops
    
    func fetchStops(in region: MKCoordinateRegion? = nil) async throws -> [TransitStop] {
        // Check cache
        if let lastFetch = lastStopsFetch,
           Date().timeIntervalSince(lastFetch) < stopsCacheExpiration,
           !cachedStops.isEmpty {
            AppLogger.debug("📍 TransitStopService: Utilisation du cache (\(cachedStops.count) arrêts)")
            return Array(cachedStops.values)
        }
        
        var urlString = "\(stopsEndpoint)?f=application/json&limit=10000"
        
        // Add bbox filter if region provided
        if let region = region {
            let minLon = region.center.longitude - region.span.longitudeDelta
            let maxLon = region.center.longitude + region.span.longitudeDelta
            let minLat = region.center.latitude - region.span.latitudeDelta
            let maxLat = region.center.latitude + region.span.latitudeDelta
            urlString += "&bbox=\(minLon),\(minLat),\(maxLon),\(maxLat)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        AppLogger.debug("🌐 TransitStopService: Chargement des arrêts...")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.heavyTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        AppLogger.debug("🚀 Arrêts: Début requête (timeout: \(NetworkConfiguration.heavyTimeout)s)")
        request.setBasicAuth(credentials)
        
        let (data, response) = try await NetworkConfiguration.heavy.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let stopsResponse = try decoder.decode(TransitStopResponse.self, from: data)
        
        var stops: [TransitStop] = []
        for feature in stopsResponse.features {
            guard let coordinate = feature.geometry.coordinate else { continue }
            let stop = TransitStop(
                id: feature.properties.id,
                nom: feature.properties.nom,
                commune: feature.properties.commune ?? "",
                adresse: feature.properties.adresse,
                coordinate: coordinate,
                desserte: feature.properties.desserte ?? "",
                pmr: feature.properties.pmr ?? false
            )
            stops.append(stop)
            cachedStops[stop.id] = stop
        }
        
        lastStopsFetch = Date()
        AppLogger.debug("✅ TransitStopService: \(stops.count) arrêts chargés")
        
        return stops
    }
    
    // MARK: - Fetch All Stops
    
    func fetchAllStops(in region: MKCoordinateRegion? = nil) async throws -> [TransitStop] {
        let stops = try await fetchStops(in: region)
        AppLogger.debug("📊 TransitStopService: \(stops.count) arrêts chargés")
        return stops
    }
    
    // MARK: - Fetch Passages for Specific Stop (Detail View)
    
    private static let passageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    func fetchPassagesForStop(stopId: Int) async throws -> [Passage] {
        AppLogger.debug("🚌 TransitStopService: Chargement passages pour arrêt \(stopId)...")
        
        // Utiliser le filtrage direct de l'API pour récupérer UNIQUEMENT les passages de cet arrêt
        // Cette approche est ultra-optimisée car l'API filtre côté serveur
        let urlString = "\(passagesEndpoint)?field=id&value=\(stopId)&compact=false&sortby=heurepassage&sortorder=asc"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.heavyTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setBasicAuth(credentials)
        
        let (data, response) = try await NetworkConfiguration.heavy.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let passagesResponse = try decoder.decode(PassagesResponse.self, from: data)
        
        // Filtrer uniquement les passages futurs
        let now = Date()
        let relevantValues = passagesResponse.values.filter { value in
            if let passageDate = Self.passageDateFormatter.date(from: value.heurepassage) {
                return passageDate >= now
            }
            return true
        }
        
        // Convertir et trier par heure de passage
        let passages = relevantValues.map { $0.toPassage() }.sorted { p1, p2 in
            let date1 = Self.passageDateFormatter.date(from: p1.heurepassage) ?? Date.distantFuture
            let date2 = Self.passageDateFormatter.date(from: p2.heurepassage) ?? Date.distantFuture
            return date1 < date2
        }
        
        // Compter les lignes uniques
        let uniqueLines = Set(passages.map { $0.ligne })
        AppLogger.debug("✅ TransitStopService: \(passages.count) passages chargés pour arrêt \(stopId) (\(uniqueLines.count) lignes: \(uniqueLines.sorted().joined(separator: ", ")))")
        
        return passages
    }
    
    // MARK: - Get Stop from Cache
    
    func getStop(id: Int) -> TransitStop? {
        cachedStops[id]
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        cachedStops.removeAll()
        lastStopsFetch = nil
    }
}
