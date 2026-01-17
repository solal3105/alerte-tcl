import Foundation
import CoreLocation
import SwiftUI

// MARK: - Clusterable Protocol

/// Protocol pour tout élément qui peut être clusterisé sur une carte
protocol Clusterable: Identifiable {
    var coordinate: CLLocationCoordinate2D { get }
    var clusterColor: Color { get }
    var clusterIcon: String { get }
}

// MARK: - Generic Cluster

/// Cluster générique qui regroupe des éléments Clusterable
struct MapCluster<T: Clusterable>: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let items: [T]
    
    var count: Int { items.count }
    
    /// Couleur dominante du cluster (basée sur la majorité des items)
    var dominantColor: Color {
        let colorCounts = Dictionary(grouping: items, by: { $0.clusterColor.description })
        let dominantColorGroup = colorCounts.max(by: { $0.value.count < $1.value.count })
        return dominantColorGroup?.value.first?.clusterColor ?? .blue
    }
    
    /// Icône dominante du cluster
    var dominantIcon: String {
        let iconCounts = Dictionary(grouping: items, by: { $0.clusterIcon })
        let dominantIconGroup = iconCounts.max(by: { $0.value.count < $1.value.count })
        return dominantIconGroup?.key ?? "mappin"
    }
    
    init(items: [T]) {
        let sortedIds = items.map { "\($0.id)" }.sorted().joined(separator: "-")
        self.id = "cluster-\(sortedIds.hashValue)"
        self.items = items
        
        let avgLat = items.map { $0.coordinate.latitude }.reduce(0, +) / Double(items.count)
        let avgLon = items.map { $0.coordinate.longitude }.reduce(0, +) / Double(items.count)
        self.coordinate = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
}

// MARK: - Clustering Engine

/// Moteur de clustering basé sur la distance écran (zoom-aware)
/// Le rayon de clustering s'adapte au niveau de zoom pour éviter que les markers se chevauchent
enum ClusteringEngine {
    
    /// Configuration du clustering
    struct Configuration {
        /// Taille cible du cluster en pixels à l'écran (~60px = taille d'un marker)
        let screenClusterSize: Double
        /// Nombre minimum d'items pour former un cluster
        let minItemsForCluster: Int
        
        static let `default` = Configuration(
            screenClusterSize: 60,
            minItemsForCluster: 2
        )
        
        static let dense = Configuration(
            screenClusterSize: 80,  // Plus gros clusters
            minItemsForCluster: 2
        )
        
        static let sparse = Configuration(
            screenClusterSize: 45,  // Clusters plus petits
            minItemsForCluster: 2
        )
    }
    
    /// Seuil de zoom en dessous duquel on désactive le clustering (zoom fort = latitudeDelta petit)
    /// Basé sur 0.03 : niveau de zoom utilisé lors de la localisation utilisateur
    /// Jamais de clusters en dessous de ce niveau quelque soit l'onglet
    static let clusteringZoomThreshold: Double = 0.03
    
    /// Le clustering est désactivé quand on zoome fortement (pour voir les détails)
    static func shouldCluster(zoomLevel: Double, config: Configuration = .default) -> Bool {
        // Pas de clustering si on est à 0.01 ou moins (niveau de localisation utilisateur)
        return zoomLevel > clusteringZoomThreshold + 0.001
    }
    
    /// Convertit une distance écran (pixels) en distance géographique (degrés)
    /// basée sur le niveau de zoom actuel (latitudeDelta)
    private static func screenToGeoDistance(screenPixels: Double, zoomLevel: Double) -> Double {
        // zoomLevel = latitudeDelta de la région visible
        // On estime qu'un écran fait ~400 points de large en moyenne
        // Donc 1 pixel ≈ zoomLevel / 400 degrés
        let degreesPerPixel = zoomLevel / 400.0
        return screenPixels * degreesPerPixel
    }
    
