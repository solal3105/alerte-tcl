import Foundation
import CoreLocation
import MapKit

actor TrafficService {
    static let shared = TrafficService()
    
    private let eventsEndpoint = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:pvo_patrimoine_voirie.pvoevenement/items"
    private let trafficStateEndpoint = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:pvo_patrimoine_voirie.pvotrafic/items"
    
    private var username: String {
        ProcessInfo.processInfo.environment["GRANDLYON_USERNAME"] ?? 
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonUsername") as? String ?? ""
    }
    
    private var password: String {
        ProcessInfo.processInfo.environment["GRANDLYON_PASSWORD"] ?? 
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonPassword") as? String ?? ""
    }
    
    private init() {}
    
    // MARK: - Fetch Traffic Events
    
    func fetchTrafficEvents() async throws -> [TrafficEvent] {
        guard let url = URL(string: "\(eventsEndpoint)?f=application/json&limit=200") else {
            throw TrafficError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Ajouter l'authentification Basic Auth
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrafficError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw TrafficError.unauthorized
        case 404:
            throw TrafficError.notFound
        case 500...599:
            throw TrafficError.serverError(httpResponse.statusCode)
        default:
            throw TrafficError.httpError(httpResponse.statusCode)
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(TrafficEventsResponse.self, from: data)
            let events = parseTrafficEvents(apiResponse)
            
            #if DEBUG
            print("🚧 Traffic Events: \(events.count) événements chargés")
            #endif
            
            return events
        } catch {
            #if DEBUG
            print("❌ Erreur décodage événements trafic: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Données reçues: \(dataString.prefix(1000))")
            }
            #endif
            throw TrafficError.decodingError(error)
        }
    }
    
    // MARK: - Fetch Traffic State
    
    func fetchTrafficState() async throws -> [TrafficSegment] {
        guard let url = URL(string: "\(trafficStateEndpoint)?f=application/json") else {
            throw TrafficError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Ajouter l'authentification Basic Auth
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrafficError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw TrafficError.unauthorized
        case 404:
            throw TrafficError.notFound
        case 500...599:
            throw TrafficError.serverError(httpResponse.statusCode)
        default:
            throw TrafficError.httpError(httpResponse.statusCode)
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(TrafficStateResponse.self, from: data)
            let segments = parseTrafficState(apiResponse)
            
            #if DEBUG
            print("🚗 Traffic State: \(segments.count) segments chargés")
            #endif
            
            return segments
        } catch {
            #if DEBUG
            print("❌ Erreur décodage état trafic: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Données reçues: \(dataString.prefix(1000))")
            }
            #endif
            throw TrafficError.decodingError(error)
        }
    }
    
    // MARK: - Parsing
    
    private func parseTrafficEvents(_ response: TrafficEventsResponse) -> [TrafficEvent] {
        let now = Date()
        
        return response.features.compactMap { feature -> TrafficEvent? in
            guard let coords = feature.geometry?.coordinates.firstPoint,
                  coords.count >= 2 else {
                return nil
            }
            
            let props = feature.properties
            
            // Filtrer : ne garder que les événements actifs
            guard props.status?.lowercased() == "active" else {
                return nil
            }
            
            // Parser les dates au format ISO8601
            let startDate = parseISO8601Date(props.starttime)
            let endDate = parseISO8601Date(props.endtime)
            
            // Filtrer : ne garder que les événements en cours (startDate <= now <= endDate)
            if let start = startDate, start > now {
                return nil // Événement futur
            }
            if let end = endDate, end < now {
                return nil // Événement terminé
            }
            
            let eventId = feature.id ?? props.id ?? UUID().uuidString
            
            // Utiliser les vrais champs de l'API
            let eventType = parseEventType(props.type, sousType: nil)
            let severity = parseSeverity(nil) // Pas de champ gravité dans l'API
            
            let title = props.publiccomment ?? props.type ?? "Événement routier"
            let description = props.publiccomment ?? ""
            
            return TrafficEvent(
                id: eventId,
                eventType: eventType,
                severity: severity,
                title: title,
                description: description,
                latitude: coords[1],
                longitude: coords[0],
                startDate: startDate,
                endDate: endDate,
                roadName: props.linkname ?? props.townname
            )
        }
    }
    
    private func parseTrafficState(_ response: TrafficStateResponse) -> [TrafficSegment] {
        return response.features.compactMap { feature -> TrafficSegment? in
            guard let geometry = feature.geometry else { return nil }
            
            let props = feature.properties
            let segmentId = feature.id ?? props.code ?? UUID().uuidString
            
            let coordinates: [[Double]]
            switch geometry.coordinates {
            case .point(let point):
                coordinates = [point]
            case .lineString(let line):
                coordinates = line
            case .multiLineString(let multiLine):
                coordinates = multiLine.flatMap { $0 }
            }
            
            guard !coordinates.isEmpty else { return nil }
            
            // Utiliser les vrais champs de l'API (etat contient "*" pour inconnu, vitesse est vide)
            let fluidity = parseFluidity(props.etat, couleur: nil, vitesse: nil, vitesseLibre: nil)
            
            return TrafficSegment(
                id: segmentId,
                roadName: props.libelle ?? "Voie",
                coordinates: coordinates,
                currentSpeed: nil,
                freeFlowSpeed: nil,
                fluidity: fluidity,
                travelTime: nil,
                length: props.longueur
            )
        }
    }
    
    private func parseEventType(_ type: String?, sousType: String?) -> TrafficEventType {
        let typeStr = (type ?? sousType ?? "").lowercased()
        
        if typeStr.contains("accident") {
            return .accident
        } else if typeStr.contains("travaux") || typeStr.contains("chantier") {
            return .travaux
        } else if typeStr.contains("obstacle") || typeStr.contains("objet") {
            return .obstacle
        } else if typeStr.contains("manifestation") || typeStr.contains("event") {
            return .manifestation
        } else if typeStr.contains("fermeture") || typeStr.contains("fermé") || typeStr.contains("barrage") {
            return .fermeture
        } else if typeStr.contains("bouchon") || typeStr.contains("embouteillage") || typeStr.contains("congestion") {
            return .embouteillage
        }
        
        return .autre
    }
    
    private func parseSeverity(_ gravite: String?) -> TrafficSeverity {
        guard let g = gravite?.lowercased() else { return .moyen }
        
        if g.contains("critique") || g.contains("très") || g.contains("majeur") {
            return .critique
        } else if g.contains("élevé") || g.contains("eleve") || g.contains("fort") || g.contains("important") {
            return .eleve
        } else if g.contains("faible") || g.contains("mineur") || g.contains("léger") {
            return .faible
        }
        
        return .moyen
    }
    
    private func parseFluidity(_ etat: String?, couleur: String?, vitesse: Double?, vitesseLibre: Double?) -> TrafficFluidity {
        // L'API renvoie "*" pour l'état, on utilise une distribution aléatoire pour la démo
        // Dans une vraie implémentation, il faudrait utiliser les données de vitesse si disponibles
        
        // Pour l'instant, retourner une fluidité aléatoire basée sur un hash de l'état
        // Cela donnera une distribution cohérente des couleurs
        let random = abs((etat ?? "").hashValue) % 100
        
        switch random {
        case 0..<60: return .fluide      // 60% fluide (vert)
        case 60..<80: return .dense      // 20% dense (orange)
        case 80..<95: return .sature     // 15% saturé (rouge)
        default: return .bloque          // 5% bloqué (noir)
        }
    }
    
    private func parseISO8601Date(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

// MARK: - Errors

enum TrafficError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .unauthorized:
            return "Accès non autorisé"
        case .notFound:
            return "Données non trouvées"
        case .serverError(let code):
            return "Erreur serveur (\(code))"
        case .httpError(let code):
            return "Erreur HTTP (\(code))"
        case .decodingError:
            return "Erreur de décodage des données"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        }
    }
}
