import SwiftUI
import MapKit

struct ParkingAnnotationView: View {
    let annotation: MKAnnotation
    let onTap: () -> Void
    
    var body: some View {
        if let parkingAnnotation = annotation as? ParkingAnnotation {
            ParkingMarker(parking: parkingAnnotation.parking)
                .onTapGesture {
                    onTap()
                }
        } else if let clusterAnnotation = annotation as? ParkingClusterAnnotation {
            ParkingClusterMarker(parkings: clusterAnnotation.parkings)
                .onTapGesture {
                    onTap()
                }
        }
    }
}

struct ParkingClusterMarker: View {
    let parkings: [Parking]
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            VStack(spacing: 2) {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("\(parkings.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}
