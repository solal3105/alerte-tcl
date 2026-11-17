import SwiftUI
import Shared

// MARK: - Intro : les pages de la prévision Vélo'v
//
// Trois illustrations animées, une par page (`DESIGN.md`, « Pages de la prévision Vélo'v »). Elles
// dessinent la démonstration du module partagé (`VelovForecastDemo`) avec les vraies briques de la fiche
// et de la carte : graphique, curseur, marqueurs, panneau du curseur.
// Aucun texte n'est écrit ici, tout vient du module partagé. Chaque animation repart de zéro quand sa
// page passe devant, tourne en boucle tant qu'elle y reste et ne bat plus ailleurs ; avec « Réduire les
// animations », la page montre son image la plus parlante.

// MARK: - La démonstration

/// La démonstration, lue une fois pour toutes : les marqueurs, les lectures de la fiche et les panneaux
/// de la carte des 97 échéances sont prêts avant que les animations ne tournent, qui n'ont plus qu'à
/// les choisir.
private enum IntroVelovDemo {
    static let demo = VelovForecastDemo.shared
    static let filter = demo.SHEET_FILTER
    static let sheet = demo.sheet
    static let panel = sheet.panel(filter: filter)
    static let lastStep = VelovForecast.companion.STEP_COUNT
    static let tour: [Int32] = demo.TOUR.map { $0.int32Value }
    static let pins = demo.pins

    private static let steps = 0...Int(lastStep)

    /// Les marqueurs des stations à chaque échéance, dans l'ordre de `pins`.
    static let markers: [[VelovMapMarker]] = steps.map { step in
        IntroVelovDemo.demo.markers(step: Int32(step), filter: IntroVelovDemo.filter).map {
            VelovMapMarker(forecast: $0, filter: IntroVelovDemo.filter)
        }
    }

    /// Ce que la fiche de la station écrit à chaque échéance.
    static let readouts: [VelovForecastReadout] = steps.map {
        IntroVelovDemo.sheet.readout(filter: IntroVelovDemo.filter, step: Int32($0))
    }

    /// Le panneau du curseur de la carte à chaque échéance.
    static let mapPanels: [VelovForecastMapPanel] = steps.map {
        VelovForecastMapPanel.companion.at(originEpochMs: IntroVelovDemo.demo.ORIGIN_EPOCH_MS, step: Int32($0))
    }

    /// La place d'une échéance, fractions comprises, sur l'axe des heures : de 0 à 1.
    static func position(_ step: Double) -> Double { step / Double(lastStep) }

    /// L'échéance entière la plus proche, pour lire les listes ci-dessus.
    static func rank(_ step: Double) -> Int { min(max(Int(step.rounded()), 0), Int(lastStep)) }
}

// MARK: - Le temps

/// Les courbes de temps des illustrations.
private enum IntroMotion {
    /// Avancement de 0 à 1 de `time` entre `start` et `end`.
    static func progress(_ time: Double, from start: Double, to end: Double) -> Double {
        min(max((time - start) / (end - start), 0), 1)
    }

    /// Départ et arrivée en douceur.
    static func ease(_ share: Double) -> Double {
        let bounded = min(max(share, 0), 1)
        return bounded * bounded * (3 - 2 * bounded)
    }
}

/// L'horloge d'une illustration : les secondes écoulées depuis que sa page est passée devant, en boucle
/// sur `period`. Elle ne bat que tant que la page est devant et que les animations ne sont pas réduites ;
/// sinon elle reste sur l'instant `still`, l'image la plus parlante.
private struct IntroClock<Content: View>: View {
    let isCurrent: Bool
    let period: Double
    let still: Double
    private let content: (Double) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// L'instant où la page est passée devant ; nil tant que l'horloge ne bat pas.
    @State private var start: Date?

    init(isCurrent: Bool, period: Double, still: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.isCurrent = isCurrent
        self.period = period
        self.still = still
        self.content = content
    }

    private var isRunning: Bool { isCurrent && !reduceMotion }

