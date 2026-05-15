import Foundation

actor SIRILiteService {
    static let shared = SIRILiteService()
    
    // MARK: - Cached parsers (hot path: ~1000 véhicules par cycle)
    // Allouer NSRegularExpression / ISO8601DateFormatter / JSONDecoder par itération
    // coûte des milliers d'allocations inutiles par fetch. On les cache en static let.
    
    private static let jsonDecoder: JSONDecoder = JSONDecoder()
    
    // Dictionnaire nom d'arrêt par ID numérique GTFS (chargé une fois depuis le bundle)
    private static let gtfsStopNames: [String: String] = {
        guard let url = Bundle.main.url(forResource: "tcl_stops", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        struct Stop: Decodable { let id: String; let name: String }
        guard let stops = try? JSONDecoder().decode([Stop].self, from: data) else { return [:] }
        return Dictionary(stops.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }()

    // Regex patterns (pré-compilés une fois)
    private static let lineNameRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "::([^:]+):SYTRAL", options: [])) ?? NSRegularExpression()
    private static let metroRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "^M[A-D]$", options: [])) ?? NSRegularExpression()
    private static let tramRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "^T\\d+$", options: [])) ?? NSRegularExpression()
    private static let trolleyRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "^TB\\d+$", options: [])) ?? NSRegularExpression()
    private static let funicularRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "^F\\d*$", options: [])) ?? NSRegularExpression()

    private static let delayRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?", options: [])) ?? NSRegularExpression()
    
    // ISO8601 formatters (2 variantes: avec et sans fractional seconds)
    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private let baseURL = NetworkConfiguration.proxyBaseURL
    private let vehicleMonitoringEndpoint = "/vehicles"
    
    private init() {}
    
    func fetchVehiclePositions() async throws -> [Vehicle] {
        guard let url = URL(string: baseURL + vehicleMonitoringEndpoint) else {
            throw SIRIError.invalidURL
        }
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.fastTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        AppLogger.debug("🚀 SIRI: Début requête (timeout: \(NetworkConfiguration.fastTimeout)s)")
        
        let (data, response) = try await NetworkConfiguration.fast.data(for: request)
        
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
            let siriResponse = try Self.jsonDecoder.decode(SIRIResponse.self, from: data)
            let vehicles = parseVehicleData(siriResponse)
            
            #if DEBUG
            AppLogger.debug("📍 SIRI API: \(vehicles.count) véhicules reçus")
            if vehicles.isEmpty {
                AppLogger.debug("⚠️ Aucun véhicule en circulation actuellement")
            }
            #endif
            
            return vehicles
        } catch {
            #if DEBUG
            AppLogger.debug("❌ Erreur de décodage SIRI: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                AppLogger.debug("Données reçues: \(dataString.prefix(500))")
            }
            #endif
            throw SIRIError.decodingError(error)
        }
    }
    
    private func parseVehicleData(_ response: SIRIResponse) -> [Vehicle] {
        guard let vehicleActivities = response.Siri.ServiceDelivery.VehicleMonitoringDelivery?.first?.VehicleActivity else {
            return []
        }

        if response.Siri.ServiceDelivery.MoreData == true {
            AppLogger.debug("⚠️ SIRI: MoreData=true — réponse tronquée malgré MaximumVehicles=2000. Augmenter la limite.")
        }
        
        return vehicleActivities.compactMap { activity -> Vehicle? in
            guard let journey = activity.MonitoredVehicleJourney,
                  let location = journey.VehicleLocation,
                  let latitude = location.Latitude,
                  let longitude = location.Longitude else {
                return nil
            }
            
            // VehicleRef est l'identifiant physique du véhicule (numéro de bus/tram),
            // stable entre les trips. VehicleMonitoringRef est un identifiant de journey
            // qui change au terminus → source du clignotement. On préfère VehicleRef.
            // Certains véhicules (trams, métros) peuvent ne pas avoir de VehicleMonitoringRef.
            let vehRef = journey.VehicleRef?.value
            let monRef = activity.VehicleMonitoringRef?.value
            guard let stableId = (vehRef?.isEmpty == false ? vehRef : monRef), !stableId.isEmpty else {
                return nil
            }
            
            let lineRef = journey.LineRef?.value ?? ""
            let lineName = extractLineName(from: lineRef)
            let vehicleType = detectVehicleType(lineRef: lineRef, vehicleRef: vehRef)
            let destination = extractDestination(from: journey.DestinationRef?.value)
            let delay = parseDelay(journey.Delay)
            
            // Extraire les informations d'arrêts
            let nextStop = parseMonitoredCall(journey.MonitoredCall)
            
            return Vehicle(
                id: stableId,
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
                nextStop: nextStop
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
    
    private func extractStopName(from stopRef: String) -> String {
        // Format: "ActIV:StopArea:SP:39975:SYTRAL" → ID numérique à l'index 3
        let parts = stopRef.components(separatedBy: ":")
        guard parts.count >= 4 else { return parts.last ?? stopRef }
        let numericId = parts[3]
        return Self.gtfsStopNames[numericId] ?? numericId
    }
    
    private func extractLineName(from lineRef: String) -> String {
        guard !lineRef.isEmpty else { return "?" }
        
        let nsRef = lineRef as NSString
        let fullRange = NSRange(location: 0, length: nsRef.length)
        if let match = Self.lineNameRegex.firstMatch(in: lineRef, options: [], range: fullRange) {
            let extracted = nsRef.substring(with: match.range)
            let cleaned = extracted.replacingOccurrences(of: "::", with: "")
                .replacingOccurrences(of: ":SYTRAL", with: "")
            return cleaned
        }
        
        let components = lineRef.split(separator: ":")
        return components.last.map(String.init) ?? lineRef
    }
    
    @inline(__always)
    private static func regexMatches(_ regex: NSRegularExpression, _ s: String) -> Bool {
        let ns = s as NSString
        return regex.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)) != nil
    }
    
    private func detectVehicleType(lineRef: String, vehicleRef: String?) -> VehicleType {
        let lineName = extractLineName(from: lineRef).uppercased()
        
        if Self.regexMatches(Self.metroRegex, lineName) { return .metro }
        if Self.regexMatches(Self.tramRegex, lineName) { return .tram }
        if lineName == "RHONEXPRESS" || lineName == "RX" { return .tram }
        if Self.regexMatches(Self.trolleyRegex, lineName) { return .trolley }
        if Self.regexMatches(Self.funicularRegex, lineName) { return .funicular }
        
        return .bus
    }
    
    private func extractDestination(from destinationRef: String?) -> String {
        guard let ref = destinationRef, !ref.isEmpty else { return "" }
        // Format DestinationRef : "ActIV:StopArea:SP:39975:SYTRAL" — identique aux StopPointRef
        let parts = ref.components(separatedBy: ":")
        guard parts.count >= 4 else { return "" }
        let numericId = parts[3]
        return Self.gtfsStopNames[numericId] ?? ""
    }
    
    private func parseDelay(_ delay: String?) -> Int {
        guard let delay = delay, !delay.isEmpty else { return 0 }
        
        let isNegative = delay.hasPrefix("-")
        let cleanDelay = isNegative ? String(delay.dropFirst()) : delay
        let nsClean = cleanDelay as NSString
        
        guard let match = Self.delayRegex.firstMatch(in: cleanDelay, options: [], range: NSRange(location: 0, length: nsClean.length)) else {
            return 0
        }
        
        @inline(__always)
        func extractGroup(_ index: Int) -> Int {
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return 0 }
            return Int(nsClean.substring(with: range)) ?? 0
        }
        
        let hours = extractGroup(1)
        let minutes = extractGroup(2)
        let seconds = extractGroup(3)
        
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        return isNegative ? -totalSeconds : totalSeconds
    }
    
    private func parseISO8601Date(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        if let date = Self.iso8601FractionalFormatter.date(from: dateString) {
            return date
        }
        return Self.iso8601Formatter.date(from: dateString)
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
        }
    }
}
