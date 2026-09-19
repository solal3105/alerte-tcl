import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// Un chantier à dessiner sur la carte : ses contours, son centre, son avancement et son importance.
struct WorksMapShape {
    let rings: [[CLLocationCoordinate2D]]
    let centroid: CLLocationCoordinate2D
    /// Avancement de 0 à 100, qui donne la couleur (même barème que la carte de l'application).
    let progress: Double
    /// 1 très perturbant, 2 perturbant : un point rouge ou orange sur le marqueur.
    let importance: Int
}

/// Image de carte pour le widget « Travaux autour de moi » : la carte du système autour de la
/// position, les chantiers dessinés comme dans l'application (contour et remplissage à la couleur
/// de l'avancement, marqueur au centre), la position en point bleu.
enum WorksMapSnapshot {
    /// Centre de Lyon (place Bellecour), quand la position n'est pas connue.
    static let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)

    static func render(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        shapes: [WorksMapShape],
        size: CGSize,
        scale: CGFloat,
        dark: Bool,
        showUser: Bool
    ) async -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let options = MKMapSnapshotter.Options()
        // La zone visible couvre le rayon choisi, avec une marge pour que les chantiers en bordure entrent.
        let ratio = size.width / size.height
        let metersHigh = radiusMeters * 2.3
        options.region = MKCoordinateRegion(center: center, latitudinalMeters: metersHigh, longitudinalMeters: metersHigh * ratio)
        options.size = size
        options.scale = scale
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false
        options.traitCollection = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)

        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await MKMapSnapshotter(options: options).start()
        } catch {
            AppLogger.debug("Carte des chantiers : capture impossible (\(error.localizedDescription))", category: .widget)
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: size, format: format(scale: scale))
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let cg = context.cgContext
            for shape in shapes {
                let color = UIColor(WidgetTheme.worksProgress(percent: shape.progress))
                for ring in shape.rings where ring.count >= 2 {
                    let path = UIBezierPath()
                    for (index, coordinate) in ring.enumerated() {
                        let point = snapshot.point(for: coordinate)
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.close()
                    color.withAlphaComponent(0.30).setFill()
                    path.fill()
                    color.setStroke()
                    path.lineWidth = 2
                    path.stroke()
                }
                drawMarker(at: snapshot.point(for: shape.centroid), color: color, importance: shape.importance, in: cg)
            }
            if showUser {
                drawUser(at: snapshot.point(for: center), in: cg)
            }
        }
    }

    private static func format(scale: CGFloat) -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return format
    }

    /// Disque à la couleur de l'avancement avec un marteau, et un point d'importance en haut à droite.
    private static func drawMarker(at point: CGPoint, color: UIColor, importance: Int, in context: CGContext) {
        let radius: CGFloat = 11
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        color.setFill()
        context.fillEllipse(in: rect)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        UIColor.white.setStroke()
        context.setLineWidth(2)
        context.strokeEllipse(in: rect)
        if let symbol = UIImage(systemName: "hammer.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let symbolRect = CGRect(x: point.x - symbol.size.width / 2, y: point.y - symbol.size.height / 2, width: symbol.size.width, height: symbol.size.height)
            symbol.draw(in: symbolRect)
        }
        guard importance == 1 || importance == 2 else { return }
        let badge = CGRect(x: point.x + radius - 8, y: point.y - radius - 1, width: 9, height: 9)
        UIColor(importance == 1 ? WidgetTheme.error : WidgetTheme.warning).setFill()
        context.fillEllipse(in: badge)
        UIColor.white.setStroke()
        context.setLineWidth(1.5)
        context.strokeEllipse(in: badge)
    }

    /// Point de position : halo, disque blanc, cœur à l'accent.
    private static func drawUser(at point: CGPoint, in context: CGContext) {
        let accent = UIColor(WidgetTheme.accent)
        accent.withAlphaComponent(0.2).setFill()
        context.fillEllipse(in: CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32))
        UIColor.white.setFill()
        context.fillEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
        accent.setFill()
        context.fillEllipse(in: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11))
    }
}
