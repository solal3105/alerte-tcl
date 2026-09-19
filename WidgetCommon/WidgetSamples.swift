import CoreLocation
import Foundation

/// Données d'exemple des widgets : aperçus de la galerie de l'application, aperçus Xcode et
/// instantanés de la galerie de widgets d'iOS.
enum WidgetSamples {
    private static var now: Date { Date() }

    static let stop = WidgetStop(stopId: 290, stopName: "Bellecour", line: "C20", direction: "Francheville Taffignon")

    static var departures: DeparturesEntry {
        DeparturesEntry(
            date: now, status: .ready, stop: stop,
            departures: [
                WidgetDeparture(time: now.addingTimeInterval(4 * 60 + 20), realTime: true),
                WidgetDeparture(time: now.addingTimeInterval(12 * 60 + 5), realTime: true),
                WidgetDeparture(time: now.addingTimeInterval(25 * 60), realTime: false),
            ],
            fetchedAt: now, stale: false, theoretical: false
        )
    }

    static var board: BoardEntry {
        let stops = [
            stop,
            WidgetStop(stopId: 1022, stopName: "Charpennes", line: "B", direction: "Saint-Genis-Laval Hôpital Lyon Sud"),
            WidgetStop(stopId: 2334, stopName: "Gratte-Ciel", line: "C3", direction: "Gare Saint-Paul"),
            WidgetStop(stopId: 4110, stopName: "Part-Dieu Vivier Merle", line: "T1", direction: "Debourg"),
            WidgetStop(stopId: 512, stopName: "Hôtel de Ville Louis Pradel", line: "C13", direction: "Montessuy"),
            WidgetStop(stopId: 3011, stopName: "Croix-Rousse", line: "C", direction: "Cuire"),
        ]
        let delays: [[Double]] = [[4.3, 12], [2, 5.5], [7, 15], [1, 9], [11, 24], [3, 8]]
        return BoardEntry(
            date: now, status: .ready,
            rows: zip(stops, delays).map { stop, minutes in
                BoardRow(stop: stop, departures: minutes.map { WidgetDeparture(time: now.addingTimeInterval($0 * 60), realTime: true) }, failed: false)
            },
            fetchedAt: now
        )
    }

    static var parking: ParkingEntry {
        ParkingEntry(
            date: now, status: .ready,
            parking: WidgetParkingSnapshot(id: "parc-relais-GOR", name: "Gorge de Loup", available: 212, capacity: 510, isParcRelais: true, open: true),
            fetchedAt: now, stale: false
        )
    }

    static var velov: VelovEntry {
        VelovEntry(
            date: now, status: .ready,
            station: WidgetVelovSnapshot(id: 1002, name: "Opéra", address: "Place Louis Pradel", bikes: 7, ebikes: 3, stands: 12, capacity: 20, open: true, updated: now, distanceMeters: 180),
            nearest: true, needsLocation: false, fetchedAt: now, stale: false
        )
    }

    static var works: WorksEntry {
        WorksEntry(
            date: now, status: .ready,
            works: [
                WidgetWork(id: "1", title: "Aménagements cyclables", address: "Rue de la République", commune: "Lyon 2e", progress: 45, distanceMeters: 240),
                WidgetWork(id: "2", title: "Espace public", address: "Place des Jacobins", commune: "Lyon 2e", progress: 80, distanceMeters: 410),
                WidgetWork(id: "3", title: "Assainissement", address: "Quai Jules Courmont", commune: "Lyon 2e", progress: 15, distanceMeters: 620),
                WidgetWork(id: "4", title: "Transports en commun", address: "Cours de Verdun", commune: "Lyon 2e", progress: 60, distanceMeters: 880),
            ],
            radiusMeters: 1000, hasLocation: true, mapLight: nil, mapDark: nil, fetchedAt: now
        )
    }

    /// Contours d'exemple pour dessiner la carte de l'aperçu (autour de la place Bellecour).
    static let worksShapes: [WorksMapShape] = [
        WorksMapShape(rings: [rectangle(lat: 45.7620, lng: 4.8355, dLat: 0.0009, dLng: 0.0004)], centroid: CLLocationCoordinate2D(latitude: 45.7620, longitude: 4.8355), progress: 45, importance: 2),
        WorksMapShape(rings: [rectangle(lat: 45.7605, lng: 4.8317, dLat: 0.0004, dLng: 0.0007)], centroid: CLLocationCoordinate2D(latitude: 45.7605, longitude: 4.8317), progress: 80, importance: 3),
        WorksMapShape(rings: [rectangle(lat: 45.7565, lng: 4.8385, dLat: 0.0012, dLng: 0.0003)], centroid: CLLocationCoordinate2D(latitude: 45.7565, longitude: 4.8385), progress: 15, importance: 1),
        WorksMapShape(rings: [rectangle(lat: 45.7525, lng: 4.8300, dLat: 0.0003, dLng: 0.0010)], centroid: CLLocationCoordinate2D(latitude: 45.7525, longitude: 4.8300), progress: 60, importance: 2),
    ]

    private static func rectangle(lat: Double, lng: Double, dLat: Double, dLng: Double) -> [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: lat - dLat, longitude: lng - dLng),
            CLLocationCoordinate2D(latitude: lat - dLat, longitude: lng + dLng),
            CLLocationCoordinate2D(latitude: lat + dLat, longitude: lng + dLng),
            CLLocationCoordinate2D(latitude: lat + dLat, longitude: lng - dLng),
        ]
    }

    static var traffic: TrafficEntry {
        TrafficEntry(
            date: now, status: .ready,
            subscribed: ["B", "C3", "C20", "T1"],
            disrupted: [
                WidgetTrafficLine(line: "B", severity: .major, title: "Trafic interrompu entre Charpennes et Part-Dieu"),
                WidgetTrafficLine(line: "C3", severity: .disruption, title: "Déviation cours Lafayette, arrêts non desservis"),
            ],
            networkMajor: 1, fetchedAt: now, stale: false
        )
    }

    static var trafficCalm: TrafficEntry {
        TrafficEntry(date: now, status: .ready, subscribed: ["B", "C3", "C20", "T1"], disrupted: [], networkMajor: 0, fetchedAt: now, stale: false)
    }
}
