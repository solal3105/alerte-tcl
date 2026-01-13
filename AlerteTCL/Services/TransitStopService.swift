import Foundation
import CoreLocation
import MapKit

actor TransitStopService {
    static let shared = TransitStopService()
    
    private let stopsEndpoint = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/sytral:tcl_sytral.tclarret/items"
    private let passagesEndpoint = "https://download.data.grandlyon.com/ws/rdata/tcl_sytral.tclpassagearret/all.json"
    
    private var cachedStops: [Int: TransitStop] = [:]
    private var lastStopsFetch: Date?
    private let stopsCacheExpiration: TimeInterval = 86400 // 24h for static stop data
    
    private var username: String {
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonUsername") as? String ?? ""
    }
    
    private var password: String {
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonPassword") as? String ?? ""
    }
    
    private init() {}
    
    // MARK: - Fetch Stops
    
    func fetchStops(in region: MKCoordinateRegion? = nil) async throws -> [TransitStop] {
        // Check cache
        if let lastFetch = lastStopsFetch,
           Date().timeIntervalSince(lastFetch) < stopsCacheExpiration,
           !cachedStops.isEmpty {
            print("📍 TransitStopService: Utilisation du cache (\(cachedStops.count) arrêts)")
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
        
        print("🌐 TransitStopService: Chargement des arrêts...")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Add Basic Auth
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let stopsResponse = try decoder.decode(TransitStopResponse.self, from: data)
        
        var stops: [TransitStop] = []
        for feature in stopsResponse.features {
            let stop = TransitStop(
                id: feature.properties.id,
                nom: feature.properties.nom,
                commune: feature.properties.commune ?? "",
                adresse: feature.properties.adresse,
                coordinate: feature.geometry.coordinate,
                desserte: feature.properties.desserte ?? "",
                pmr: feature.properties.pmr ?? false
            )
            stops.append(stop)
            cachedStops[stop.id] = stop
        }
        
        lastStopsFetch = Date()
        print("✅ TransitStopService: \(stops.count) arrêts chargés")
        
        return stops
    }
    
    // MARK: - Fetch Passages
    
    func fetchPassages() async throws -> [Int: [Passage]] {
        guard let url = URL(string: passagesEndpoint) else {
            throw APIError.invalidURL
        }
        
        print("🚌 TransitStopService: Chargement des passages temps réel...")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        // Add Basic Auth
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let passagesResponse = try decoder.decode(PassagesResponse.self, from: data)
        
        // Group passages by stop ID
        var passagesByStop: [Int: [Passage]] = [:]
        for value in passagesResponse.values {
            let passage = value.toPassage()
            if passagesByStop[passage.stopId] == nil {
                passagesByStop[passage.stopId] = []
            }
            passagesByStop[passage.stopId]?.append(passage)
        }
        
        // Sort passages by time for each stop
        for (stopId, passages) in passagesByStop {
            passagesByStop[stopId] = passages.sorted { $0.heurepassage < $1.heurepassage }
        }
        
        print("✅ TransitStopService: Passages pour \(passagesByStop.count) arrêts")
        
        return passagesByStop
    }
    
    // MARK: - Fetch Stops with Passages
    
    func fetchStopsWithPassages(in region: MKCoordinateRegion? = nil) async throws -> [TransitStop] {
        // Fetch stops and passages in parallel
        async let stopsTask = fetchStops(in: region)
        async let passagesTask = fetchPassages()
        
        let (stops, passagesByStop) = try await (stopsTask, passagesTask)
        
        // Merge passages into stops
        var stopsWithPassages: [TransitStop] = []
        for var stop in stops {
            if let passages = passagesByStop[stop.id] {
                stop.passages = passages
            }
            stopsWithPassages.append(stop)
        }
        
        // Filter to only stops with passages
        let activeStops = stopsWithPassages.filter { $0.hasPassages }
        print("📊 TransitStopService: \(activeStops.count) arrêts actifs avec passages")
        
        return activeStops
    }
    
    // MARK: - Fetch Passages for Specific Stop
    
    func fetchPassagesForStop(stopId: Int) async throws -> [Passage] {
        let allPassages = try await fetchPassages()
        return allPassages[stopId] ?? []
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
