import UIKit
import SwiftUI

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
        case .metro:   return 14
        case .tramway: return 12
        case .busC:    return 10.5
        case .bus:     return 8.5
        }
    }

    /// Diamètre du dot en mode badges (zoom serré)
    var badgeSize: CGFloat {
        switch self {
        case .metro:   return 16
        case .tramway: return 14
        case .busC:    return 12
        case .bus:     return 10
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

    /// Corps du marqueur véhicule : cercle coloré + icône SF Symbol.
    /// Taille fixe 32×32 pt (le point cardinal de la ligne est géré par un layer séparé).
    static func vehicleBody(lineName: String, vehicleType: VehicleType) -> UIImage {
        let key = VehicleBodyKey(lineName: lineName, vehicleType: vehicleType)
        if let cached = vehicleBodyCache.object(forKey: key) { return cached }
        let image = renderVehicleBody(lineName: lineName, vehicleType: vehicleType)
        vehicleBodyCache.setObject(image, forKey: key)
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
        let key = "stop-\(tier.rawValue)-\(primaryLine ?? "")-\(forBadge ? 1 : 0)" as NSString
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

    /// Tooltip de ponctualité (texte blanc sur capsule colorée).
    /// Peu fréquent (zoom serré uniquement) → cache clé (texte, couleur catégorielle).
    static func punctualityTooltip(text: String, status: PunctualityStatus) -> UIImage {
        let key = TooltipKey(text: text, status: status)
        if let cached = tooltipCache.object(forKey: key) { return cached }
        let image = renderPunctualityTooltip(text: text, color: status.color)
        tooltipCache.setObject(image, forKey: key)
        return image
    }

    // MARK: - Types

    enum PunctualityStatus: Int {
        case onTime, late, early

        var color: UIColor {
            switch self {
            case .onTime: return .systemGreen
            case .late:   return .systemRed
            case .early:  return .systemOrange
            }
        }

        init(vehicle: Vehicle) {
            if vehicle.isDelayed       { self = .late }
            else if vehicle.isEarly    { self = .early }
            else                        { self = .onTime }
        }
    }

    // MARK: - Caches (type-safe, purgés automatiquement en cas de pression mémoire)

    private static let vehicleBodyCache: NSCache<VehicleBodyKey, UIImage> = makeCache(name: "marker.vehicleBody", limit: 256)
    private static let bearingArrowCache: NSCache<NSString, UIImage>     = makeCache(name: "marker.arrow",       limit: 128)
    private static let vehicleDotCache:   NSCache<NSString, UIImage>      = makeCache(name: "marker.dot",         limit: 128)
    private static let tooltipCache: NSCache<TooltipKey, UIImage>        = makeCache(name: "marker.tooltip",     limit: 128)
    private static let sharedDotCache: NSCache<NSString, UIImage>        = makeCache(name: "marker.stopDot",     limit: 4)

    private static func makeCache<K, V>(name: String, limit: Int) -> NSCache<K, V> {
        let cache = NSCache<K, V>()
        cache.name = name
        cache.countLimit = limit
        return cache
    }

    // MARK: - Cache keys

    private final class VehicleBodyKey: NSObject {
        let lineName: String
        let vehicleType: VehicleType
        init(lineName: String, vehicleType: VehicleType) {
            self.lineName = lineName
            self.vehicleType = vehicleType
        }
        override var hash: Int {
            var h = Hasher()
            h.combine(lineName)
            h.combine(vehicleType)
            return h.finalize()
        }
        override func isEqual(_ object: Any?) -> Bool {
            guard let o = object as? VehicleBodyKey else { return false }
            return o.lineName == lineName && o.vehicleType == vehicleType
        }
    }

    private final class TooltipKey: NSObject {
        let text: String
        let status: PunctualityStatus
        init(text: String, status: PunctualityStatus) { self.text = text; self.status = status }
        override var hash: Int { text.hashValue ^ status.rawValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let o = object as? TooltipKey else { return false }
            return o.text == text && o.status == status
        }
    }

    // MARK: - Renderers

    /// Dimensions communes (en points, scale = écran).
    private enum Dim {
        static let vehicleDiameter: CGFloat = 32
        static let vehicleIconSize: CGFloat = 14
        static let stopDotOuter:    CGFloat = 9
        static let stopDotInner:    CGFloat = 5
        static let arrowWidth:      CGFloat = 10
        static let arrowHeight:     CGFloat = 7
    }

    private static func renderVehicleBody(lineName: String, vehicleType: VehicleType) -> UIImage {
        let size = CGSize(width: Dim.vehicleDiameter, height: Dim.vehicleDiameter)
        let bg = uiColor(LineColorHelper.backgroundColor(for: lineName))
        let fg = uiColor(LineColorHelper.textColor(for: lineName))
        let iconConfig = UIImage.SymbolConfiguration(pointSize: Dim.vehicleIconSize, weight: .bold)
        let icon = UIImage(systemName: vehicleType.icon, withConfiguration: iconConfig)?
            .withTintColor(fg, renderingMode: .alwaysOriginal)

        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Disque
            bg.setFill()
            cg.fillEllipse(in: rect)

            // Bordure fine 0.5pt (équivalent de strokeBorder(Color.black.opacity(0.15)))
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            cg.setLineWidth(0.5)
            cg.strokeEllipse(in: rect.insetBy(dx: 0.25, dy: 0.25))

            // Icône centrée
            if let icon {
                let s = icon.size
                icon.draw(in: CGRect(
                    x: (size.width  - s.width)  / 2,
                    y: (size.height - s.height) / 2,
                    width: s.width,
                    height: s.height
                ))
            }
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

        // Couleur du noyau selon le tier
        let fillColor: UIColor
        switch tier {
        case .metro:
            let line = primaryLine ?? ""
            fillColor = uiColor(LineColorHelper.backgroundColor(for: line))
        case .tramway:
            fillColor = UIColor(red: 0.40, green: 0.20, blue: 0.60, alpha: 1) // violet tram
        case .busC:
            fillColor = UIColor(red: 0.10, green: 0.20, blue: 0.55, alpha: 1) // bleu nuit bus C
        case .bus:
            fillColor = UIColor(red: 0.50, green: 0.55, blue: 0.62, alpha: 1) // gris bleuté
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

    private static func renderPunctualityTooltip(text: String, color: UIColor) -> UIImage {
        let font = UIFont.systemFont(ofSize: 9, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let hPad: CGFloat = 5
        let vPad: CGFloat = 2
        let size = CGSize(
            width:  ceil(textSize.width  + hPad * 2),
            height: ceil(textSize.height + vPad * 2)
        )

        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let capsule = UIBezierPath(roundedRect: rect, cornerRadius: size.height / 2)
            color.setFill()
            capsule.fill()

            cg.saveGState()
            let textRect = CGRect(
                x: hPad,
                y: (size.height - textSize.height) / 2,
                width:  textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attrs)
            cg.restoreGState()
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
