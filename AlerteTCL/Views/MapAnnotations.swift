import MapKit
import Shared
import SwiftUI
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
    /// Cache direct de la vue UIKit associée — élimine le lookup `mapView.view(for:)`
    /// dans la boucle d'animation (10 Hz × N véhicules). `weak` pour ne pas
    /// bloquer le recyclage des vues par MapKit.
    weak var annotationView: VehicleAnnotationView?

    init(vehicle: Vehicle, coordinate: CLLocationCoordinate2D, bearing: Double) {
        self.id = vehicle.id
        self.vehicle = vehicle
        self.coordinate = coordinate
        self.bearing = bearing
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
/// **Mode simplifié** (sous `MapStyle.ZOOM_VEHICLE_BODY`) : disque plat 12 pt, aucun layer
/// de flèche mis à jour → coût animation tick ≈ 0.
///
/// **Mode complet** : disque 32 pt portant le numéro de ligne + flèche orbitale 10×7 pt
/// dans un frame 56×56 pt, et à partir de `MapStyle.ZOOM_FRESHNESS_RING` un anneau de délai.
///
/// Aucune UIHostingView, aucune View SwiftUI.
final class VehicleAnnotationView: MKAnnotationView {
    static let identifier = "vehicle"

    private enum Layout {
        static let bodySize: CGFloat = 32
        static let arrowW:   CGFloat = 10
        static let arrowH:   CGFloat = 7
        static let orbit:    CGFloat = 19
        static let side:     CGFloat = 56
        static let dotSize:  CGFloat = 12   // mode simplifié
        static let ringGap:  CGFloat = 2.5  // espace entre le disque et l'anneau de délai
        static let ringWidth: CGFloat = 3
    }

    private let bodyLayer  = CALayer()
    private let arrowLayer = CALayer()
    /// Halo à la couleur de la ligne autour du véhicule sélectionné sur la carte.
    private let haloLayer  = CAShapeLayer()

    /// Véhicule sélectionné (filtre de ligne actif sur lui) : halo et passage au premier plan.
    var isFocusedVehicle = false {
        didSet { if isFocusedVehicle != oldValue { updateHalo() } }
    }
    /// Anneau autour du corps : se remplit avec le délai depuis la dernière position (0 à 90 s), dans la couleur de fraîcheur.
    private let ringLayer = CAShapeLayer()

    private var currentLineName:  String?
    private var currentSimplified: Bool = false
    private var currentRingFraction: CGFloat = -1
    private var currentRingFreshness: Vehicle.PositionFreshness?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func setUp() {
        backgroundColor = .clear
        // Véhicules toujours au-dessus des arrêts
        displayPriority = .required

        bounds = CGRect(origin: .zero, size: CGSize(width: Layout.side, height: Layout.side))

        haloLayer.isHidden = true
        layer.addSublayer(haloLayer)
        layer.addSublayer(bodyLayer)
        layer.addSublayer(arrowLayer)

        bodyLayer.bounds   = CGRect(origin: .zero, size: CGSize(width: Layout.bodySize, height: Layout.bodySize))
        bodyLayer.position = CGPoint(x: Layout.side / 2, y: Layout.side / 2)
        bodyLayer.contentsGravity = .resizeAspect

        arrowLayer.bounds          = CGRect(origin: .zero, size: CGSize(width: Layout.arrowW, height: Layout.arrowH))
        arrowLayer.position        = CGPoint(x: Layout.side / 2, y: Layout.side / 2 - Layout.orbit)
        arrowLayer.contentsGravity = .resizeAspect
        arrowLayer.isHidden        = true

        let ringRadius = Layout.bodySize / 2 + Layout.ringGap
        let ringRect = CGRect(x: Layout.side / 2 - ringRadius, y: Layout.side / 2 - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
        ringLayer.path        = UIBezierPath(ovalIn: ringRect).cgPath
        ringLayer.fillColor   = UIColor.clear.cgColor
        ringLayer.lineWidth   = Layout.ringWidth
        ringLayer.lineCap     = .round
        ringLayer.strokeStart = 0
        ringLayer.strokeEnd   = 0
        ringLayer.frame       = CGRect(origin: .zero, size: CGSize(width: Layout.side, height: Layout.side))
        // Départ en haut, sens horaire.
        ringLayer.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 2))
        ringLayer.isHidden    = true
        layer.addSublayer(ringLayer)

        centerOffset = .zero
    }

    /// Anneau de délai : ne touche le layer que si la part écoulée change de 2 % ou si la couleur change,
    /// pour rester quasi gratuit dans la boucle d'animation à 10 Hz.
    private func updateRing(vehicle: Vehicle, visible: Bool) {
        guard visible, vehicle.recordedAt != nil else {
            if !ringLayer.isHidden { ringLayer.isHidden = true }
            currentRingFraction = -1
            return
        }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let fraction = (CGFloat(vehicle.shared.freshnessFraction(nowEpochMs: nowMs)) * 50).rounded() / 50
        let freshness = vehicle.positionFreshness
        if freshness != currentRingFreshness {
            currentRingFreshness = freshness
            ringLayer.strokeColor = UIColor(freshness.color).cgColor
        }
        if fraction != currentRingFraction {
            currentRingFraction = fraction
            ringLayer.strokeEnd = fraction
        }
        if ringLayer.isHidden { ringLayer.isHidden = false }
    }

    // MARK: - API

    /// Halo autour du corps : diamètre 46 pt en mode complet, 24 pt autour du point en mode simplifié.
    private func updateHalo() {
        guard isFocusedVehicle, let lineName = currentLineName else {
            haloLayer.isHidden = true
            if zPriority != .defaultUnselected { zPriority = .defaultUnselected }
            return
        }
        let center = currentSimplified ? CGPoint(x: Layout.dotSize / 2, y: Layout.dotSize / 2)
                                       : CGPoint(x: Layout.side / 2, y: Layout.side / 2)
        let diameter: CGFloat = currentSimplified ? 24 : 46
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        let color = UIColor(LineColorHelper.backgroundColor(for: lineName))
        haloLayer.path        = UIBezierPath(ovalIn: rect).cgPath
        haloLayer.fillColor   = color.withAlphaComponent(0.22).cgColor
        haloLayer.strokeColor = color.cgColor
        haloLayer.lineWidth   = 2
        haloLayer.isHidden    = false
        if zPriority != .max { zPriority = .max }
    }

    /// Oublie la ligne rendue : le prochain `apply` régénère le corps (changement de palette de couleurs).
    func invalidateLineColors() {
        currentLineName = nil
    }

    func apply(vehicle: Vehicle, bearing: Double, showRing: Bool, simplified: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if simplified {
            // ── Mode dot : frame 12×12, aucune flèche ──────────────────────
            if !currentSimplified || currentLineName != vehicle.lineName {
                let d = Layout.dotSize
                bounds = CGRect(origin: .zero, size: CGSize(width: d, height: d))
                bodyLayer.bounds   = CGRect(origin: .zero, size: CGSize(width: d, height: d))
                bodyLayer.position = CGPoint(x: d / 2, y: d / 2)
                bodyLayer.contents = MarkerImageCache.vehicleDot(lineName: vehicle.lineName).cgImage
                centerOffset = .zero
                currentLineName = vehicle.lineName
            }
            arrowLayer.isHidden = true
            updateRing(vehicle: vehicle, visible: false)
            currentSimplified = true

        } else {
            // ── Mode complet : frame 56×56, corps + flèche ─────────────────
            if currentSimplified {
                // Restaurer la géométrie pleine taille
                bounds = CGRect(origin: .zero, size: CGSize(width: Layout.side, height: Layout.side))
                bodyLayer.bounds   = CGRect(origin: .zero, size: CGSize(width: Layout.bodySize, height: Layout.bodySize))
                bodyLayer.position = CGPoint(x: Layout.side / 2, y: Layout.side / 2)
                centerOffset = .zero
                currentLineName = nil  // forcer re-rendu du corps
            }

            if currentLineName != vehicle.lineName {
                bodyLayer.contents = MarkerImageCache.vehicleBody(lineName: vehicle.lineName).cgImage
                currentLineName = vehicle.lineName
            }

            if bearing != 0 {
                arrowLayer.contents = MarkerImageCache.vehicleBearingArrow(lineName: vehicle.lineName).cgImage
                arrowLayer.isHidden = false
                let θ = CGFloat(bearing * .pi / 180)
                arrowLayer.position = CGPoint(
                    x: Layout.side / 2 + Layout.orbit * sin(θ),
                    y: Layout.side / 2 - Layout.orbit * cos(θ)
                )
                arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: θ))
            } else {
                arrowLayer.isHidden = true
            }

            updateRing(vehicle: vehicle, visible: showRing)
            currentSimplified = false
        }

        updateHalo()

        CATransaction.commit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentLineName   = nil
        currentSimplified = false
        currentRingFraction = -1
        currentRingFreshness = nil
        arrowLayer.isHidden = true
        ringLayer.isHidden  = true
    }
}