    var body: some View {
        TimelineView(.animation(paused: !isRunning)) { context in
            content(time(at: context.date))
        }
        // Chaque image est calculée pour son instant : une animation venue d'au-dessus (le bouton
        // « Suivant ») ne doit pas la fondre avec la précédente. Les animations posées dans
        // l'illustration (chiffres, marqueurs) s'appliquent toujours.
        .transaction { $0.animation = nil }
        .onChange(of: isRunning, initial: true) { _, running in
            start = running ? .now : nil
        }
    }

    private func time(at date: Date) -> Double {
        guard isRunning else { return still }
        guard let start else { return 0 }
        return max(0, date.timeIntervalSince(start)).truncatingRemainder(dividingBy: period)
    }
}

/// Où en est une tournée à un instant donné.
private struct IntroTourPlace {
    /// L'échéance sous le pouce, fractions comprises pendant un trajet.
    let step: Double
    /// Le rang du dernier arrêt atteint.
    let stop: Int
    /// Les secondes passées depuis l'arrivée à cet arrêt, trajet suivant compris.
    let sinceArrival: Double
    /// L'avancement du trajet vers l'arrêt suivant, de 0 (à l'arrêt) à 1, adouci.
    let travel: Double
}

/// La tournée d'un curseur qui avance seul : il reste `hold` secondes sur chaque arrêt de `stops`, puis
/// glisse en `travel` secondes jusqu'au suivant ; après le dernier, il revient au premier quand
/// `loopsBack`, sinon il y reste.
private struct IntroTour {
    let stops: [Int32]
    let hold: Double
    let travel: Double
    var loopsBack = true

    var duration: Double {
        Double(stops.count) * hold + Double(loopsBack ? stops.count : stops.count - 1) * travel
    }

    /// Le milieu de l'arrêt de rang `stop` : l'image fixe montrée quand les animations sont réduites.
    func stillTime(at stop: Int) -> Double { Double(stop) * (hold + travel) + hold / 2 }

    func at(_ time: Double) -> IntroTourPlace {
        let leg = hold + travel
        let elapsed = max(0, time)
        let stop = min(Int(elapsed / leg), stops.count - 1)
        let since = elapsed - Double(stop) * leg
        let next = stop + 1 < stops.count ? stop + 1 : (loopsBack ? 0 : stop)
        let travelled = next == stop ? 0 : IntroMotion.ease((since - hold) / travel)
        let from = Double(stops[stop])
        let to = Double(stops[next])
        return IntroTourPlace(step: from + (to - from) * travelled, stop: stop, sinceArrival: since, travel: travelled)
    }
}

// MARK: - La scène

/// Les mesures de la scène, les mêmes pour toutes les pages : les illustrations s'y dessinent à taille
/// fixe, puis la scène entière est mise à l'échelle de la place laissée par la page.
private enum IntroStageMetrics {
    static let size = CGSize(width: 320, height: 340)
    static let cornerRadius: CGFloat = 30
    static let padding: CGFloat = 18
    /// Agrandissement permis sur les grands écrans.
    static let maxScale: CGFloat = 1.12
}

/// Ce qui porte une illustration : une carte de verre, ou le plan de démonstration qui la remplit.
private enum IntroGround {
    case glass
    case map(IntroMapLayout)
}

/// La scène d'une illustration : une carte arrondie à l'ombre douce, réduite pour tenir sur un petit
/// écran. Elle n'est ni touchable (le balayage des pages passe à travers) ni lue par VoiceOver : le titre
/// et le texte de la page portent le sens.
private struct IntroStage<Content: View>: View {
    let ground: IntroGround
    private let content: Content

    init(_ ground: IntroGround, @ViewBuilder content: () -> Content) {
        self.ground = ground
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let size = IntroStageMetrics.size
            let scale = max(0.01, min(IntroStageMetrics.maxScale, geometry.size.width / size.width, geometry.size.height / size.height))
            card
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // La scène est dessinée à taille fixe : son texte ne grandit pas avec les réglages.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var card: some View {
        let size = IntroStageMetrics.size
        let shape = RoundedRectangle(cornerRadius: IntroStageMetrics.cornerRadius, style: .continuous)
        switch ground {
        case .glass:
            content
                .padding(IntroStageMetrics.padding)
                .frame(width: size.width, height: size.height)
                .glassSurface(shape)
                .shadow(color: .black.opacity(0.12), radius: 26, x: 0, y: 14)
        case .map(let layout):
            content
                .frame(width: size.width, height: size.height)
                .background { IntroMapBackdrop(layout: layout) }
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.appNeutralBorder.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 26, x: 0, y: 14)
        }
    }
}