    /// Crée des clusters basés sur la distance écran (les markers ne se chevauchent pas)
    static func createClusters<T: Clusterable>(
        from items: [T],
        zoomLevel: Double,
        config: Configuration = .default
    ) -> (clusters: [MapCluster<T>], unclustered: [T]) {
        guard !items.isEmpty else { return ([], []) }
        
        // Convertir la taille écran cible en distance géographique
        let clusterRadius = screenToGeoDistance(screenPixels: config.screenClusterSize, zoomLevel: zoomLevel)
        
        var clusteredIds: Set<String> = []
        var clusters: [MapCluster<T>] = []
        var unclustered: [T] = []
        
        // Trier par position pour un clustering plus cohérent
        let sortedItems = items.sorted { 
            $0.coordinate.latitude + $0.coordinate.longitude < $1.coordinate.latitude + $1.coordinate.longitude 
        }
        
        for item in sortedItems {
            let itemId = "\(item.id)"
            guard !clusteredIds.contains(itemId) else { continue }
            
            var clusterItems = [item]
            clusteredIds.insert(itemId)
            
            for other in sortedItems {
                let otherId = "\(other.id)"
                guard !clusteredIds.contains(otherId) else { continue }
                
                let distance = sqrt(
                    pow(item.coordinate.latitude - other.coordinate.latitude, 2) +
                    pow(item.coordinate.longitude - other.coordinate.longitude, 2)
                )
                
                if distance < clusterRadius {
                    clusterItems.append(other)
                    clusteredIds.insert(otherId)
                }
            }
            
            if clusterItems.count >= config.minItemsForCluster {
                clusters.append(MapCluster(items: clusterItems))
            } else {
                unclustered.append(contentsOf: clusterItems)
            }
        }
        
        return (clusters, unclustered)
    }
}

// MARK: - Unified Cluster Marker View

/// Vue de cluster unifiée avec un design moderne et cohérent
struct UnifiedClusterMarker<T: Clusterable>: View {
    let cluster: MapCluster<T>
    let style: ClusterStyle
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    enum ClusterStyle {
        case standard
        case transport
        case parking
        case travaux
        
        var backgroundOpacity: Double {
            switch self {
            case .standard, .transport: return 1.0
            case .parking: return 0.95
            case .travaux: return 0.95
            }
        }
    }
    
    init(cluster: MapCluster<T>, style: ClusterStyle = .standard) {
        self.cluster = cluster
        self.style = style
    }
    
    private var markerSize: CGFloat {
        let baseSize: CGFloat = 44
        let increment = min(CGFloat(cluster.count) * 2, 16)
        return baseSize + increment
    }
    
    private var backgroundColor: Color {
        cluster.dominantColor
    }
    
