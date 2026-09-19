import UIKit
import SwiftUI
import Shared

// MARK: - Stop Tier

/// Hiérarchie visuelle des arrêts TCL sur la carte.
/// Dérivée des lignes desservies : metro > tramway > busC > bus.
enum StopTier: Int {
    case metro
    case tramway
    case busC
    case bus

    // MARK: Dimensions

    /// Diamètre du dot en mode compact (zoom éloigné)
    var compactSize: CGFloat {
        switch self {
        case .metro:   return 17
        case .tramway: return 15
        case .busC:    return 13
        case .bus:     return 11
        }
    }

    /// Diamètre du dot en mode badges (zoom serré)
    var badgeSize: CGFloat {
        switch self {
        case .metro:   return 20
        case .tramway: return 17
        case .busC:    return 15
        case .bus:     return 13
        }
    }

    /// Épaisseur de l'anneau blanc extérieur
    var strokeWidth: CGFloat {
        switch self {
        case .metro:   return 2.5
        case .tramway: return 2.0
        case .busC:    return 1.8
        case .bus:     return 1.5
        }
    }

    /// Métro et tramway prennent la couleur officielle de leur ligne principale.
    var usesLineColor: Bool { self == .metro || self == .tramway }

    // MARK: Factory

    static func from(lines: [String]) -> StopTier {
        let modes = lines.map { TransportMode.detectFromLine($0) }
        if modes.contains(.metro)   { return .metro }
        if modes.contains(.tramway) { return .tramway }
        if modes.contains(.busC)    { return .busC }
        return .bus
    }

    /// Première ligne de la hiérarchie la plus haute parmi `lines`
    static func primaryLine(from lines: [String]) -> String? {
        lines.min { a, b in
            TransportMode.detectFromLine(a).sortOrder < TransportMode.detectFromLine(b).sortOrder
        }
    }
}

/// Cache d'images pré-rendues pour les marqueurs de carte UIKit.
///
/// **Pourquoi** : `Annotation(coordinate:) { SwiftUIView }` crée un `UIHostingView`
/// + un sous-graphe `AttributeGraph` par marqueur. Avec 300+ marqueurs,
/// `beginTransaction` doit visiter chaque sous-graphe à chaque tick d'animation
/// (≈ 27 % du CPU, O(N) par tick même avec `.equatable()`).
///
/// Une `UIImage` posée sur `MKAnnotationView.image` n'a ni graphe, ni
/// transaction : le seul coût au tick est le repositionnement MapKit
/// (irréductible, ≈ 7 %).
///
/// Les clés sont construites à partir des **données discriminantes du rendu**
/// uniquement (couleur, icône, taille). Un même couple (ligneA, bus) partage
/// une seule image pour tous les véhicules.
enum MarkerImageCache {

    // MARK: - Public API

    /// Corps du marqueur véhicule : disque à la couleur de la ligne portant le pictogramme de son type
    /// (même rendu qu'Android). Taille fixe 32×32 pt ; la flèche de cap et le numéro sont des layers séparés.
    static func vehicleBody(lineName: String, type: VehicleType) -> UIImage {
        let key = "\(type.rawValue)|\(lineName)" as NSString
        if let cached = vehicleBodyCache.object(forKey: key) { return cached }
        let image = renderVehicleBody(lineName: lineName, symbol: type.icon)
        vehicleBodyCache.setObject(image, forKey: key)
        return image
    }

    /// Numéro de ligne dans une capsule à la couleur de la ligne, affiché sous le disque. Hauteur fixe 14 pt.
    static func vehicleLabel(lineName: String) -> UIImage {
        let key = lineName as NSString
        if let cached = vehicleLabelCache.object(forKey: key) { return cached }
        let image = renderVehicleLabel(lineName: lineName)
        vehicleLabelCache.setObject(image, forKey: key)
        return image
    }

    /// Triangle directionnel (pointe en haut, à rotater via `CALayer.transform`).
    /// Colorié à la couleur de la ligne.
    static func vehicleBearingArrow(lineName: String) -> UIImage {
        let key = lineName as NSString
        if let cached = bearingArrowCache.object(forKey: key) { return cached }
        let image = renderBearingArrow(color: uiColor(LineColorHelper.backgroundColor(for: lineName)))
        bearingArrowCache.setObject(image, forKey: key)
        return image
    }

