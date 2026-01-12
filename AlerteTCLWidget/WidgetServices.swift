//
//  WidgetServices.swift
//  AlerteTCLWidget
//
//  Services simplifiés pour les widgets
//

import Foundation

// MARK: - Parking Service for Widget

struct WidgetParkingService {
    static func fetchParking(withId parkingId: String) async -> Int? {
        do {
            let parkings = try await fetchParkings()
            return parkings.first(where: { $0.id == parkingId })?.placesDisponibles
        } catch {
            print("❌ Widget: Erreur récupération parking: \(error)")
            return nil
        }
    }
    
    private static func fetchParkings() async throws -> [WidgetParking] {
        let urlString = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2/items?f=application/json&sortby=gid"
        
        guard let url = URL(string: urlString) else {
            throw WidgetError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(WidgetParkingResponse.self, from: data)
        
        return response.features.map { WidgetParking(from: $0) }
    }
}

// MARK: - Widget Models

struct WidgetParking {
    let id: String
    let placesDisponibles: Int
    
    init(from feature: WidgetParkingFeature) {
        self.id = feature.properties.id
        self.placesDisponibles = feature.properties.placesDisponibles ?? 0
    }
}

struct WidgetParkingResponse: Codable {
    let features: [WidgetParkingFeature]
}

struct WidgetParkingFeature: Codable {
    let properties: WidgetParkingProperties
}

struct WidgetParkingProperties: Codable {
    let id: String
    let placesDisponibles: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case placesDisponibles = "places_disponibles"
    }
}

enum WidgetError: Error {
    case invalidURL
    case invalidResponse
}
