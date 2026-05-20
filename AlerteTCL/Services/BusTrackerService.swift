import Foundation

/// Récupère les informations de véhicule depuis l'API publique Bus Tracker.
/// Source externe non officielle — données manquantes ou erreurs silencieusement ignorées.
/// Référence : https://bus-tracker.fr
enum BusTrackerService {
    private static let baseURL = "https://bus-tracker.fr/api/vehicles"
    private static let networkId = 91 // TCL Lyon (id stable dans la DB Bus Tracker)

    private static var cache: [String: String] = [:]

    static func fetchVehicleModel(fleetNumber: String) async -> String? {
        if let cached = cache[fleetNumber] { return cached }
        guard let url = URL(string: "\(baseURL)?networkId=\(networkId)&number=\(fleetNumber)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let vehicles = try JSONDecoder().decode([BusTrackerVehicleDTO].self, from: data)
            guard let designation = vehicles.first(where: { $0.number == fleetNumber })?.designation else { return nil }
            cache[fleetNumber] = designation
            return designation
        } catch {
            return nil
        }
    }

    private struct BusTrackerVehicleDTO: Decodable {
        let number: String?
        let designation: String?
    }
}
