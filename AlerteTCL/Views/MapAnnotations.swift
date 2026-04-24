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
/// Géométrie du frame (fixe, 32 × 44 pt) :
///
///  ┌────────────────┐  y=0
///  │   topPad=12    │  ← zone flèche (arrow layer centré ici)
///  ├────────────────┤  y=12
///  │                │
///  │   body 32×32   │  ← bodyLayer + icône SF Symbol
///  │                │
///  └────────────────┘  y=44
///
/// `centerOffset = (0, -6)` → le centre du body (y=28) coïncide avec
/// la coordonnée map, pas le centre de la vue (y=22).
///
/// Aucune UIHostingView, aucune View SwiftUI.
final class VehicleAnnotationView: MKAnnotationView {
    static let identifier = "vehicle"

    private enum Layout {
        static let bodySize:     CGFloat = 32
        static let topPad:       CGFloat = 12   // espace au-dessus du corps pour la flèche
        static let totalHeight:  CGFloat = topPad + bodySize  // 44
        static let arrowW:       CGFloat = 10
        static let arrowH:       CGFloat = 7
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

        // Frame fixe : la flèche ET le corps sont dans ce rectangle.
        bounds = CGRect(origin: .zero, size: CGSize(width: Layout.bodySize, height: Layout.totalHeight))

        layer.addSublayer(bodyLayer)
        layer.addSublayer(arrowLayer)

        // Corps : occupe les 32pt inférieurs du frame.
        bodyLayer.bounds   = CGRect(origin: .zero, size: CGSize(width: Layout.bodySize, height: Layout.bodySize))
        bodyLayer.position = CGPoint(x: Layout.bodySize / 2,
                                     y: Layout.topPad + Layout.bodySize / 2)  // (16, 28)
        bodyLayer.contentsGravity = .resizeAspect

        // Flèche : centrée dans les topPad supérieurs.
        arrowLayer.bounds   = CGRect(origin: .zero, size: CGSize(width: Layout.arrowW, height: Layout.arrowH))
        arrowLayer.position = CGPoint(x: Layout.bodySize / 2,
                                      y: Layout.topPad / 2)                   // (16, 6)
        arrowLayer.contentsGravity = .resizeAspect
        arrowLayer.isHidden = true

        // La coordonnée map doit coïncider avec le CENTRE du corps (y=28),
        // pas le centre de la vue (y=22).
        // centerOffset.y < 0 remonte la vue : corps centre → coordonnée.
        // Formule : -(bodyCenterY − viewCenterY) = -(28 − 22) = −6
        let bodyCenterY = Layout.topPad + Layout.bodySize / 2     // 28
        let viewCenterY = Layout.totalHeight / 2                   // 22
        centerOffset = CGPoint(x: 0, y: -(bodyCenterY - viewCenterY))
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
            arrowLayer.isHidden = false
            // Rotation autour du centre du layer (anchorPoint = 0.5, 0.5 par défaut)
            arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(bearing * .pi / 180)))
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