// MARK: - Le plan de démonstration

/// Où tombe le plan dans la scène : le carré des positions des stations (0 à 1) posé sur `frame`, qui
/// peut déborder de la scène. Le dessin du plan et les marqueurs suivent le même cadre.
private struct IntroMapLayout {
    let frame: CGRect

    /// Tout le plan, au-dessus du panneau du curseur.
    static let overview = IntroMapLayout(frame: CGRect(x: 26, y: 24, width: 268, height: 166))

    /// Rapport à la vue d'ensemble : les rues et les fleuves s'élargissent d'autant.
    var zoom: CGFloat { frame.width / Self.overview.frame.width }

    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(x: frame.minX + CGFloat(x) * frame.width, y: frame.minY + CGFloat(y) * frame.height)
    }

    func point(_ pin: VelovForecastDemoPin) -> CGPoint { point(x: pin.x, y: pin.y) }
}

/// Le plan dessiné : le sol, des rues, la Saône et le Rhône, puis les grandes avenues qui les
/// franchissent comme des ponts. Il ne dépend que de son cadre : il est dessiné une fois, sous
/// l'horloge de l'illustration.
private struct IntroMapBackdrop: View {
    let layout: IntroMapLayout

    private typealias Line = [(x: Double, y: Double)]

    /// Des deux fleuves, la Saône à l'ouest et le Rhône à l'est, assez loin des stations pour ne passer
    /// sous aucun marqueur.
    private static let saone: Line = [(0.06, -0.5), (0.14, 0.05), (0.33, 0.42), (0.345, 0.85), (0.42, 2.2)]
    private static let rhone: Line = [(1.08, -0.5), (0.99, 0.2), (0.94, 0.46), (0.70, 0.80), (0.58, 2.2)]
    /// Les petites rues, sous l'eau.
    private static let streets: [Line] = [
        [(-1, 0.04), (2, -0.02)], [(-1, 0.50), (2, 0.46)], [(-1, 0.92), (2, 0.86)], [(-1, 1.30), (2, 1.24)],
        [(0.08, -1), (0.0, 2.2)], [(0.24, -1), (0.20, 2.2)], [(0.42, -1), (0.38, 2.2)],
        [(0.80, -1), (0.72, 2.2)], [(1.02, -1), (0.92, 2.2)], [(-0.6, 1.6), (1.6, -0.6)],
    ]
    /// Les grandes avenues, par-dessus l'eau.
    private static let avenues: [Line] = [
        [(-1, 0.33), (2, 0.22)], [(-1, 0.70), (2, 0.60)], [(0.62, -1), (0.50, 2.2)],
    ]

    var body: some View {
        Canvas { context, size in
            let zoom = layout.zoom
            func path(_ line: Line) -> Path {
                Self.smoothPath(line.map { layout.point(x: $0.x, y: $0.y) })
            }
            func stroke(_ lines: [Line], color: Color, width: CGFloat) {
                for line in lines {
                    context.stroke(path(line), with: .color(color), style: StrokeStyle(lineWidth: width * zoom, lineCap: .round, lineJoin: .round))
                }
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.appIntroMapLand))
            stroke(Self.streets, color: .appIntroMapStreet, width: 3.5)
            stroke([Self.saone], color: .appIntroMapWater, width: 16)
            stroke([Self.rhone], color: .appIntroMapWater, width: 22)
            stroke(Self.avenues, color: .appIntroMapStreet, width: 7)
        }
    }

    /// Une ligne adoucie : chaque point intérieur tire la courbe vers lui, qui passe par les milieux.
    private static func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: first)
        if points.count > 2 {
            for rank in 1..<(points.count - 1) {
                let control = points[rank]
                let next = points[rank + 1]
                path.addQuadCurve(to: CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2), control: control)
            }
        }
        path.addLine(to: last)
        return path
    }
}

/// Le marqueur d'une station, le vrai : quand son texte ou sa couleur change, le nouveau arrive en
/// ressort, et s'élargit quand une fourchette remplace un nombre.
private struct IntroVelovMarker: View {
    let marker: VelovMapMarker

