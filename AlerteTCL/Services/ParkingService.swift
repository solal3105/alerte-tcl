import Foundation
import MapKit

actor ParkingService {
    static let shared = ParkingService()
    
    private let baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections"
    
    // Cache simple par type (pour voitures - données temps réel)
    private var simpleCache: [ParkingType: (parkings: [Parking], timestamp: Date)] = [:]
    private let simpleCacheValidity: TimeInterval = 30
    
    // Cache spatial par tuiles (pour vélos/2-roues - données statiques)
    private let bikeTileCache = SpatialTileCache<Parking>(config: .staticData)
    private let motoTileCache = SpatialTileCache<Parking>(config: .staticData)
    
    // Limites de requête
    private let defaultLimit = 500
    private let maxLimit = 1000
    
    private init() {}
    
    // MARK: - Fetch All (legacy, pour voitures)
    
    func fetchParkings(type: ParkingType = .car, forceRefresh: Bool = false) async throws -> [Parking] {
        // Pour vélos/2-roues, utiliser le chargement spatial
        if type == .bike || type == .motorized2Wheel {
            AppLogger.debug("⚠️ ParkingService: fetchParkings() appelé pour \(type.rawValue) - utiliser fetchParkingsInRegion() pour de meilleures performances")
        }
        
        // Vérifier le cache simple
        if !forceRefresh, let cached = simpleCache[type] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < simpleCacheValidity {
                AppLogger.debug("✨ ParkingService: Cache hit pour \(type.rawValue) (âge: \(Int(age))s)")
                return cached.parkings
            }
        }
        
        let parkings = try await fetchFromAPI(type: type, bbox: nil, limit: nil)
        simpleCache[type] = (parkings: parkings, timestamp: Date())
        return parkings
    }
    
    // MARK: - Fetch In Region (optimisé avec BBox)
    
    /// Charge les parkings dans une région spécifique avec filtrage spatial côté serveur
    func fetchParkingsInRegion(type: ParkingType, region: MKCoordinateRegion, forceRefresh: Bool = false) async throws -> [Parking] {
        // Pour les voitures (peu nombreuses, temps réel), charger tout
        if type == .car {
            return try await fetchParkings(type: type, forceRefresh: forceRefresh)
        }
        
        // Pour vélos/2-roues, utiliser le cache spatial
        let tileCache = type == .bike ? bikeTileCache : motoTileCache
        
        // Nettoyer les tuiles expirées
        await tileCache.pruneExpired()
        
        // Récupérer les items en cache et identifier les tuiles manquantes
        let (cachedItems, missingTiles) = await tileCache.getItemsForRegion(region)
        
        if missingTiles.isEmpty {
            AppLogger.debug("✨ ParkingService: 100% cache hit pour \(type.rawValue) - \(cachedItems.count) items")
            let stats = await tileCache.stats
            AppLogger.debug("📊 \(stats)")
            return cachedItems
        }
        
        AppLogger.debug("🔄 ParkingService: \(missingTiles.count) tuiles à charger pour \(type.rawValue)")
        
        // Générer le bbox pour les tuiles manquantes
        let bbox = BBoxHelper.bboxString(for: missingTiles, tileSizeDegrees: 0.01)
        let limit = BBoxHelper.optimalLimit(for: region.span.latitudeDelta, baseLimit: defaultLimit)
        
        // Charger les données manquantes
        let newParkings = try await fetchFromAPI(type: type, bbox: bbox, limit: limit)
        
        // Répartir les parkings dans les tuiles correspondantes
        for tile in missingTiles {
            let tileMinLon = Double(tile.x) * 0.01
            let tileMaxLon = Double(tile.x + 1) * 0.01
            let tileMinLat = Double(tile.y) * 0.01
            let tileMaxLat = Double(tile.y + 1) * 0.01
            
            let tileItems = newParkings.filter { parking in
                parking.coordinate.longitude >= tileMinLon &&
                parking.coordinate.longitude < tileMaxLon &&
                parking.coordinate.latitude >= tileMinLat &&
                parking.coordinate.latitude < tileMaxLat
            }
            
            await tileCache.set(tile: tile, items: tileItems)
        }
        
        // Combiner cache + nouvelles données (dédupliqués)
        var seenIds: Set<String> = Set(cachedItems.map { $0.id })
        var allItems = cachedItems
        
        for parking in newParkings {
            if !seenIds.contains(parking.id) {
                seenIds.insert(parking.id)
                allItems.append(parking)
            }
        }
        
        AppLogger.debug("✅ ParkingService: \(allItems.count) parkings \(type.rawValue) (\(cachedItems.count) cached + \(newParkings.count) new)")
        let finalStats = await tileCache.stats
        AppLogger.debug("📊 \(finalStats)")
        
        return allItems
    }
    
    // MARK: - Private API Fetch
    
    private func fetchFromAPI(type: ParkingType, bbox: String?, limit: Int?) async throws -> [Parking] {
        let collectionName = collectionName(for: type)
        
        var urlString = "\(baseURL)/\(collectionName)/items?f=application/json"
        
        // Ajouter bbox si fourni
        if let bbox = bbox, !bbox.isEmpty {
            urlString += "&bbox=\(bbox)"
        }
        
        // Ajouter limit si fourni
        if let limit = limit {
            urlString += "&limit=\(limit)"
        }
        
        // Tri pour cohérence
        urlString += "&sortby=gid"
        
        guard let url = URL(string: urlString) else {
            AppLogger.debug("❌ ParkingService: URL invalide")
            throw ParkingServiceError.invalidURL
        }
        
        AppLogger.debug("🌐 ParkingService: \(type.rawValue) URL: \(url.absoluteString.prefix(120))...")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParkingServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            AppLogger.debug("❌ ParkingService: HTTP \(httpResponse.statusCode)")
            throw ParkingServiceError.httpError(httpResponse.statusCode)
        }
        
        // Log taille des données pour monitoring
        let dataSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .memory)
        AppLogger.debug("📦 ParkingService: \(dataSize) reçus")
        
        return try decodeParkings(from: data, type: type)
    }
    
    private func collectionName(for type: ParkingType) -> String {
        switch type {
        case .car:
            return "metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2"
        case .bike:
            return "metropole-de-lyon:pvo_patrimoine_voirie.pvostationnementvelo"
        case .motorized2Wheel:
            return "ville-de-lyon:vdl_deplacements.emplacement_moto"
        }
    }
    
    private func decodeParkings(from data: Data, type: ParkingType) throws -> [Parking] {
        let decoder = JSONDecoder()
        
        do {
            let parkingResponse = try decoder.decode(ParkingResponse.self, from: data)
            let parkings = parkingResponse.features.compactMap { Parking(from: $0, type: type) }
            AppLogger.debug("✅ ParkingService: \(parkings.count) parkings \(type.rawValue) décodés")
            return parkings
        } catch let decodingError as DecodingError {
            AppLogger.debug("❌ ParkingService: Erreur décodage: \(decodingError.localizedDescription)")
            throw ParkingServiceError.decodingError(decodingError)
        }
    }
    
    // MARK: - Cache Management
    
    /// Vide les caches (utile pour forcer un refresh complet)
    func clearCaches() async {
        simpleCache.removeAll()
        await bikeTileCache.clear()
        await motoTileCache.clear()
        AppLogger.debug("🧹 ParkingService: Tous les caches vidés")
    }
    
    /// Statistiques des caches
    func cacheStats() async -> String {
        let bikeStats = await bikeTileCache.stats
        let motoStats = await motoTileCache.stats
        return "Bike: \(bikeStats) | Moto: \(motoStats)"
    }
    
    func fetchParkingsRelais() async throws -> [Parking] {
        let allParkings = try await fetchParkings()
        return allParkings.filter { parking in
            parking.nom.lowercased().contains("p+r") ||
            parking.nom.lowercased().contains("parc relais") ||
            parking.nom.lowercased().contains("park relais") ||
            parking.gestionnaire.lowercased().contains("tcl") ||
            parking.gestionnaire.lowercased().contains("sytral")
        }
    }
}

enum ParkingServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .httpError(let code):
            return "Erreur HTTP: \(code)"
        case .decodingError(let error):
            return "Erreur de décodage: \(error.localizedDescription)"
        }
    }
}
