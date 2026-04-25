import MapKit
import UIKit

// MARK: - Annotations (KVO-compliant pour animation fluide des coordinates)

/// Véhicule live (bus, tram, métro, etc.).
/// La coordinate est `dynamic` : MapKit peut ainsi animer son déplacement
/// via son propre système quand on met à jour la valeur.
final class VehicleAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let id: String
    var vehicle: Vehicle
    var bearing: Double

    init(vehicle: Vehicle, coordinate: CLLocationCoordinate2D, bearing: Double) {
        self.id = vehicle.id
        self.vehicle = vehicle
        self.coordinate = coordinate
        self.bearing = bearing
        super.init()
    }
}

final class ClusterAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let id: String
    var cluster: MapCluster<Vehicle>

    init(cluster: MapCluster<Vehicle>) {
        self.id = cluster.id
        self.cluster = cluster
        self.coordinate = cluster.coordinate
        super.init()
    }
}

final class MergedStopAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let id: String
    var stop: MergedStop

    init(stop: MergedStop) {
        self.id = stop.id
        self.stop = stop
        self.coordinate = stop.coordinate
        super.init()
    }
}

// MARK: - Annotation views

/// Vue d'annotation véhicule.
///
/// Géométrie du frame (carré 56 × 56 pt) :
///
///    centre = (28, 28)  ← coordonnée map / centre du corps
///
///  La flèche orbite à `orbit`=22 pt autour du centre du corps.
///  Position = (28 + orbit·sin θ, 28 − orbit·cos θ) en coord. UIKit.
///  L'image flèche pointe vers le haut au repos (bearing=0=nord) ;
///  la rotation CGAffineTransform la fait pointer dans la bonne direction.
///
///  Le frame 56 pt garantit que la flèche (10×7) reste à l'intérieur
///  quelle que soit la direction (worst-case est/ouest : centre à x=50, marge 1 pt).
///
/// Aucune UIHostingView, aucune View SwiftUI.
final class VehicleAnnotationView: MKAnnotationView {
    static let identifier = "vehicle"

    private enum Layout {
        static let bodySize: CGFloat = 32
        static let arrowW:   CGFloat = 10
        static let arrowH:   CGFloat = 7
        /// Distance entre le centre du corps et le centre de la flèche.
        /// = rayon corps (16) + 2 pt de marge + demi-hauteur flèche (3.5) ≈ 22
        static let orbit:    CGFloat = 22
        /// Côté du frame carré : 2 × (orbit + demi-largeur flèche + 1 pt)
        static let side:     CGFloat = 56
    }

    private let bodyLayer  = CALayer()
    private let arrowLayer = CALayer()

    private var currentLineName: String?
    private var currentType:     VehicleType?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func setUp() {
        backgroundColor = .clear

        // Frame carré : flèche orbitale toujours à l'intérieur.
        bounds = CGRect(origin: .zero, size: CGSize(width: Layout.side, height: Layout.side))

        layer.addSublayer(bodyLayer)
        layer.addSublayer(arrowLayer)

        // Corps centré dans le frame carré.
        bodyLayer.bounds   = CGRect(origin: .zero, size: CGSize(width: Layout.bodySize, height: Layout.bodySize))
        bodyLayer.position = CGPoint(x: Layout.side / 2, y: Layout.side / 2)  // (28, 28)
        bodyLayer.contentsGravity = .resizeAspect

        // Flèche : position initiale « nord » (au-dessus du corps).
        // Elle sera repositionnée + tournée dans apply(bearing:).
        arrowLayer.bounds         = CGRect(origin: .zero, size: CGSize(width: Layout.arrowW, height: Layout.arrowH))
        arrowLayer.position       = CGPoint(x: Layout.side / 2,
                                            y: Layout.side / 2 - Layout.orbit) // (28, 6)
        arrowLayer.contentsGravity = .resizeAspect
        arrowLayer.isHidden        = true

        // Corps centré → coordonnée map au centre de la vue.
        centerOffset = .zero
    }

    /// Mise à jour idempotente : ne re-rend que si les données discriminantes changent.
    func apply(vehicle: Vehicle, bearing: Double, showTooltip: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Corps (image pré-rendue, clé = lineName + vehicleType)
        if currentLineName != vehicle.lineName || currentType != vehicle.vehicleType {
            let img = MarkerImageCache.vehicleBody(lineName: vehicle.lineName, vehicleType: vehicle.vehicleType)
            bodyLayer.contents = img.cgImage
            currentLineName = vehicle.lineName
            currentType     = vehicle.vehicleType
        }

        // Flèche directionnelle (masquée si bearing = 0 / inconnu)
        if bearing != 0 {
            let img = MarkerImageCache.vehicleBearingArrow(lineName: vehicle.lineName)
            arrowLayer.contents = img.cgImage
            arrowLayer.isHidden  = false
            let θ = CGFloat(bearing * .pi / 180)
            let cx = Layout.side / 2
            let cy = Layout.side / 2
            // Orbite : déplace le centre de la flèche autour du corps.
            // UIKit : x → est, y ↓ → sud ⟹ nord = y − orbit·cos(0) = y − orbit.
            arrowLayer.position = CGPoint(
                x: cx + Layout.orbit * sin(θ),
                y: cy - Layout.orbit * cos(θ)
            )
            // L'image pointe vers le haut au repos (bearing=0=nord).
            arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: θ))
        } else {
            arrowLayer.isHidden = true
        }

        CATransaction.commit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentLineName = nil
        currentType     = nil
        arrowLayer.isHidden = true
    }
}

/// Vue d'annotation cluster (cercle bleu + nombre).
final class ClusterAnnotationView: MKAnnotationView {
    static let identifier = "cluster"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func apply(cluster: MapCluster<Vehicle>) {
        let img = MarkerImageCache.cluster(count: cluster.count)
        image = img
        frame = CGRect(origin: .zero, size: img.size)
    }
}

/// Vue d'annotation arrêt fusionné.
final class MergedStopAnnotationView: MKAnnotationView {
    static let identifier = "stop"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        image = MarkerImageCache.mergedStopDot()
        frame = CGRect(origin: .zero, size: image?.size ?? .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func apply(stop: MergedStop) {
        // Rien à faire : l'image du point est identique pour tous les arrêts.
        // Les badges de lignes (tooltip zoom serré) sont gérés par un éventuel
        // layer dédié ajouté en V2 si besoin.
    }
}