    private var look: String { "\(marker.label)-\(marker.availability.name)" }

    var body: some View {
        ZStack {
            VelovMarker(marker: marker, compact: false)
                .id(look)
                .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.55), value: look)
    }
}

/// Les marqueurs des stations de démonstration, chacun à sa place sur le plan.
private struct IntroVelovPins: View {
    let layout: IntroMapLayout
    let markers: [VelovMapMarker]

    var body: some View {
        ZStack {
            ForEach(IntroVelovDemo.pins.indices, id: \.self) { rank in
                IntroVelovMarker(marker: markers[rank])
                    .position(layout.point(IntroVelovDemo.pins[rank]))
            }
        }
    }
}

// MARK: - 2. Carte

/// Le plan de démonstration et ses huit stations, le panneau du curseur en bas : un doigt pose le pouce
/// et le fait glisser d'un arrêt de la tournée à l'autre, et les marqueurs changent de chiffre et de
/// couleur sur son passage, jusqu'au retour à « Maintenant ».
struct IntroVelovMap: View {
    let isCurrent: Bool

    private static let tour = IntroTour(stops: IntroVelovDemo.tour, hold: 0.8, travel: 0.8)

    var body: some View {
        IntroStage(.map(.overview)) {
            // Image fixe : 9 h 15, les quartiers d'habitation vides, les bureaux pleins.
            IntroClock(isCurrent: isCurrent, period: Self.tour.duration, still: Self.tour.stillTime(at: 2)) { time in
                let place = Self.tour.at(time)
                let end = Self.tour.duration
                IntroVelovMapFrame(
                    place: place,
                    finger: IntroMotion.progress(time, from: 0.2, to: 0.5) * (1 - IntroMotion.progress(time, from: end - 0.5, to: end - 0.2)),
                    pressed: place.sinceArrival > Self.tour.hold - 0.15
                )
            }
        }
    }
}

private struct IntroVelovMapFrame: View {
    let place: IntroTourPlace
    /// Présence du doigt, de 0 à 1.
    let finger: Double
    /// Vrai quand le doigt appuie pour faire glisser le pouce.
    let pressed: Bool

    var body: some View {
        let rank = IntroVelovDemo.rank(place.step)
        let panel = IntroVelovDemo.mapPanels[rank]
        let position = IntroVelovDemo.position(place.step)
        ZStack(alignment: .bottom) {
            IntroVelovPins(layout: .overview, markers: IntroVelovDemo.markers[rank])
            VelovForecastTimeCard(panel: panel) {
                VelovForecastSliderFace(position: position, trackLevels: nil, ticks: panel.ticks)
                    .overlay {
                        IntroFinger(position: position, pressed: pressed)
                            .opacity(finger)
                    }
            }
            .contentTransition(.numericText())
            .animation(.snappy, value: rank)
            .padding(10)
        }
    }
}

/// Le rond d'un doigt posé sur le pouce du curseur, qui s'enfonce un peu quand il appuie.
private struct IntroFinger: View {
    let position: Double
    let pressed: Bool

    private static let side: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.primary.opacity(0.12))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.28), lineWidth: 1.5))
                .frame(width: Self.side, height: Self.side)
                .scaleEffect(pressed ? 0.86 : 1.08)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
                .position(x: VelovForecastAxis(width: geometry.size.width).x(position), y: VelovForecastSliderFace.trackHeight / 2)
        }
        // Le doigt suit le pouce image par image : l'animation des chiffres du panneau ne doit pas le retenir.
        .transaction { $0.animation = nil }
    }
}

// MARK: - 3. Fourchette

/// Le graphique de la fiche se dessine de gauche à droite ; puis son curseur le parcourt, une accolade
/// marque à chaque arrêt la fourchette sous le curseur, et la lecture de la fiche l'écrit en grand au-dessus,
/// avec « 8 fois sur 10 ».
struct IntroVelovRange: View {
    let isCurrent: Bool

    private static let reveal = 1.6
    private static let tail = 0.6
    private static let tour = IntroTour(stops: Array(IntroVelovDemo.tour.dropFirst()), hold: 1.0, travel: 0.7, loopsBack: false)
    private static var period: Double { reveal + tour.duration + tail }

