import Foundation
import CoreLocation
import MapKit

actor GTFSStopsService {
    static let shared = GTFSStopsService()
    
    private var allStops: [GTFSStop] = []
    private var isLoaded = false
    
    private init() {}
    
    func loadStops() async throws {
        guard !isLoaded else { return }
        
        guard let url = Bundle.main.url(forResource: "tcl_stops", withExtension: "json") else {
            throw GTFSError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        let stops = try JSONDecoder().decode([GTFSStop].self, from: data)
        
        allStops = stops
        isLoaded = true
        
        AppLogger.debug("✅ GTFS: \(allStops.count) arrêts chargés")
    }
    
    func getStopsInRegion(_ region: MKCoordinateRegion) async throws -> [GTFSStop] {
        if !isLoaded {
            try await loadStops()
        }
        
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        return allStops.filter { stop in
            stop.lat >= minLat &&
            stop.lat <= maxLat &&
            stop.lon >= minLon &&
            stop.lon <= maxLon
        }
    }
}

struct GTFSStop: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

enum GTFSError: LocalizedError {
    case fileNotFound
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "Fichier GTFS non trouvé"
        case .decodingError: return "Erreur de décodage GTFS"
        }
    }
}
