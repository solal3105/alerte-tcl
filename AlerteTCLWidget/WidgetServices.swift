//
//  WidgetServices.swift
//  AlerteTCLWidget
//
//  Services simplifiés pour les widgets
//

import Foundation
import SwiftUI

// MARK: - Passage Service for Widget

struct WidgetPassageService {
    private static let passagesEndpoint = "https://download.data.grandlyon.com/ws/rdata/tcl_sytral.tclpassagearret/all.json"
    
    private static var username: String {
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonUsername") as? String ?? ""
    }
    
    private static var password: String {
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonPassword") as? String ?? ""
    }
    
    static func fetchPassages(stopId: Int, line: String, direction: String) async throws -> [WidgetPassage] {
        let urlString = "\(passagesEndpoint)?field=id&value=\(stopId)&compact=false"
        
        guard let url = URL(string: urlString) else {
            throw WidgetError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        
        // Add Basic Auth
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WidgetError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WidgetError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let passagesResponse = try decoder.decode(WidgetPassagesResponse.self, from: data)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "fr_FR")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let now = Date()
        
        // Normaliser la ligne et direction pour la comparaison
        let normalizedLine = line.uppercased().trimmingCharacters(in: .whitespaces)
        let normalizedDirection = direction.lowercased().trimmingCharacters(in: .whitespaces)
        let directionPrefix = String(normalizedDirection.prefix(8))
        
        // Filtrer par ligne et direction, puis par passages futurs
        let filteredPassages = passagesResponse.values.filter { value in
            let valueLine = value.ligne.uppercased().trimmingCharacters(in: .whitespaces)
            let valueDirection = value.direction.lowercased().trimmingCharacters(in: .whitespaces)
            
            let matchesLine = valueLine == normalizedLine
            let matchesDirection = valueDirection.contains(directionPrefix) || normalizedDirection.contains(String(valueDirection.prefix(8)))
            
            if let passageDate = dateFormatter.date(from: value.heurepassage) {
                return matchesLine && matchesDirection && passageDate >= now
            }
            return matchesLine && matchesDirection
        }
        
        // Trier par heure et convertir
        let sortedPassages = filteredPassages.sorted { p1, p2 in
            let date1 = dateFormatter.date(from: p1.heurepassage) ?? Date.distantFuture
            let date2 = dateFormatter.date(from: p2.heurepassage) ?? Date.distantFuture
            return date1 < date2
        }
        
        return sortedPassages.prefix(6).map { value in
            let time: String
            if let passageDate = dateFormatter.date(from: value.heurepassage) {
                time = timeFormatter.string(from: passageDate)
            } else {
                time = "--:--"
            }
            
            return WidgetPassage(
                delay: value.delaipassage,
                time: time,
                isRealTime: value.type == "R"
            )
        }
    }
}

// MARK: - Widget Passages Response

struct WidgetPassagesResponse: Codable {
    let values: [WidgetPassageValue]
}

struct WidgetPassageValue: Codable {
    let id: Int
    let ligne: String
    let direction: String
    let delaipassage: String
    let heurepassage: String
    let type: String
}

// MARK: - Line Color Helper for Widget

struct WidgetLineColorHelper {
    static func backgroundColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        if upper == "MA" || upper == "A" {
            return Color(red: 238/255, green: 56/255, blue: 152/255)
        } else if upper == "MB" || upper == "B" {
            return Color(red: 0/255, green: 125/255, blue: 197/255)
        } else if upper == "MC" || upper == "C" {
            return Color(red: 249/255, green: 157/255, blue: 29/255)
        } else if upper == "MD" || upper == "D" {
            return Color(red: 0/255, green: 172/255, blue: 77/255)
        } else if upper == "RX" || upper.contains("RHONEXPRESS") {
            return Color(red: 201/255, green: 43/255, blue: 33/255)
        } else if upper.hasPrefix("T") && upper.count <= 3 {
            return Color(red: 103/255, green: 56/255, blue: 119/255)
        } else if upper.hasPrefix("TB") {
            return Color(red: 1.0, green: 0.8, blue: 0.0)
        } else if upper.hasPrefix("F") && upper.count <= 3 {
            return .orange
        } else if upper.hasPrefix("C") && upper.count <= 4 {
            return Color(.systemGray)
        } else if upper.hasPrefix("JD") {
            return Color(red: 42/255, green: 36/255, blue: 117/255)
        }
        return .blue
    }
    
    static func textColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        if upper.hasPrefix("JD") {
            return Color(red: 235/255, green: 202/255, blue: 47/255)
        } else if upper.hasPrefix("C") && upper.count <= 4 {
            return .white
        } else if upper.hasPrefix("T") && upper.count <= 3 {
            return .white
        } else if !upper.hasPrefix("M") &&
                  !upper.hasPrefix("F") &&
                  !upper.hasPrefix("TB") &&
                  upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
                  !upper.contains("RHONEXPRESS") && upper != "RX" {
            return .red
        }
        return .white
    }
}

// MARK: - Parking Service for Widget

struct WidgetParkingService {
    static func fetchParking(withId parkingId: String) async -> WidgetParking? {
        do {
            let parkings = try await fetchParkings()
            return parkings.first(where: { $0.id == parkingId })
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
    let nom: String
    let placesDisponibles: Int
    let capaciteTotale: Int
    
    init(from feature: WidgetParkingFeature) {
        self.id = feature.properties.id
        self.nom = feature.properties.nom
        self.placesDisponibles = feature.properties.placesDisponibles ?? 0
        self.capaciteTotale = feature.properties.nbPlaces ?? 0
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
    let nom: String
    let placesDisponibles: Int?
    let nbPlaces: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case nom
        case placesDisponibles = "places_disponibles"
        case nbPlaces = "nb_places"
    }
}

enum WidgetError: Error {
    case invalidURL
    case invalidResponse
}
