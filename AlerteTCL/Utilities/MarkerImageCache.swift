import UIKit
import SwiftUI

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

    /// Point d'arrêt TCL (petit disque blanc + noyau violet).
    static func mergedStopDot() -> UIImage {
        if let cached = sharedDotCache.object(forKey: "mergedStopDot" as NSString) { return cached }
        let image = renderStopDot()
        sharedDotCache.setObject(image, forKey: "mergedStopDot" as NSString)
        return image
    }

    /// Marqueur de cluster : cercle bleu + nombre. Taille dépend du count.
    static func cluster(count: Int) -> UIImage {
        let bucket = clusterBucket(for: count)
        let key = ClusterKey(bucket: bucket, count: count)
        if let cached = clusterCache.object(forKey: key) { return cached }
        let image = renderCluster(count: count, diameter: bucket)
        clusterCache.setObject(image, forKey: key)
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
    private static let clusterCache: NSCache<ClusterKey, UIImage>        = makeCache(name: "marker.cluster",     limit: 64)
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

    private final class ClusterKey: NSObject {
        let bucket: CGFloat
        let count: Int
        init(bucket: CGFloat, count: Int) { self.bucket = bucket; self.count = count }
        override var hash: Int { count.hashValue ^ bucket.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let o = object as? ClusterKey else { return false }
            return o.bucket == bucket && o.count == count
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

    private static func renderStopDot() -> UIImage {
        let size = CGSize(width: Dim.stopDotOuter, height: Dim.stopDotOuter)
        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            cg.fillEllipse(in: CGRect(origin: .zero, size: size))

            let innerRect = CGRect(
                x: (size.width  - Dim.stopDotInner) / 2,
                y: (size.height - Dim.stopDotInner) / 2,
                width:  Dim.stopDotInner,
                height: Dim.stopDotInner
            )
            UIColor.systemPurple.setFill()
            cg.fillEllipse(in: innerRect)
        }
    }

    private static func renderCluster(count: Int, diameter: CGFloat) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        let text = "\(count)"
        let fontSize = diameter * 0.4
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: UIColor.white,
        ]

        return imageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            UIColor.systemBlue.setFill()
            cg.fillEllipse(in: rect)

            // Halo interne (effet "cercle blanc opacité 0.15")
            UIColor.white.withAlphaComponent(0.15).setFill()
            cg.fillEllipse(in: rect.insetBy(dx: 4, dy: 4))

            // Texte centré
            let textSize = (text as NSString).size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width  - textSize.width)  / 2,
                y: (size.height - textSize.height) / 2,
                width:  textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attrs)
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

    /// Buckets de diamètre pour limiter le nombre d'images de cluster :
    /// 44, 46, 48, …, 58 (8 valeurs discrètes au lieu de 300+).
    private static func clusterBucket(for count: Int) -> CGFloat {
        let base: CGFloat = 44
        let increment = min(CGFloat(count) * 2, 14)
        let rounded = (increment / 2).rounded() * 2
        return base + rounded
    }
}