    var body: some View {
        ZStack {
            // Cercle externe avec ombre
            Circle()
                .fill(backgroundColor.opacity(style.backgroundOpacity))
                .frame(width: markerSize, height: markerSize)
                .shadow(color: backgroundColor.opacity(0.4), radius: 6, x: 0, y: 3)
            
            // Cercle interne semi-transparent
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: markerSize - 8, height: markerSize - 8)
            
            // Contenu
            VStack(spacing: 2) {
                Image(systemName: cluster.dominantIcon)
                    .font(.system(size: markerSize * 0.28, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(cluster.count)")
                    .font(.system(size: markerSize * 0.28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: markerSize, height: markerSize)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cluster.count)
    }
}

// MARK: - Specialized Cluster Markers

/// Marker pour les clusters de parking - affiche le nombre de parkings + pastille avec places
struct ParkingClusterMarker: View {
    let cluster: MapCluster<Parking>
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    private var markerSize: CGFloat {
        let baseSize: CGFloat = 44
        let increment = min(CGFloat(cluster.count) * 2, 16)
        return baseSize + increment
    }
    
    private var availablePlaces: Int {
        cluster.items.reduce(0) { $0 + $1.placesDisponibles }
    }
    
    private var totalPlaces: Int {
        cluster.items.reduce(0) { $0 + $1.capaciteTotale }
    }
    
    private var averageOccupancy: Double {
        guard totalPlaces > 0 else { return 0 }
        return Double(totalPlaces - availablePlaces) / Double(totalPlaces)
    }
    
    private var clusterColor: Color {
        // Déterminer le type dominant du cluster
        let typeCounts = Dictionary(grouping: cluster.items, by: { $0.parkingType })
        let dominantType = typeCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .car
        
        switch dominantType {
        case .bike:
            return .green
        case .motorized2Wheel:
            return .orange
        case .car:
            // Pour les voitures, couleur selon la disponibilité
            switch averageOccupancy {
            case 0..<0.5: return .green
            case 0.5..<0.8: return .orange
            default: return .red
            }
        }
    }
    
    private var placesText: String {
        if availablePlaces >= 1000 {
            return "\(availablePlaces / 1000)k places"
        }
        return "\(availablePlaces) places"
    }
    
    var body: some View {
        ZStack {
            // Cercle principal
            Circle()
                .fill(clusterColor)
                .frame(width: markerSize, height: markerSize)
                .shadow(color: clusterColor.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Cercle interne
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: markerSize - 8, height: markerSize - 8)
            
            // Nombre de parkings (principal)
            Text("\(cluster.count)")
                .font(.system(size: markerSize * 0.4, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            // Pastille P en bas avec nombre de places
            VStack {
                Spacer()
                Text(placesText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(clusterColor.opacity(0.9))
                            .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    )
                    .offset(y: 6)
            }
        }
        .frame(width: markerSize, height: markerSize + 12)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cluster.count)
    }
}

/// Marker simplifié pour les clusters de travaux - juste le nombre
struct TravauxClusterMarker: View {
    let cluster: MapCluster<Travaux>
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    private var markerSize: CGFloat {
        let baseSize: CGFloat = 44
        let increment = min(CGFloat(cluster.count) * 2, 16)
        return baseSize + increment
    }
    
    private var dominantColor: Color {
        let tresPerturbant = cluster.items.filter { $0.importance == .tresPerturbant }.count
        let perturbant = cluster.items.filter { $0.importance == .perturbant }.count
        
        if tresPerturbant > 0 { return .red }
        if perturbant > 0 { return .orange }
        return .yellow
    }
    
    var body: some View {
        ZStack {
            // Cercle principal
            Circle()
                .fill(dominantColor)
                .frame(width: markerSize, height: markerSize)
                .shadow(color: dominantColor.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Cercle interne
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: markerSize - 8, height: markerSize - 8)
            
            // Contenu simplifié: juste le nombre
            Text("\(cluster.count)")
                .font(.system(size: markerSize * 0.4, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: markerSize, height: markerSize)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cluster.count)
    }
}

/// Marker simplifié pour les clusters de transport - juste le nombre
struct TransportClusterMarker: View {
    let cluster: MapCluster<Vehicle>
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    private var markerSize: CGFloat {
        let baseSize: CGFloat = 44
        let increment = min(CGFloat(cluster.count) * 2, 14)
        return baseSize + increment
    }
    
    private var dominantType: VehicleType {
        let typeCounts = Dictionary(grouping: cluster.items, by: { $0.vehicleType })
        return typeCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .bus
    }
    
    private var clusterColor: Color {
        // Tous les clusters de transports sont bleus
        .blue
    }
    
    var body: some View {
        ZStack {
            // Cercle principal
            Circle()
                .fill(clusterColor)
                .frame(width: markerSize, height: markerSize)
                .shadow(color: clusterColor.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Cercle interne
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: markerSize - 8, height: markerSize - 8)
            
            // Contenu simplifié: juste le nombre
            Text("\(cluster.count)")
                .font(.system(size: markerSize * 0.4, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: markerSize, height: markerSize)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cluster.count)
    }
}
