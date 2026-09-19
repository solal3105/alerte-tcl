import CoreLocation
import Foundation

/// Chantiers de la Métropole (« Travaux engagés », GeoServer) autour d'un point : la requête ne
/// demande que l'emprise utile, avec les contours pour la carte du widget.
enum WorksService {
    struct Work {
        let item: WidgetWork
        let shape: WorksMapShape
    }

    private static let collection = "metropole-de-lyon:lyv_lyvia.lyvchantier"
    private static let pageLimit = 80

    private struct Response: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let id: String
        let geometry: Geometry
        let properties: Properties
    }

    /// Anneaux normalisés, quel que soit le type GeoJSON (même lecture que l'application).
    private struct Geometry: Decodable {
        let rings: [[CLLocationCoordinate2D]]

        enum CodingKeys: String, CodingKey {
            case type, coordinates
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "MultiPolygon":
                let coords = try container.decode([[[[Double]]]].self, forKey: .coordinates)
                rings = coords.flatMap { polygon in polygon.map { ring in ring.compactMap(Self.coordinate) } }
            case "Polygon", "MultiLineString":
                let coords = try container.decode([[[Double]]].self, forKey: .coordinates)
                rings = coords.map { ring in ring.compactMap(Self.coordinate) }
            case "LineString":
                let coords = try container.decode([[Double]].self, forKey: .coordinates)
                rings = [coords.compactMap(Self.coordinate)]
            default:
                rings = []
            }
        }

        private static func coordinate(_ pair: [Double]) -> CLLocationCoordinate2D? {
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }

    private struct Properties: Decodable {
        let natureChantier: String?
        let adresse: String?
        let commune: String?
        let dateDebut: String?
        let dateFin: String?
        let etat: String?
        let codeImportance: Int?

        enum CodingKeys: String, CodingKey {
            case adresse, commune, etat
            case natureChantier = "nature_chantier"
            case dateDebut = "date_debut"
            case dateFin = "date_fin"
            case codeImportance = "codeimportance"
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f
    }()

    /// Chantiers en cours à moins de `radiusMeters` du centre, du plus proche au plus lointain.
    static func nearby(center: CLLocationCoordinate2D, radiusMeters: Double, now: Date = Date()) async throws -> [Work] {
        let dLat = radiusMeters / 111_320
        let dLng = radiusMeters / (111_320 * cos(center.latitude * .pi / 180))
        let bbox = [center.longitude - dLng, center.latitude - dLat, center.longitude + dLng, center.latitude + dLat]
            .map { String(format: "%.5f", $0) }.joined(separator: ",")
        let url = "\(WidgetNetwork.geoServerBase)/\(collection)/items?f=application/json&limit=\(pageLimit)&sortby=gid&bbox=\(bbox)"
        let response = try await WidgetNetwork.json(Response.self, from: url)
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return response.features.compactMap { feature -> Work? in
            let end = feature.properties.dateFin.flatMap(dayFormatter.date)
            if let end, end.addingTimeInterval(86_400) < now { return nil }
            let rings = feature.geometry.rings.filter { !$0.isEmpty }
            let points = rings.flatMap { $0 }
            guard !points.isEmpty else { return nil }
            let centroid = CLLocationCoordinate2D(
                latitude: points.map(\.latitude).reduce(0, +) / Double(points.count),
                longitude: points.map(\.longitude).reduce(0, +) / Double(points.count)
            )
            let distance = origin.distance(from: CLLocation(latitude: centroid.latitude, longitude: centroid.longitude))
            guard distance <= radiusMeters else { return nil }
            let start = feature.properties.dateDebut.flatMap(dayFormatter.date)
            let progress = progress(start: start, end: end, state: feature.properties.etat, now: now)
            let importance = feature.properties.codeImportance ?? 0
            let item = WidgetWork(
                id: feature.id,
                title: feature.properties.natureChantier ?? "Travaux",
                address: feature.properties.adresse ?? "Rue inconnue",
                commune: feature.properties.commune ?? "",
                progress: progress,
                distanceMeters: distance
            )
            return Work(item: item, shape: WorksMapShape(rings: rings, centroid: centroid, progress: progress, importance: importance))
        }
        .sorted { $0.item.distanceMeters < $1.item.distanceMeters }
    }

    /// Avancement de 0 à 100 d'après les dates, sinon d'après l'état (même règle que l'application).
    private static func progress(start: Date?, end: Date?, state: String?, now: Date) -> Double {
        guard let start, let end else {
            let etat = (state ?? "").lowercased()
            if etat.contains("termin") { return 100 }
            if etat.contains("ouvert") || etat.contains("en cours") { return 50 }
            return 0
        }
        if now < start { return 0 }
        if now >= end { return 100 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(100, max(0, now.timeIntervalSince(start) / total * 100))
    }
}
