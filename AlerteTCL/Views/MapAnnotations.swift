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
        /// = rayon corps (16) + demi-hauteur flèche (3.5) → flèche collée au cercle
        static let orbit:    CGFloat = 19
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
///
/// Mode compact (zoom éloigné) : simple disque 9pt.
/// Mode badges  (zoom serré)   : disque + capsules de ligne colorées en dessous.
///
///    ●          ← dot (coordonnée map = centre du dot)
///  C26 T1 …    ← badges (visibles en dessous à partir du seuil de zoom)
final class MergedStopAnnotationView: MKAnnotationView {
    static let identifier = "stop"

    private enum L {
        static let dot:     CGFloat = 9
        static let badgeH:  CGFloat = 14
        static let gap:     CGFloat = 3   // dot ↔ première rangée badges
        static let hPad:    CGFloat = 5   // padding horizontal à l'intérieur du badge
        static let spacing: CGFloat = 2   // espacement entre badges
        static let font = UIFont.systemFont(ofSize: 9, weight: .bold)
        static let maxBadges = 3
    }

    // Conteneur du disque (taille = L.dot × L.dot, réutilisé dans les deux modes)
    private let dotLayer: CALayer = {
        let l = CALayer()
        l.contents = MarkerImageCache.mergedStopDot().cgImage
        l.contentsGravity = .resizeAspect
        return l
    }()
    private var badgeLayers: [CALayer] = []

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        layer.addSublayer(dotLayer)
        // Mode compact par défaut
        setCompact()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - API

    func apply(stop: MergedStop, showBadges: Bool) {
        let visibleLines = stop.allLines.filter { !$0.hasPrefix("JD") }
        if showBadges && !visibleLines.isEmpty {
            let capped = Array(visibleLines.prefix(L.maxBadges))
            let overflow = visibleLines.count - capped.count
            setBadges(lines: capped, overflow: overflow)
        } else {
            setCompact()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setCompact()
    }

    // MARK: - Layouts

    private func setCompact() {
        badgeLayers.forEach { $0.removeFromSuperlayer() }
        badgeLayers = []
        let s = L.dot
        bounds          = CGRect(origin: .zero, size: CGSize(width: s, height: s))
        dotLayer.frame  = CGRect(origin: .zero, size: CGSize(width: s, height: s))
        centerOffset    = .zero
    }

    private func setBadges(lines: [String], overflow: Int) {
        badgeLayers.forEach { $0.removeFromSuperlayer() }
        badgeLayers = []

        // Calcul de la largeur totale de la rangée de badges.
        var totalBadgeW: CGFloat = 0
        var badgeWidths: [CGFloat] = []
        // Texte réel de chaque badge (y compris éventuel "+X")
        var allItems: [(text: String, isOverflow: Bool)] = lines.map { ($0, false) }
        if overflow > 0 { allItems.append(("+\(overflow)", true)) }
        for item in allItems {
            let tw = ceil((item.text as NSString).size(withAttributes: [.font: L.font]).width)
            let bw = tw + 2 * L.hPad
            badgeWidths.append(bw)
            totalBadgeW += bw
        }
        totalBadgeW += L.spacing * CGFloat(max(allItems.count - 1, 0))

        let totalW = max(L.dot, totalBadgeW)
        let totalH = L.dot + L.gap + L.badgeH

        bounds = CGRect(origin: .zero, size: CGSize(width: totalW, height: totalH))

        // Dot centré en haut.
        let dotX = (totalW - L.dot) / 2
        dotLayer.frame = CGRect(x: dotX, y: 0, width: L.dot, height: L.dot)

        // Badges centrés en dessous.
        var x = (totalW - totalBadgeW) / 2
        let y = L.dot + L.gap
        for (item, bw) in zip(allItems, badgeWidths) {
            let bgColor: UIColor  = item.isOverflow
                ? .secondarySystemFill
                : UIColor(LineColorHelper.backgroundColor(for: item.text))
            let txtColor: UIColor = item.isOverflow
                ? .secondaryLabel
                : UIColor(LineColorHelper.textColor(for: item.text))

            // Capsule (CALayer)
            let bg = CALayer()
            bg.frame           = CGRect(x: x, y: y, width: bw, height: L.badgeH)
            bg.backgroundColor = bgColor.cgColor
            bg.cornerRadius    = L.badgeH / 2
            bg.masksToBounds   = true

            // Texte (CATextLayer)
            let txt = CATextLayer()
            txt.string          = item.text
            txt.font           = L.font
            txt.fontSize       = 9
            txt.foregroundColor = txtColor.cgColor
            txt.alignmentMode  = .center
            txt.contentsScale  = UIScreen.main.scale
            txt.frame          = CGRect(x: L.hPad, y: (L.badgeH - 11) / 2, width: bw - 2 * L.hPad, height: 11)

            bg.addSublayer(txt)
            layer.addSublayer(bg)
            badgeLayers.append(bg)
            x += bw + L.spacing
        }

        // La coordonnée map doit pointer sur le centre du dot, pas le centre de la vue.
        centerOffset = CGPoint(x: 0, y: totalH / 2 - L.dot / 2)
    }
}
