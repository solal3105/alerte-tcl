import Foundation

actor SIRILiteService {
    static let shared = SIRILiteService()
    
    private let baseURL = "https://data.grandlyon.com"
    private let vehicleMonitoringEndpoint = "/siri-lite/2.0/vehicle-monitoring.json"
    
    private var username: String {
        ProcessInfo.processInfo.environment["GRANDLYON_USERNAME"] ?? 
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonUsername") as? String ?? ""
    }
    
    private var password: String {
        ProcessInfo.processInfo.environment["GRANDLYON_PASSWORD"] ?? 
        Bundle.main.object(forInfoDictionaryKey: "GrandLyonPassword") as? String ?? ""
    }
    
    private init() {}
    
    func fetchVehiclePositions() async throws -> [Vehicle] {
        guard let url = URL(string: baseURL + vehicleMonitoringEndpoint) else {
            throw SIRIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SIRIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw SIRIError.unauthorized
        case 403:
            throw SIRIError.forbidden
        case 404:
            throw SIRIError.notFound
        case 500...599:
            throw SIRIError.serverError(httpResponse.statusCode)
        default:
            throw SIRIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let siriResponse = try JSONDecoder().decode(SIRIResponse.self, from: data)
            let vehicles = parseVehicleData(siriResponse)
            
            #if DEBUG
            print("📍 SIRI API: \(vehicles.count) véhicules reçus")
            if vehicles.isEmpty {
                print("⚠️ Aucun véhicule en circulation actuellement")
            }
            #endif
            
            return vehicles
        } catch {
            #if DEBUG
            print("❌ Erreur de décodage SIRI: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Données reçues: \(dataString.prefix(500))")
            }
            #endif
            throw SIRIError.decodingError(error)
        }
    }
    
    private func parseVehicleData(_ response: SIRIResponse) -> [Vehicle] {
        guard let vehicleActivities = response.Siri.ServiceDelivery.VehicleMonitoringDelivery?.first?.VehicleActivity else {
            return []
        }
        
        return vehicleActivities.compactMap { activity -> Vehicle? in
            guard let journey = activity.MonitoredVehicleJourney,
                  let location = journey.VehicleLocation,
                  let latitude = location.Latitude,
                  let longitude = location.Longitude else {
                return nil
            }
            
            let lineRef = journey.LineRef?.value ?? ""
            let lineName = extractLineName(from: lineRef)
            let vehicleType = detectVehicleType(lineRef: lineRef, vehicleRef: journey.VehicleRef?.value)
            let destination = extractDestination(from: journey.DestinationRef?.value)
            let delay = parseDelay(journey.Delay)
            
            // Extraire les informations d'arrêts
            let nextStop = parseMonitoredCall(journey.MonitoredCall)
            let onwardStops = parseOnwardCalls(journey.OnwardCalls)
            
            return Vehicle(
                id: activity.VehicleMonitoringRef?.value ?? UUID().uuidString,
                latitude: latitude,
                longitude: longitude,
                bearing: journey.Bearing ?? 0,
                lineRef: lineRef,
                lineName: lineName,
                vehicleType: vehicleType,
                destination: destination,
                delay: delay,
                status: journey.VehicleStatus,
                recordedAt: parseISO8601Date(activity.RecordedAtTime),
                validUntil: parseISO8601Date(activity.ValidUntilTime),
                nextStop: nextStop,
                onwardStops: onwardStops
            )
        }
    }
    
    private func parseMonitoredCall(_ monitoredCall: MonitoredCall?) -> StopInfo? {
        guard let call = monitoredCall,
              let stopRef = call.StopPointRef?.value else {
            return nil
        }
        
        return StopInfo(
            id: stopRef,
            stopRef: stopRef,
            stopName: extractStopName(from: stopRef),
            aimedArrivalTime: parseISO8601Date(call.AimedArrivalTime),
            aimedDepartureTime: parseISO8601Date(call.AimedDepartureTime),
            distanceFromStop: call.DistanceFromStop,
            order: call.Order
        )
    }
    
    private func parseOnwardCalls(_ onwardCalls: OnwardCalls?) -> [StopInfo] {
        guard let calls = onwardCalls?.OnwardCall else { return [] }
        
        return calls.compactMap { call -> StopInfo? in
            guard let stopRef = call.StopPointRef?.value else { return nil }
            
            return StopInfo(
                id: stopRef,
                stopRef: stopRef,
                stopName: extractStopName(from: stopRef),
                aimedArrivalTime: parseISO8601Date(call.AimedArrivalTime),
                aimedDepartureTime: parseISO8601Date(call.AimedDepartureTime),
                distanceFromStop: call.DistanceFromStop,
                order: call.Order
            )
        }
    }
    
    private func extractStopName(from stopRef: String) -> String? {
        // Pour l'instant, retourne l'ID. Plus tard, on peut mapper avec les données GTFS
        return stopRef.components(separatedBy: ":").last
    }
    
    private func extractLineName(from lineRef: String) -> String {
        guard !lineRef.isEmpty else { return "?" }
        
        if let match = lineRef.range(of: "::([^:]+):SYTRAL", options: .regularExpression) {
            let extracted = String(lineRef[match])
            let cleaned = extracted.replacingOccurrences(of: "::", with: "")
                .replacingOccurrences(of: ":SYTRAL", with: "")
            return cleaned
        }
        
        let components = lineRef.split(separator: ":")
        return components.last.map(String.init) ?? lineRef
    }
    
    private func detectVehicleType(lineRef: String, vehicleRef: String?) -> VehicleType {
        let lineName = extractLineName(from: lineRef).uppercased()
        
        if lineName.range(of: "^M[A-D]$", options: .regularExpression) != nil {
            return .metro
        }
        
        if lineName.range(of: "^T\\d+$", options: .regularExpression) != nil {
            return .tram
        }
        
        if lineName == "RHONEXPRESS" || lineName == "RX" {
            return .tram
        }
        
        if lineName.range(of: "^TB\\d+$", options: .regularExpression) != nil {
            return .trolley
        }
        
        if lineName.range(of: "^F\\d*$", options: .regularExpression) != nil {
            return .funicular
        }
        
        return .bus
    }
    
    private func extractDestination(from destinationRef: String?) -> String {
        guard let ref = destinationRef, !ref.isEmpty else { return "" }
        
        if let match = ref.range(of: "::([^:]+):", options: .regularExpression) {
            let extracted = String(ref[match])
            return extracted.replacingOccurrences(of: "::", with: "")
                .replacingOccurrences(of: ":", with: "")
        }
        
        return ref
    }
    
    private func parseDelay(_ delay: String?) -> Int {
        guard let delay = delay, !delay.isEmpty else { return 0 }
        
        let isNegative = delay.hasPrefix("-")
        let cleanDelay = delay.replacingOccurrences(of: "-", with: "")
        
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: cleanDelay, options: [], range: NSRange(cleanDelay.startIndex..., in: cleanDelay)) else {
            return 0
        }
        
        func extractGroup(_ index: Int) -> Int {
            guard let range = Range(match.range(at: index), in: cleanDelay) else { return 0 }
            return Int(cleanDelay[range]) ?? 0
        }
        
        let hours = extractGroup(1)
        let minutes = extractGroup(2)
        let seconds = extractGroup(3)
        
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        return isNegative ? -totalSeconds : totalSeconds
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

enum SIRIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
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
            return "Authentification requise - Configurez vos identifiants Grand Lyon"
        case .forbidden:
            return "Accès refusé - Vérifiez vos identifiants"
        case .notFound:
            return "Service non trouvé"
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
