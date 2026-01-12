import Foundation
import CoreLocation

struct ParkingCluster: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let parkings: [Parking]
    
    var totalPlaces: Int {
        parkings.reduce(0) { $0 + $1.capaciteTotale }
    }
    
    var availablePlaces: Int {
        parkings.reduce(0) { $0 + $1.placesDisponibles }
    }
    
    var averageOccupancy: Double {
        guard totalPlaces > 0 else { return 0 }
        return Double(totalPlaces - availablePlaces) / Double(totalPlaces)
    }
    
    var clusterColor: Color {
        switch averageOccupancy {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    static func == (lhs: ParkingCluster, rhs: ParkingCluster) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Cluster Marker View
struct ParkingClusterMarker: View {
    let cluster: ParkingCluster
    
    // Taille dynamique selon le nombre de parkings
    private var markerSize: CGFloat {
        let baseSize: CGFloat = 50
        let increment = min(CGFloat(cluster.parkings.count) * 3, 30)
        return baseSize + increment
    }
    
    var body: some View {
        ZStack {
            // Cercle de fond avec couleur selon disponibilité
            Circle()
                .fill(cluster.clusterColor)
                .frame(width: markerSize, height: markerSize)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            // Contenu du cluster
            VStack(spacing: 1) {
                // Icône parking
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: markerSize * 0.3, weight: .semibold))
                    .foregroundStyle(.white)
                
                // Nombre de parkings
                Text("\(cluster.parkings.count)")
                    .font(.system(size: markerSize * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            // Badge avec places disponibles (en haut à droite)
            VStack {
                HStack {
                    Spacer()
                    Text("\(cluster.availablePlaces)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(cluster.clusterColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: 6, y: -6)
                }
                Spacer()
            }
        }
        .frame(width: markerSize, height: markerSize)
    }
}

// MARK: - Color Extension
import SwiftUI

extension Color {
    static func clusterColor(for occupancy: Double) -> Color {
        switch occupancy {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