    /// Point d'arrêt TCL — taille et couleur selon le tier de la ligne la plus importante.
    static func mergedStopDot(tier: StopTier, primaryLine: String?, forBadge: Bool = false) -> UIImage {
        // Le rendu n'utilise primaryLine que pour le métro et le tramway (couleur du noyau) :
        // l'ignorer ailleurs garde un espace de clés minimal.
        let lineKey = tier.usesLineColor ? (primaryLine ?? "") : ""
        let key = "stop-\(tier.rawValue)-\(lineKey)-\(forBadge ? 1 : 0)" as NSString
        if let cached = sharedDotCache.object(forKey: key) { return cached }
        let image = renderStopDot(tier: tier, primaryLine: primaryLine, forBadge: forBadge)
        sharedDotCache.setObject(image, forKey: key)
        return image
    }

    /// Petit disque plat (dezoom) : cercle de couleur sans icône ni flèche.
    /// Taille fixe 12×12 pt. Clé = nom de ligne (la couleur dépend uniquement de la ligne).
    static func vehicleDot(lineName: String) -> UIImage {
        let key = lineName as NSString
        if let cached = vehicleDotCache.object(forKey: key) { return cached }
        let image = renderVehicleDot(lineName: lineName)
        vehicleDotCache.setObject(image, forKey: key)
        return image
    }


    /// Marqueur d'une station Vélo'v : carré arrondi à la couleur de disponibilité, le pictogramme du
    /// filtre courant et le nombre compté.
    static func velovMarker(count: Int, availability: AvailabilityColor, symbol: String) -> UIImage {
        let key = "velov-\(count)-\(availability.name)-\(symbol)" as NSString
        if let cached = velovCache.object(forKey: key) { return cached }
        let color = uiColor(Color(token: AppColors.shared.parkingAvailability(color: availability)))
        let image = renderVelovMarker(bikes: count, color: color, symbol: symbol)
        velovCache.setObject(image, forKey: key)
        return image
    }

    /// Vide toutes les images : à appeler quand la palette des couleurs de lignes change.
    static func clearAll() {
        vehicleBodyCache.removeAllObjects()
        vehicleLabelCache.removeAllObjects()
        bearingArrowCache.removeAllObjects()
        vehicleDotCache.removeAllObjects()
        sharedDotCache.removeAllObjects()
    }

    // MARK: - Types


    // MARK: - Caches (type-safe, purgés automatiquement en cas de pression mémoire)

    private static let vehicleBodyCache: NSCache<NSString, UIImage>     = makeCache(name: "marker.vehicleBody", limit: 256)
    private static let vehicleLabelCache: NSCache<NSString, UIImage>    = makeCache(name: "marker.vehicleLabel", limit: 256)
    private static let bearingArrowCache: NSCache<NSString, UIImage>     = makeCache(name: "marker.arrow",       limit: 128)
    private static let vehicleDotCache:   NSCache<NSString, UIImage>      = makeCache(name: "marker.dot",         limit: 128)
    private static let sharedDotCache: NSCache<NSString, UIImage>        = makeCache(name: "marker.stopDot",     limit: 64)
    private static let velovCache: NSCache<NSString, UIImage>            = makeCache(name: "marker.velov",       limit: 256)

    private static func makeCache<K, V>(name: String, limit: Int) -> NSCache<K, V> {
        let cache = NSCache<K, V>()
        cache.name = name
        cache.countLimit = limit
        return cache
    }

    // MARK: - Cache keys



    // MARK: - Renderers

    /// Dimensions communes (en points, scale = écran).
    private enum Dim {
        static let vehicleDiameter: CGFloat = 32
        static let vehicleLabelHeight: CGFloat = 14
        static let stopDotOuter:    CGFloat = 9
        static let stopDotInner:    CGFloat = 5
        static let arrowWidth:      CGFloat = 10
        static let arrowHeight:     CGFloat = 7
    }

