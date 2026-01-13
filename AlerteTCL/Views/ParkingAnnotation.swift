import SwiftUI
import MapKit

class ParkingAnnotation: NSObject, MKAnnotation {
    let id: String
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let parking: Parking
    
    init(parking: Parking) {
        self.id = parking.id
        self.title = parking.nom
        self.coordinate = parking.coordinate
        self.parking = parking
        super.init()
    }
    
    // Clustering support
    static let clusteringIdentifier = "parking"
}

class ParkingClusterAnnotation: NSObject, MKAnnotation {
    let id: String
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let parkings: [Parking]
    
    init(parkings: [Parking]) {
        self.id = "cluster_\(parkings.map { $0.id }.joined(separator: "_"))"
        self.title = "\(parkings.count) parkings"
        self.parkings = parkings
        
        // Calculate center coordinate
        let totalLat = parkings.reduce(0.0) { $0 + $1.coordinate.latitude }
        let totalLon = parkings.reduce(0.0) { $0 + $1.coordinate.longitude }
        self.coordinate = CLLocationCoordinate2D(
            latitude: totalLat / Double(parkings.count),
            longitude: totalLon / Double(parkings.count)
        )
        super.init()
    }
}
