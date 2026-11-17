import SwiftUI
import Shared

// MARK: - Prévision Vélo'v : graphique, curseur d'heure, bloc de la fiche et panneau de la carte
//
// Tout ce qui s'écrit vient du module partagé (`VelovForecastSheet`, `VelovForecastMapPanel`) : ces
// vues ne calculent que des positions à l'écran.

/// Axe des heures commun au graphique et au curseur : une position, de 0 (maintenant) à 1 (dans 24 h),
/// y tombe à la même abscisse. La marge laissée de chaque côté vaut le rayon du pouce du curseur, qui
/// ne déborde donc jamais du graphique.
struct VelovForecastAxis {
    static let inset: CGFloat = 14
    let width: CGFloat

    private var span: CGFloat { max(1, width - 2 * Self.inset) }

    func x(_ position: Double) -> CGFloat {
        Self.inset + CGFloat(position) * span
    }

    /// L'échéance la plus proche d'une abscisse, de 0 à `lastStep`.
    func step(at x: CGFloat, lastStep: Int32) -> Int32 {
        let position = min(max(Double((x - Self.inset) / span), 0), 1)
        return Int32((position * Double(lastStep)).rounded())
    }
}

extension View {
    /// Carte d'une fiche de station Vélo'v (état du moment, prévision, voisines).
    func velovForecastCard() -> some View {
        padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Graphique

/// Les échelles du graphique d'un panneau dans un cadre de taille donnée : l'axe des heures et la
/// hauteur d'un compte, de 0 au haut de l'échelle. Les deux couches du graphique les partagent, comme
/// l'accolade que l'intro pose sur la fourchette.
struct VelovForecastChartScale {
    static let topInset: CGFloat = 10
    private static let bottomInset: CGFloat = 6

    let axis: VelovForecastAxis
    let plotHeight: CGFloat
    private let scaleMax: Double

    init(size: CGSize, panel: VelovForecastPanel) {
        axis = VelovForecastAxis(width: size.width)
        plotHeight = size.height - Self.topInset - Self.bottomInset
        scaleMax = Double(panel.scaleMax)
    }

    func y(_ value: Double) -> CGFloat {
        Self.topInset + plotHeight * CGFloat(1 - value / scaleMax)
    }

    func line(_ through: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(through)
        return path
    }
}

/// Graphique des 24 heures d'une station, à l'accent : la valeur la plus probable (trait), la
/// fourchette 10-90 (bande claire) et la fourchette 30-70 (bande soutenue), de 0 au haut de l'échelle,
/// avec le trait de minuit et le repère de l'échéance choisie. Les courbes ne dépendent que du panneau
/// et ne sont pas redessinées quand le curseur glisse : seul le repère, en surimpression, suit.
struct VelovForecastChart: View {
    let panel: VelovForecastPanel
    /// L'échéance repérée ; nil pour les seules courbes (l'intro, avant que le curseur n'arrive).
    let step: Int32?
    /// Hauteur du graphique : celle de la fiche, ou moins dans une illustration de l'intro.
    var frameHeight: CGFloat = VelovForecastChart.height

    static let height: CGFloat = 190

    var body: some View {
        VelovForecastChartCurves(panel: panel)
            .equatable()
            .overlay {
                if let step { VelovForecastChartCursor(panel: panel, step: step) }
            }
            .frame(height: frameHeight)
            // Les repères sont tenus par la géométrie : leur texte grandit avec les réglages, jusqu'à un plafond.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(VelovTexts.shared.CHART_LABEL)
    }
}

/// Les courbes, les bandes, l'échelle et minuit : une couche qui ne change qu'avec le panneau (le
/// filtre ou un nouveau relevé), jamais avec l'échéance.
private struct VelovForecastChartCurves: View, Equatable {
    let panel: VelovForecastPanel

    private static let labelGap: CGFloat = 5

    /// Le module partagé garde un panneau par filtre : le même objet, ce sont les mêmes courbes.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.panel === rhs.panel }

    var body: some View {
        Canvas { context, size in
            let scale = VelovForecastChartScale(size: size, panel: panel)
            let axis = scale.axis
            let points = panel.points
            func curve(_ value: KeyPath<VelovForecastChartPoint, Double>) -> [CGPoint] {
                points.map { CGPoint(x: axis.x($0.position), y: scale.y($0[keyPath: value])) }
            }
            func band(_ lower: KeyPath<VelovForecastChartPoint, Double>, _ upper: KeyPath<VelovForecastChartPoint, Double>) -> Path {
                var path = scale.line(curve(upper) + curve(lower).reversed())
                path.closeSubpath()
                return path
            }

            // Le zéro et le haut de l'échelle, seul nombre écrit sur l'axe.
            for value in [0, Double(panel.scaleMax)] {
                let segment = scale.line([CGPoint(x: axis.x(0), y: scale.y(value)), CGPoint(x: axis.x(1), y: scale.y(value))])
                context.stroke(segment, with: .color(.appNeutralBorder), lineWidth: 1)
            }
            let labelY = VelovForecastChartScale.topInset + 2
            let scaleLabel = context.resolve(Text(verbatim: "\(panel.scaleMax)").font(.caption2).foregroundColor(.secondary))
            context.draw(scaleLabel, at: CGPoint(x: axis.x(1), y: labelY), anchor: .topTrailing)

            // Minuit : le nom du jour suit le trait, ou le précède quand il toucherait le nombre de l'échelle.
            if let midnight = panel.midnight {
                let midnightX = axis.x(midnight.position)
                let dashes = scale.line([
                    CGPoint(x: midnightX, y: VelovForecastChartScale.topInset),
                    CGPoint(x: midnightX, y: VelovForecastChartScale.topInset + scale.plotHeight),
                ])
                context.stroke(dashes, with: .color(.appNeutralBorder), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                let dayLabel = context.resolve(Text(midnight.label).font(.caption2).foregroundColor(.secondary))
                let lastFreeX = axis.x(1) - scaleLabel.measure(in: size).width - Self.labelGap
                let fitsAfter = midnightX + Self.labelGap + dayLabel.measure(in: size).width <= lastFreeX
                context.draw(
                    dayLabel,
                    at: CGPoint(x: fitsAfter ? midnightX + Self.labelGap : midnightX - Self.labelGap, y: labelY),
                    anchor: fitsAfter ? .topLeading : .topTrailing
                )
            }

            context.fill(band(\.low, \.high), with: .color(Color.appAccent.opacity(0.16)))
            context.fill(band(\.midLow, \.midHigh), with: .color(Color.appAccent.opacity(0.30)))
            context.stroke(scale.line(curve(\.median)), with: .color(.appAccent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Le repère de l'échéance, seule couche redessinée quand le curseur glisse : un trait qui descend
/// jusqu'au pouce du curseur, la fourchette large en gras et la valeur la plus probable en pastille.
private struct VelovForecastChartCursor: View {
    let panel: VelovForecastPanel
    let step: Int32

    private static let dotRadius: CGFloat = 5.5

    var body: some View {
        Canvas { context, size in
            let points = panel.points
            guard points.indices.contains(Int(step)) else { return }
            let scale = VelovForecastChartScale(size: size, panel: panel)
            let selected = points[Int(step)]
            let cursorX = scale.axis.x(selected.position)
            context.stroke(
                scale.line([CGPoint(x: cursorX, y: VelovForecastChartScale.topInset), CGPoint(x: cursorX, y: size.height)]),
                with: .color(.primary),
                lineWidth: 1.5
            )
            context.stroke(
                scale.line([CGPoint(x: cursorX, y: scale.y(selected.high)), CGPoint(x: cursorX, y: scale.y(selected.low))]),
                with: .color(.appAccent),
                style: StrokeStyle(lineWidth: 7, lineCap: .round)
            )
            let dot = Path(ellipseIn: CGRect(
                x: cursorX - Self.dotRadius, y: scale.y(selected.median) - Self.dotRadius,
                width: 2 * Self.dotRadius, height: 2 * Self.dotRadius
            ))
            context.fill(dot, with: .style(.background))
            context.stroke(dot, with: .color(.appAccent), lineWidth: 3)
        }
    }
}

// MARK: - Curseur d'heure

/// Curseur d'heure, le même sur la fiche d'une station et sur la carte : une échéance par quart
/// d'heure, de 0 (« Maintenant ») à la dernière, posées aux abscisses du graphique (`VelovForecastAxis`).
/// Quand il glisse, seuls le pouce (et, sur la carte, le remplissage de la piste) sont redessinés.
struct VelovForecastSlider: View {
    let step: Int32
    /// Palier de chaque échéance, qui colore la piste (fiche) ; nil pour une piste neutre remplie à
    /// l'accent jusqu'au pouce (carte).
    let trackLevels: [VelovChanceLevel]?
    /// Heures écrites sous la piste.
    let ticks: [VelovForecastTick]
    /// Ce que VoiceOver lit comme valeur : l'heure de l'échéance et, sur la fiche, son chiffre.
    let valueText: String
    let onSelect: (Int32) -> Void

    fileprivate static let thumbSize: CGFloat = 2 * VelovForecastAxis.inset

    fileprivate static var lastStep: Int32 { VelovForecast.companion.STEP_COUNT }

    /// La place du pouce sur l'axe, de 0 à 1.
    private var position: Double { Double(step) / Double(Self.lastStep) }

    var body: some View {
        VelovForecastSliderFace(position: position, trackLevels: trackLevels, ticks: ticks)
        // Le doigt se pose sur toute la hauteur, heures comprises, et le pouce le suit.
        .overlay {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        select(VelovForecastAxis(width: geometry.size.width).step(at: drag.location.x, lastStep: Self.lastStep))
                    })
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VelovTexts.shared.SLIDER_LABEL)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(step + 1)
            case .decrement: select(step - 1)
            @unknown default: break
            }
        }
    }

    private func select(_ candidate: Int32) {
        let bounded = min(max(candidate, 0), Self.lastStep)
        if bounded != step { onSelect(bounded) }
    }
}

/// Ce que l'on voit du curseur : la piste, le pouce posé à `position` (de 0 à 1 sur l'axe) et les heures.
/// Le curseur de la fiche et de la carte le pose sur une échéance ; l'intro le fait glisser seul, entre
/// deux échéances.
struct VelovForecastSliderFace: View {
    let position: Double
    /// Palier de chaque échéance (fiche) ; nil pour la piste neutre remplie jusqu'au pouce (carte).
    let trackLevels: [VelovChanceLevel]?
    let ticks: [VelovForecastTick]

    /// Place laissée à l'ombre du pouce, au-dessus et au-dessous.
    private static let shadowMargin: CGFloat = 3

    /// Hauteur de la piste et de son pouce, au-dessus des heures.
    static var trackHeight: CGFloat { VelovForecastSlider.thumbSize + 2 * shadowMargin }

    var body: some View {
        VStack(spacing: 2) {
            VelovForecastSliderTrack(levels: trackLevels, filledTo: trackLevels == nil ? position : nil)
                .equatable()
                .overlay { VelovForecastSliderThumb(position: position) }
                .frame(height: Self.trackHeight)
            VelovForecastSliderTicks(ticks: ticks)
                .equatable()
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// La piste du curseur : colorée par palier (fiche), qui ne change qu'avec le panneau, ou neutre et
/// remplie à l'accent jusqu'au pouce (carte).
private struct VelovForecastSliderTrack: View, Equatable {
    let levels: [VelovChanceLevel]?
    /// Jusqu'où la piste neutre est remplie, de 0 à 1 ; nil sur une piste colorée par palier.
    let filledTo: Double?

    private static let height: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let axis = VelovForecastAxis(width: size.width)
            let lastStep = Double(VelovForecastSlider.lastStep)
            let track = CGRect(x: axis.x(0), y: (size.height - Self.height) / 2, width: axis.x(1) - axis.x(0), height: Self.height)
            context.clip(to: Path(roundedRect: track, cornerRadius: Self.height / 2))
            if let levels {
                // Le segment de rang i va de l'échéance i à la suivante, un rien plus large pour ne pas laisser de jour.
                for (rank, level) in levels.enumerated() {
                    let from = axis.x(Double(rank) / lastStep)
                    let to = axis.x(Double(rank + 1) / lastStep)
                    context.fill(Path(CGRect(x: from, y: track.minY, width: to - from + 0.5, height: track.height)), with: .color(level.trackColor))
                }
            } else {
                context.fill(Path(track), with: .color(.appNeutralBorder))
                let filled = axis.x(filledTo ?? 0) - track.minX
                context.fill(Path(CGRect(x: track.minX, y: track.minY, width: filled, height: track.height)), with: .color(.appAccent))
            }
        }
    }
}

/// Le pouce du curseur, posé à sa place sur l'axe.
private struct VelovForecastSliderThumb: View {
    let position: Double

    var body: some View {
        Canvas { context, size in
            let thumbX = VelovForecastAxis(width: size.width).x(position)
            let side = VelovForecastSlider.thumbSize
            let thumb = Path(ellipseIn: CGRect(x: thumbX - side / 2, y: (size.height - side) / 2, width: side, height: side))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1))
                layer.fill(thumb, with: .color(.white))
            }
        }
    }
}

/// Les heures écrites sous la piste, chacune à son abscisse, sur une ligne à la hauteur du texte.
private struct VelovForecastSliderTicks: View, Equatable {
    let ticks: [VelovForecastTick]

    var body: some View {
        Text(verbatim: " ")
            .font(.caption2)
            .frame(maxWidth: .infinity)
            .hidden()
            .overlay {
                GeometryReader { geometry in
                    let axis = VelovForecastAxis(width: geometry.size.width)
                    ForEach(ticks, id: \.position) { tick in
                        Text(tick.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .position(x: axis.x(tick.position), y: geometry.size.height / 2)
                    }
                }
            }
    }
}

// MARK: - Fiche d'une station

/// Le bloc de prévision d'une fiche de station : le filtre de la carte, l'heure et le chiffre de
/// l'échéance, le graphique des 24 heures et son curseur, la période à risque. Sans `panel` ni
/// `readout` (prévision en cours de calcul), il garde sa place, vide.
struct VelovForecastCard: View {
    let panel: VelovForecastPanel?
    let readout: VelovForecastReadout?
    let filter: VelovFilter
    let onSelectFilter: (VelovFilter) -> Void
    let onSelectStep: (Int32) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelovForecastFilterPicker(filter: filter, onSelect: onSelectFilter)
                .equatable()

            reading

            if let panel, let readout {
                VStack(spacing: 0) {
                    VelovForecastChart(panel: panel, step: readout.step)
                    VelovForecastSlider(
                        step: readout.step,
                        trackLevels: panel.trackLevels,
                        ticks: panel.ticks,
                        valueText: "\(readout.time), \(readout.count)",
                        onSelect: onSelectStep
                    )
                }
                if let risk = panel.risk {
                    Divider()
                    VelovForecastRiskLine(text: risk)
                }
            } else {
                VStack(spacing: 0) {
                    Color.clear.frame(height: VelovForecastChart.height)
                    VelovForecastSlider(step: 0, trackLevels: nil, ticks: [], valueText: "", onSelect: { _ in })
                        .hidden()
                }
            }
        }
        .velovForecastCard()
    }

    /// L'heure de l'échéance, le chiffre principal et ce que vaut sa fourchette ; à droite, la chance d'en
    /// trouver au moins un. Les trois lignes gardent leur place même vides (« Maintenant » n'a ni
    /// fourchette ni chance) : le graphique et le curseur ne bougent pas sous le doigt.
    private var reading: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(readout?.time ?? " ")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(readout?.count ?? " ")
                    .font(.title.bold())
                    .minimumScaleFactor(0.6)
                Text(readout?.reliability ?? " ")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let chance = readout?.chance {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(chance.text)
                        .font(.title.bold())
                    Text(chance.level.label)
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(chance.level.color)
                .fixedSize()
            }
        }
        .lineLimit(1)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }
}

