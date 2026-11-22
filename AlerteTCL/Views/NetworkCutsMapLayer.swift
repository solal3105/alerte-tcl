import SwiftUI
import MapKit
import Shared

// MARK: - Coupures du réseau sur la carte Transport
//
// Dessine ce que rend `NetworkCuts.mapCuts` (module partagé) : un fond qui efface la couleur de la
// ligne, puis des points gris (coupé) ou des tirets à sa couleur (plus tard aujourd'hui), et une
// pastille par coupure. Les tracés sont posés au-dessus des lignes (`.aboveLabels`), qui sont ajoutées
// et retirées au gré des réglages. Règles dans DESIGN.md (« Coupures du réseau »).

/// Un trait d'une coupure : le fond, les points ou les tirets.
final class CutPolyline: MKPolyline {
    enum Role { case casing, dots, dashes }
    var role: Role = .dots
    var color: UIColor = .gray
}

/// La pastille d'une coupure, placée au milieu du plus long tronçon coupé.
final class CutAnnotation: NSObject, MKAnnotation {
    let mapCut: NetworkCuts.MapCut
    let coordinate: CLLocationCoordinate2D

    init(mapCut: NetworkCuts.MapCut, coordinate: CLLocationCoordinate2D) {
        self.mapCut = mapCut
        self.coordinate = coordinate
    }
}

final class CutAnnotationView: MKAnnotationView {
    static let identifier = "cut"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        displayPriority = .required
        zPriority = .max
        collisionMode = .none
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Appelée par le délégué de la carte, toujours sur le fil principal.
    func apply(_ mapCut: NetworkCuts.MapCut) {
        let pastille = CutPastille(line: mapCut.line, soon: mapCut.style == .soon, label: mapCut.label)
            .environment(\.colorScheme, traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        let scale = traitCollection.displayScale
        image = MainActor.assumeIsolated {
            let renderer = ImageRenderer(content: pastille)
            renderer.scale = scale
            return renderer.uiImage
        }
        // La coordonnée tombe au centre du badge, en haut de l'image.
        centerOffset = CGPoint(x: 0, y: (image?.size.height ?? 0) / 2 - Self.badgeCenterFromTop)
        accessibilityLabel = "\(NetworkCuts.shared.subject(cut: mapCut.cut)), \(mapCut.label)"
    }

    /// Marge de la pastille et moitié de la rangée du badge.
    private static let badgeCenterFromTop: CGFloat = 19
}

final class NetworkCutsMapLayer {
    private struct Drawn {
        let overlays: [CutPolyline]
        let annotation: CutAnnotation?
    }

    /// Une coupure dessinée, par identité et apparence : un changement de style ou d'étiquette la redessine.
    private var drawn: [String: Drawn] = [:]

    /// Pose sur la carte les coupures [cuts] (déjà filtrées pour le zoom), en ne touchant qu'à ce qui change.
    /// [lineTraces] : tracé de la ligne, pour une ligne entière coupée que le fichier ne dessine pas.
    func sync(_ cuts: [NetworkCuts.MapCut], lineTraces: (String) -> [[CLLocationCoordinate2D]], on mapView: MKMapView) {
        let wanted = Dictionary(cuts.map { ("\($0.cut.id)|\($0.style)|\($0.label)", $0) }, uniquingKeysWith: { first, _ in first })
        for key in Set(drawn.keys).subtracting(wanted.keys) {
            guard let old = drawn.removeValue(forKey: key) else { continue }
            mapView.removeOverlays(old.overlays)
            if let annotation = old.annotation { mapView.removeAnnotation(annotation) }
        }
        for (key, mapCut) in wanted where drawn[key] == nil {
            let traces = mapCut.traces.isEmpty
                ? lineTraces(mapCut.line)
                : mapCut.traces.map { $0.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } }
            let overlays = Self.polylines(for: mapCut, traces: traces)
            mapView.addOverlays(overlays, level: .aboveLabels)
            let annotation = Self.anchor(of: mapCut, traces: traces).map { CutAnnotation(mapCut: mapCut, coordinate: $0) }
            if let annotation { mapView.addAnnotation(annotation) }
            drawn[key] = Drawn(overlays: overlays, annotation: annotation)
        }
    }

    func renderer(for line: CutPolyline) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: line)
        renderer.strokeColor = line.color
        renderer.lineJoin = .round
        switch line.role {
        case .casing:
            renderer.lineWidth = MapStyle.shared.CUT_CASING_WIDTH
            renderer.lineCap = .round
        case .dots:
            renderer.lineWidth = MapStyle.shared.CUT_DOT_WIDTH
            renderer.lineCap = .round
            renderer.lineDashPattern = MapStyle.shared.CUT_DOT_PATTERN.map { NSNumber(value: $0.doubleValue) }
        case .dashes:
            renderer.lineWidth = MapStyle.shared.SOON_DASH_WIDTH
            renderer.lineCap = .butt
            renderer.lineDashPattern = MapStyle.shared.SOON_DASH_PATTERN.map { NSNumber(value: $0.doubleValue) }
        }
        return renderer
    }

    private static func polylines(for mapCut: NetworkCuts.MapCut, traces: [[CLLocationCoordinate2D]]) -> [CutPolyline] {
        let cut = mapCut.style == .cut
        return traces.filter { $0.count >= 2 }.flatMap { coords -> [CutPolyline] in
            [
                polyline(coords, role: .casing, color: UIColor(Color.appCutCasing)),
                polyline(coords, role: cut ? .dots : .dashes, color: cut ? UIColor(Color.appCutTrace) : UIColor(LineColorHelper.backgroundColor(for: mapCut.line)))
            ]
        }
    }

    private static func polyline(_ coords: [CLLocationCoordinate2D], role: CutPolyline.Role, color: UIColor) -> CutPolyline {
        var coords = coords
        let line = CutPolyline(coordinates: &coords, count: coords.count)
        line.role = role
        line.color = color
        return line
    }

    /// La pastille : le point donné par le fichier, sinon le milieu du plus long tracé de la ligne.
    private static func anchor(of mapCut: NetworkCuts.MapCut, traces: [[CLLocationCoordinate2D]]) -> CLLocationCoordinate2D? {
        if let anchor = mapCut.anchor { return CLLocationCoordinate2D(latitude: anchor.latitude, longitude: anchor.longitude) }
        guard let longest = traces.max(by: { $0.count < $1.count }),
              let middle = NetworkCuts.shared.midpoint(points: longest.map { LatLng(latitude: $0.latitude, longitude: $0.longitude) })
        else { return nil }
        return CLLocationCoordinate2D(latitude: middle.latitude, longitude: middle.longitude)
    }
}