    private static func renderVehicleBody(lineName: String, symbol: String) -> UIImage {
        let size = CGSize(width: Dim.vehicleDiameter, height: Dim.vehicleDiameter)
        let bg = uiColor(LineColorHelper.backgroundColor(for: lineName))
        let fg = uiColor(LineColorHelper.textColor(for: lineName))
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?.withTintColor(fg, renderingMode: .alwaysOriginal)

        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Disque
            bg.setFill()
            cg.fillEllipse(in: rect)

            // Bordure fine
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            cg.setLineWidth(0.5)
            cg.strokeEllipse(in: rect.insetBy(dx: 0.25, dy: 0.25))

            // Pictogramme du type de véhicule, centré
            if let glyph {
                let glyphSize = glyph.size
                glyph.draw(in: CGRect(x: (size.width - glyphSize.width) / 2, y: (size.height - glyphSize.height) / 2,
                                      width: glyphSize.width, height: glyphSize.height))
            }
        }
    }

    private static func renderVehicleLabel(lineName: String) -> UIImage {
        let bg = uiColor(LineColorHelper.backgroundColor(for: lineName))
        let fg = uiColor(LineColorHelper.textColor(for: lineName))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .heavy),
            .foregroundColor: fg,
        ]
        let text = lineName as NSString
        let textSize = text.size(withAttributes: attributes)
        let size = CGSize(width: ceil(textSize.width) + 10, height: Dim.vehicleLabelHeight)

        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let capsule = UIBezierPath(roundedRect: rect.insetBy(dx: 0.25, dy: 0.25), cornerRadius: size.height / 2)
            bg.setFill()
            capsule.fill()
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            cg.setLineWidth(0.5)
            capsule.stroke()
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2), withAttributes: attributes)
        }
    }

    private static func renderVelovMarker(bikes: Int, color: UIColor, symbol: String) -> UIImage {
        let size = CGSize(width: 30, height: 30)
        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 9)
            cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            color.setFill()
            path.fill()
            cg.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.white.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 1.5
            path.stroke()

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            if let icon = UIImage(systemName: symbol, withConfiguration: iconConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let s = icon.size
                icon.draw(in: CGRect(x: (size.width - s.width) / 2, y: 4, width: s.width, height: s.height))
            }
            let text = "\(bikes)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .heavy),
                .foregroundColor: UIColor.white,
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: size.height - textSize.height - 3), withAttributes: attributes)
        }
    }

    private static func renderBearingArrow(color: UIColor) -> UIImage {
        let size = CGSize(width: Dim.arrowWidth, height: Dim.arrowHeight)
        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            cg.move(to: CGPoint(x: size.width / 2, y: 0))
            cg.addLine(to: CGPoint(x: size.width, y: size.height))
            cg.addLine(to: CGPoint(x: 0, y: size.height))
            cg.closePath()
            color.setFill()
            cg.fillPath()
        }
    }

    private static func renderStopDot(tier: StopTier, primaryLine: String?, forBadge: Bool) -> UIImage {
        let outer = forBadge ? tier.badgeSize : tier.compactSize
        let stroke = tier.strokeWidth
        let inner = outer - stroke * 2
        let size = CGSize(width: outer, height: outer)

        // Couleur du noyau : celle de la ligne principale pour le métro et le tramway, sinon celle du tier
        let fillColor: UIColor
        switch tier {
        case .metro, .tramway:
            fillColor = uiColor(LineColorHelper.backgroundColor(for: primaryLine ?? ""))
        case .busC:
            fillColor = UIColor(Color(hex: AppColors.shared.stopMarkerBusC))
        case .bus:
            fillColor = UIColor(Color(hex: AppColors.shared.stopMarkerBus))
        }

        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Ombre portée pour visibilité sur carte (metro + tram uniquement)
            if tier == .metro || tier == .tramway {
                cg.setShadow(offset: CGSize(width: 0, height: 1),
                             blur: 2.5,
                             color: UIColor.black.withAlphaComponent(0.30).cgColor)
            }

            // Anneau blanc extérieur
            UIColor.white.setFill()
            cg.fillEllipse(in: rect)

            cg.setShadow(offset: .zero, blur: 0, color: nil) // reset ombre avant noyau

            // Noyau coloré
            fillColor.setFill()
            let innerRect = rect.insetBy(dx: stroke, dy: stroke)
            cg.fillEllipse(in: innerRect)

            // Micro-détail : point blanc central sur le métro pour effet "œil"
            if tier == .metro {
                UIColor.white.withAlphaComponent(0.35).setFill()
                let pip = inner * 0.30
                let pipRect = CGRect(
                    x: outer / 2 - pip / 2,
                    y: outer / 2 - pip / 2,
                    width: pip, height: pip
                )
                cg.fillEllipse(in: pipRect)
            }
        }
    }

    private static func renderVehicleDot(lineName: String) -> UIImage {
        let s: CGFloat = 12
        let size = CGSize(width: s, height: s)
        let color = uiColor(LineColorHelper.backgroundColor(for: lineName))
        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            color.setFill()
            cg.fillEllipse(in: CGRect(origin: .zero, size: size))
            // Bordure fine pour visibilité sur fond clair
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.18).cgColor)
            cg.setLineWidth(0.5)
            cg.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 0.25, dy: 0.25))
        }
    }


    // MARK: - Helpers

    private static func imageRenderer(size: CGSize) -> UIGraphicsImageRenderer {
        let fmt = UIGraphicsImageRendererFormat.preferred()
        fmt.opaque = false
        fmt.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: fmt)
    }

    private static func uiColor(_ color: Color) -> UIColor {
        UIColor(color)
    }

}