/// La période à risque d'une fiche : un point rouge et sa phrase (« Souvent vide de 9 h à 10 h 15 »).
struct VelovForecastRiskLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.appError)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.subheadline)
        }
    }
}

/// Le sélecteur de filtre de la fiche, laissé tel quel quand seul le curseur bouge.
struct VelovForecastFilterPicker: View, Equatable {
    let filter: VelovFilter
    let onSelect: (VelovFilter) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.filter == rhs.filter }

    var body: some View {
        Picker(VelovTexts.shared.FILTER_LABEL, selection: Binding(get: { filter }, set: onSelect)) {
            ForEach(VelovFilter.companion.ordered) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Carte

/// Panneau de verre posé en bas de la carte Vélo'v : l'heure que montrent les marqueurs et le curseur
/// qui la choisit, de « Maintenant » à dans 24 heures (on y revient en glissant). Le panneau tient
/// lui-même l'échéance sous le doigt : elle s'affiche aussitôt, sans attendre la carte, dont les
/// marqueurs suivent dès que leur liste arrive.
struct VelovForecastTimePanel: View {
    /// Heure où les stations ont été relevées : le départ du curseur.
    let originEpochMs: Int64
    let onSelect: (Int32) -> Void
    @State private var step: Int32

    init(originEpochMs: Int64, step: Int32, onSelect: @escaping (Int32) -> Void) {
        self.originEpochMs = originEpochMs
        self.onSelect = onSelect
        _step = State(initialValue: step)
    }

    var body: some View {
        let panel = VelovForecastMapPanel.companion.at(originEpochMs: originEpochMs, step: step)
        VelovForecastTimeCard(panel: panel) {
            VelovForecastSlider(step: step, trackLevels: nil, ticks: panel.ticks, valueText: panel.title) { selected in
                step = selected
                onSelect(selected)
            }
        }
        // Le curseur montré, la prévision est vue : la pastille « Nouveau » n'a plus lieu d'être.
        .onAppear { NewBadgesViewModel.shared.markVelovForecastSeen() }
    }
}

/// L'habit du panneau de la carte : l'heure que montrent les marqueurs, la consigne, et dessous le
/// curseur donné (celui de la carte, sous le doigt, ou celui de l'intro, qui glisse seul).
struct VelovForecastTimeCard<Slider: View>: View {
    let panel: VelovForecastMapPanel
    private let slider: Slider

    init(panel: VelovForecastMapPanel, @ViewBuilder slider: () -> Slider) {
        self.panel = panel
        self.slider = slider()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(panel.title)
                    .font(.title3.bold())
                    .monospacedDigit()
                // La ligne garde sa place quand la consigne s'efface : le curseur ne bouge pas sous le doigt.
                Text(panel.hint ?? " ")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            slider
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassSurface(RoundedRectangle(cornerRadius: 26))
    }
}