    var body: some View {
        IntroStage(.glass) {
            // Image fixe : l'avant-dernier arrêt, le soir, une fourchette déjà large.
            IntroClock(isCurrent: isCurrent, period: Self.period, still: Self.reveal + Self.tour.stillTime(at: Self.tour.stops.count - 2)) { time in
                IntroVelovRangeFrame(
                    drawn: IntroMotion.ease(IntroMotion.progress(time, from: 0, to: Self.reveal)),
                    cursor: IntroMotion.progress(time, from: Self.reveal - 0.25, to: Self.reveal + 0.25),
                    place: Self.tour.at(time - Self.reveal),
                    shown: 1 - IntroMotion.progress(time, from: Self.period - Self.tail, to: Self.period)
                )
            }
        }
    }
}

private struct IntroVelovRangeFrame: View {
    /// Part du graphique déjà dessinée, de gauche à droite.
    let drawn: Double
    /// Arrivée du curseur et de la lecture, de 0 à 1.
    let cursor: Double
    let place: IntroTourPlace
    /// Le tout s'efface à la fin de la boucle, avant de se redessiner.
    let shown: Double

    var body: some View {
        let rank = IntroVelovDemo.rank(place.step)
        VStack(alignment: .leading, spacing: 12) {
            IntroVelovReading(readout: IntroVelovDemo.readouts[rank])
                .opacity(cursor)
            VelovForecastChart(panel: IntroVelovDemo.panel, step: cursor > 0 ? Int32(rank) : nil)
                .overlay { IntroRangeBrace(step: rank, extent: braceExtent) }
                .mask { IntroWipe(progress: drawn) }
        }
        .frame(maxHeight: .infinity)
        .opacity(shown)
        .animation(.snappy, value: rank)
    }

    /// L'accolade se déploie depuis son milieu à chaque arrêt et se replie dès que le curseur repart.
    private var braceExtent: Double {
        guard cursor >= 1 else { return 0 }
        if place.travel > 0 { return 1 - IntroMotion.ease(place.travel * 3) }
        return IntroMotion.ease(place.sinceArrival / 0.35)
    }
}

/// La lecture de la fiche, en grand : l'heure, la fourchette, et ce qu'elle vaut.
private struct IntroVelovReading: View {
    let readout: VelovForecastReadout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(readout.time)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(readout.count)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            // La ligne garde sa place à « Maintenant », qui n'a pas de fourchette.
            Text(readout.reliability ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.appAccent.opacity(0.14), in: Capsule())
                .opacity(readout.reliability == nil ? 0 : 1)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .monospacedDigit()
        .contentTransition(.numericText())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// L'accolade posée à côté du repère du graphique, de la borne haute à la borne basse de la fourchette
/// sous le curseur ; à gauche du repère quand il touche le bord droit.
private struct IntroRangeBrace: View {
    let step: Int
    /// Part déployée, de 0 à 1, depuis le milieu.
    let extent: Double

    private static let gap: CGFloat = 9
    private static let depth: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let panel = IntroVelovDemo.panel
            let points = panel.points
            guard extent > 0, points.indices.contains(step) else { return }
            let scale = VelovForecastChartScale(size: size, panel: panel)
            let point = points[step]
            let cursorX = scale.axis.x(point.position)
            let direction: CGFloat = cursorX + Self.gap + 3 * Self.depth > size.width ? -1 : 1
            let brace = Self.brace(x: cursorX + direction * Self.gap, top: scale.y(point.high), bottom: scale.y(point.low), direction: direction)
            context.stroke(
                brace.trimmedPath(from: CGFloat(0.5 - extent / 2), to: CGFloat(0.5 + extent / 2)),
                with: .color(.appAccent),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// Une accolade verticale de `top` à `bottom`, sa pointe tournée vers `direction` (1 à droite, -1 à gauche).
    private static func brace(x: CGFloat, top: CGFloat, bottom: CGFloat, direction: CGFloat) -> Path {
        let depth = min(Self.depth, max(0, bottom - top) / 4) * direction
        let middle = (top + bottom) / 2
        var path = Path()
        path.move(to: CGPoint(x: x, y: top))
        path.addQuadCurve(to: CGPoint(x: x + depth, y: top + abs(depth)), control: CGPoint(x: x + depth, y: top))
        path.addLine(to: CGPoint(x: x + depth, y: middle - abs(depth)))
        path.addQuadCurve(to: CGPoint(x: x + 2 * depth, y: middle), control: CGPoint(x: x + depth, y: middle))
        path.addQuadCurve(to: CGPoint(x: x + depth, y: middle + abs(depth)), control: CGPoint(x: x + depth, y: middle))
        path.addLine(to: CGPoint(x: x + depth, y: bottom - abs(depth)))
        path.addQuadCurve(to: CGPoint(x: x, y: bottom), control: CGPoint(x: x + depth, y: bottom))
        return path
    }
}

/// Le masque qui découvre le graphique de gauche à droite, au bord adouci.
private struct IntroWipe: View {
    let progress: Double

