import Foundation
import CoreLocation
import MapKit

struct Stop: Identifiable, Hashable {
    let id: String
    let stopId: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct StopAnnotation: Identifiable, Hashable {
    let id: String
    let stop: Stop
    let passages: [Passage]
    
    var nextPassageTime: String? {
        passages.first?.formattedTime
    }
    
    var linesServed: [String] {
        Array(Set(passages.map { $0.ligne })).sorted()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: StopAnnotation, rhs: StopAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}