/// Vue d'annotation arrêt fusionné.
///
/// Mode compact (zoom éloigné) : simple disque dont la taille et la couleur
///   reflètent la hiérarchie de la ligne la plus importante (metro > tram > busC > bus).
/// Mode badges  (zoom serré)   : disque + capsules de ligne colorées en dessous.
///
///    ●          ← dot (coordonnée map = centre du dot)
///  C26 T1 …    ← badges (visibles en dessous à partir du seuil de zoom)
final class MergedStopAnnotationView: MKAnnotationView {
    static let identifier = "stop"

    private enum L {
        // Badges
        static let badgeH:   CGFloat = 14
        static let gap:      CGFloat = 3
        static let hPad:     CGFloat = 4
        static let spacing:  CGFloat = 2
        static let font = UIFont.systemFont(ofSize: 9.5, weight: .bold)
        static let maxBadges = 4
    }

    private let dotLayer: CALayer = {
        let l = CALayer()
        l.contentsGravity = .resizeAspect
        l.shadowColor  = UIColor.black.cgColor
        l.shadowOpacity = 0
        l.shadowRadius  = 2
        l.shadowOffset  = CGSize(width: 0, height: 1)
        return l
    }()
    private var badgeLayers: [CALayer] = []
    private var currentTier: StopTier = .bus
    private var currentPrimaryLine: String? = nil

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        displayPriority = .defaultLow
        layer.addSublayer(dotLayer)
        setCompact(tier: .bus, primaryLine: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - API

    func apply(stop: MergedStop, showBadges: Bool) {
        let visibleLines = stop.allLines.filter { !$0.hasPrefix("JD") }
        let tier        = StopTier.from(lines: visibleLines)
        let primaryLine = StopTier.primaryLine(from: visibleLines)

        // Priorité d'affichage selon hiérarchie
        switch tier {
        case .metro:   displayPriority = .required
        case .tramway: displayPriority = .defaultHigh
        case .busC:    displayPriority = .defaultLow
        case .bus:     displayPriority = .defaultLow
        }

        if showBadges && !visibleLines.isEmpty {
            let capped   = Array(visibleLines.prefix(L.maxBadges))
            let overflow = visibleLines.count - capped.count
            setBadges(lines: capped, overflow: overflow, tier: tier, primaryLine: primaryLine)
        } else {
            setCompact(tier: tier, primaryLine: primaryLine)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setCompact(tier: .bus, primaryLine: nil)
    }

    // MARK: - Layouts

    private func setCompact(tier: StopTier, primaryLine: String?) {
        badgeLayers.forEach { $0.removeFromSuperlayer() }
        badgeLayers = []
        dotLayer.shadowOpacity = 0
        let s = tier.compactSize
        dotLayer.contents = MarkerImageCache.mergedStopDot(tier: tier, primaryLine: primaryLine, forBadge: false).cgImage
        bounds         = CGRect(origin: .zero, size: CGSize(width: s, height: s))
        dotLayer.frame = CGRect(origin: .zero, size: CGSize(width: s, height: s))
        centerOffset   = .zero
    }

    private func setBadges(lines: [String], overflow: Int, tier: StopTier, primaryLine: String?) {
        badgeLayers.forEach { $0.removeFromSuperlayer() }
        badgeLayers = []

        dotLayer.shadowOpacity = tier == .metro ? 0.30 : 0.22
        dotLayer.contents = MarkerImageCache.mergedStopDot(tier: tier, primaryLine: primaryLine, forBadge: true).cgImage

        let d = tier.badgeSize

        // Construction de la liste d'items avec éventuel overflow
        var allItems: [(text: String, isOverflow: Bool)] = lines.map { ($0, false) }
        if overflow > 0 { allItems.append(("+\(overflow)", true)) }

        // Pré-calculer les largeurs des badges
        var badgeWidths: [CGFloat] = []
        var totalBadgeW: CGFloat = 0
        for item in allItems {
            let tw = ceil((item.text as NSString).size(withAttributes: [.font: L.font]).width)
            let bw = tw + 2 * L.hPad
            badgeWidths.append(bw)
            totalBadgeW += bw
        }
        totalBadgeW += L.spacing * CGFloat(max(allItems.count - 1, 0))

        let totalW = max(d, totalBadgeW)
        let totalH = d + L.gap + L.badgeH

        bounds = CGRect(origin: .zero, size: CGSize(width: totalW, height: totalH))

        // Dot centré horizontalement en haut
        let dotX = (totalW - d) / 2
        dotLayer.frame = CGRect(x: dotX, y: 0, width: d, height: d)

        // Rangée de badges centrée sous le dot
        var x = (totalW - totalBadgeW) / 2
        let y = d + L.gap

        for (item, bw) in zip(allItems, badgeWidths) {
            let bgColor: UIColor
            let txtColor: UIColor
            let needsBorder: Bool

            if item.isOverflow {
                bgColor     = UIColor(Color.appNeutralFill)
                txtColor    = UIColor.secondaryLabel
                needsBorder = false
            } else {
                bgColor     = UIColor(LineColorHelper.backgroundColor(for: item.text))
                txtColor    = UIColor(LineColorHelper.textColor(for: item.text))
                needsBorder = LineColorHelper.needsBorder(for: item.text)
            }

            // Capsule de fond
            let bg = CALayer()
            bg.frame           = CGRect(x: x, y: y, width: bw, height: L.badgeH)
            bg.backgroundColor = bgColor.cgColor
            bg.cornerRadius    = L.badgeH / 2
            bg.masksToBounds   = false  // false pour permettre contour + ombre éventuelle

            // Bordure fine sur les badges à fond clair (bus blanc)
            if needsBorder {
                bg.borderWidth = 0.5
                bg.borderColor = UIColor(Color.appNeutralBorder).cgColor
            }
            // Clip après borderColor pour que le texte reste dans la capsule
            bg.masksToBounds   = true

            // Texte
            let txt = CATextLayer()
            txt.string         = item.text
            txt.font           = L.font
            txt.fontSize       = 9.5
            txt.foregroundColor = txtColor.cgColor
            txt.alignmentMode  = .center
            txt.contentsScale  = UIScreen.main.scale
            // Centrer verticalement le texte dans le badge
            let textH: CGFloat = 12
            txt.frame          = CGRect(x: L.hPad,
                                        y: (L.badgeH - textH) / 2,
                                        width: bw - 2 * L.hPad,
                                        height: textH)

            bg.addSublayer(txt)
            layer.addSublayer(bg)
            badgeLayers.append(bg)
            x += bw + L.spacing
        }

        // La coordonnée map pointe sur le centre du dot
        centerOffset = CGPoint(x: 0, y: totalH / 2 - d / 2)
    }
}