    private static let softEdge = 0.1

    var body: some View {
        let edge = progress * (1 + Self.softEdge)
        LinearGradient(
            stops: [
                .init(color: .black, location: CGFloat(min(max(edge - Self.softEdge, 0), 1))),
                .init(color: .clear, location: CGFloat(min(max(edge, 0), 1))),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - 4. Chances

/// Une jauge ronde dit la chance d'en trouver au moins un, en pourcentage et en mot, à la couleur du
/// palier ; dessous, la piste colorée du curseur de la fiche, dont le pouce avance. La période à risque
/// s'écrit dès que le pouce entre dans le rouge.
struct IntroVelovChance: View {
    let isCurrent: Bool

    private static let tour = IntroTour(stops: Array(IntroVelovDemo.tour.dropFirst()), hold: 1.0, travel: 0.8)
    /// Le premier arrêt où la station risque d'être vide.
    private static let firstRedStop = tour.stops.firstIndex {
        IntroVelovChance.isUnlikely(IntroVelovDemo.readouts[Int($0)])
    } ?? tour.stops.count

    var body: some View {
        IntroStage(.glass) {
            // Image fixe : le pouce dans le rouge, la période à risque écrite.
            IntroClock(isCurrent: isCurrent, period: Self.tour.duration, still: Self.tour.stillTime(at: min(Self.firstRedStop, Self.tour.stops.count - 1))) { time in
                let place = Self.tour.at(time)
                let readout = IntroVelovDemo.readouts[IntroVelovDemo.rank(place.step)]
                IntroVelovChanceFrame(
                    place: place,
                    readout: readout,
                    risk: place.stop >= Self.firstRedStop || Self.isUnlikely(readout)
                )
            }
        }
    }

    private static func isUnlikely(_ readout: VelovForecastReadout) -> Bool {
        readout.chance?.level == VelovChanceLevel.unlikely
    }
}

private struct IntroVelovChanceFrame: View {
    let place: IntroTourPlace
    let readout: VelovForecastReadout
    /// Vrai une fois que le pouce est entré dans le rouge.
    let risk: Bool

    var body: some View {
        let panel = IntroVelovDemo.panel
        VStack(spacing: 14) {
            Text(readout.time)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let chance = readout.chance {
                IntroChanceGauge(chance: chance)
            }
            VStack(alignment: .leading, spacing: 12) {
                VelovForecastSliderFace(position: IntroVelovDemo.position(place.step), trackLevels: panel.trackLevels, ticks: panel.ticks)
                VelovForecastRiskLine(text: panel.risk ?? " ")
                    .opacity(risk ? 1 : 0)
                    .offset(y: risk ? 0 : 8)
            }
        }
        .frame(maxHeight: .infinity)
        .monospacedDigit()
        .contentTransition(.numericText())
        .animation(.snappy, value: readout.step)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: risk)
    }
}

/// La jauge des chances : un anneau rempli au pourcentage, à la couleur du palier, le pourcentage et
/// son mot au centre.
private struct IntroChanceGauge: View {
    let chance: VelovChance

    private static let side: CGFloat = 150
    private static let ringWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appNeutralFill, lineWidth: Self.ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(chance.percent) / 100)
                .stroke(chance.level.color, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(chance.text)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(chance.level.label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(chance.level.color)
        }
        .padding(Self.ringWidth / 2)
        .frame(width: Self.side, height: Self.side)
        .animation(.smooth(duration: 0.4), value: chance.percent)
    }
}
