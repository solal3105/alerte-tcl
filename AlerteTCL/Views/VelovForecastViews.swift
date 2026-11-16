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
    /// Carte d'une fiche de station Vélo'v (prévision, voisines).
    func velovForecastCard() -> some View {
        padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Graphique

/// Graphique des 24 heures d'une station, à l'accent : la valeur la plus probable (trait), la
/// fourchette 10-90 (bande claire) et la fourchette 30-70 (bande soutenue), de 0 au haut de l'échelle,
/// avec le trait de minuit et le repère de l'échéance choisie.
struct VelovForecastChart: View {
    let panel: VelovForecastPanel
    let step: Int32

    static let height: CGFloat = 190
    private static let topInset: CGFloat = 10
    private static let bottomInset: CGFloat = 6
    private static let labelGap: CGFloat = 5
    private static let dotRadius: CGFloat = 5.5

    var body: some View {
        Canvas { context, size in
            let axis = VelovForecastAxis(width: size.width)
            let points = panel.points
            let plotHeight = size.height - Self.topInset - Self.bottomInset
            let scaleMax = Double(panel.scaleMax)
            func y(_ value: Double) -> CGFloat {
                Self.topInset + plotHeight * CGFloat(1 - value / scaleMax)
            }
            func curve(_ value: KeyPath<VelovForecastChartPoint, Double>) -> [CGPoint] {
                points.map { CGPoint(x: axis.x($0.position), y: y($0[keyPath: value])) }
            }
            func band(_ lower: KeyPath<VelovForecastChartPoint, Double>, _ upper: KeyPath<VelovForecastChartPoint, Double>) -> Path {
                var path = Path()
                path.addLines(curve(upper) + curve(lower).reversed())
                path.closeSubpath()
                return path
            }
            func line(_ through: [CGPoint]) -> Path {
                var path = Path()
                path.addLines(through)
                return path
            }

            // Le zéro et le haut de l'échelle, seul nombre écrit sur l'axe.
            for value in [0, scaleMax] {
                let segment = line([CGPoint(x: axis.x(0), y: y(value)), CGPoint(x: axis.x(1), y: y(value))])
                context.stroke(segment, with: .color(.appNeutralBorder), lineWidth: 1)
            }
            let scaleLabel = context.resolve(Text(verbatim: "\(panel.scaleMax)").font(.caption2).foregroundColor(.secondary))
            context.draw(scaleLabel, at: CGPoint(x: axis.x(1), y: Self.topInset + 2), anchor: .topTrailing)

            // Minuit : le nom du jour suit le trait, ou le précède quand il toucherait le nombre de l'échelle.
            if let midnight = panel.midnight {
                let midnightX = axis.x(midnight.position)
                let dashes = line([CGPoint(x: midnightX, y: Self.topInset), CGPoint(x: midnightX, y: Self.topInset + plotHeight)])
                context.stroke(dashes, with: .color(.appNeutralBorder), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                let dayLabel = context.resolve(Text(midnight.label).font(.caption2).foregroundColor(.secondary))
                let lastFreeX = axis.x(1) - scaleLabel.measure(in: size).width - Self.labelGap
                let fitsAfter = midnightX + Self.labelGap + dayLabel.measure(in: size).width <= lastFreeX
                context.draw(
                    dayLabel,
                    at: CGPoint(x: fitsAfter ? midnightX + Self.labelGap : midnightX - Self.labelGap, y: Self.topInset + 2),
                    anchor: fitsAfter ? .topLeading : .topTrailing
                )
            }

            context.fill(band(\.low, \.high), with: .color(Color.appAccent.opacity(0.16)))
            context.fill(band(\.midLow, \.midHigh), with: .color(Color.appAccent.opacity(0.30)))
            context.stroke(line(curve(\.median)), with: .color(.appAccent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

            // Repère de l'échéance : un trait qui descend jusqu'au pouce du curseur, la fourchette large
            // en gras et la valeur la plus probable en pastille.
            guard points.indices.contains(Int(step)) else { return }
            let selected = points[Int(step)]
            let cursorX = axis.x(selected.position)
            context.stroke(line([CGPoint(x: cursorX, y: Self.topInset), CGPoint(x: cursorX, y: size.height)]), with: .color(.primary), lineWidth: 1.5)
            context.stroke(
                line([CGPoint(x: cursorX, y: y(selected.high)), CGPoint(x: cursorX, y: y(selected.low))]),
                with: .color(.appAccent),
                style: StrokeStyle(lineWidth: 7, lineCap: .round)
            )
            let dot = Path(ellipseIn: CGRect(
                x: cursorX - Self.dotRadius, y: y(selected.median) - Self.dotRadius,
                width: 2 * Self.dotRadius, height: 2 * Self.dotRadius
            ))
            context.fill(dot, with: .style(.background))
            context.stroke(dot, with: .color(.appAccent), lineWidth: 3)
        }
        .frame(height: Self.height)
        // Les repères sont tenus par la géométrie : leur texte grandit avec les réglages, jusqu'à un plafond.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VelovTexts.shared.CHART_LABEL)
    }
}

// MARK: - Curseur d'heure

/// Curseur d'heure, le même sur la fiche d'une station et sur la carte : une échéance par quart
/// d'heure, de 0 (« Maintenant ») à la dernière, posées aux abscisses du graphique (`VelovForecastAxis`).
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

    private static let thumbSize: CGFloat = 2 * VelovForecastAxis.inset
    private static let trackHeight: CGFloat = 8
    /// Place laissée à l'ombre du pouce, au-dessus et au-dessous.
    private static let shadowMargin: CGFloat = 3

    private var lastStep: Int32 { VelovForecast.companion.STEP_COUNT }

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                let axis = VelovForecastAxis(width: size.width)
                let thumbX = axis.x(Double(step) / Double(lastStep))
                let track = CGRect(
                    x: axis.x(0), y: (size.height - Self.trackHeight) / 2,
                    width: axis.x(1) - axis.x(0), height: Self.trackHeight
                )
                var clipped = context
                clipped.clip(to: Path(roundedRect: track, cornerRadius: Self.trackHeight / 2))
                if let trackLevels {
                    // Le segment de rang i va de l'échéance i à la suivante, un rien plus large pour ne pas laisser de jour.
                    for (rank, level) in trackLevels.enumerated() {
                        let from = axis.x(Double(rank) / Double(lastStep))
                        let to = axis.x(Double(rank + 1) / Double(lastStep))
                        clipped.fill(Path(CGRect(x: from, y: track.minY, width: to - from + 0.5, height: track.height)), with: .color(level.trackColor))
                    }
                } else {
                    clipped.fill(Path(track), with: .color(.appNeutralBorder))
                    clipped.fill(Path(CGRect(x: track.minX, y: track.minY, width: thumbX - track.minX, height: track.height)), with: .color(.appAccent))
                }
                let thumb = Path(ellipseIn: CGRect(
                    x: thumbX - Self.thumbSize / 2, y: (size.height - Self.thumbSize) / 2,
                    width: Self.thumbSize, height: Self.thumbSize
                ))
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1))
                    layer.fill(thumb, with: .color(.white))
                }
            }
            .frame(height: Self.thumbSize + 2 * Self.shadowMargin)

            // Une ligne à la hauteur du texte, sur laquelle chaque heure se pose à son abscisse.
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
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        // Le doigt se pose sur toute la hauteur, heures comprises, et le pouce le suit.
        .overlay {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        select(VelovForecastAxis(width: geometry.size.width).step(at: drag.location.x, lastStep: lastStep))
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
        let bounded = min(max(candidate, 0), lastStep)
        if bounded != step { onSelect(bounded) }
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
            Picker(VelovTexts.shared.FILTER_LABEL, selection: Binding(get: { filter }, set: onSelectFilter)) {
                ForEach(VelovFilter.companion.ordered) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

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
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.appError)
                            .frame(width: 8, height: 8)
                        Text(risk)
                            .font(.subheadline)
                    }
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

// MARK: - Carte

/// Panneau de verre posé en bas de la carte Vélo'v : l'heure que montrent les marqueurs et le curseur
/// qui la choisit, de « Maintenant » à dans 24 heures.
struct VelovForecastTimePanel: View {
    /// Heure où les stations ont été relevées : le départ du curseur.
    let originEpochMs: Int64
    let step: Int32
    let onSelect: (Int32) -> Void

    var body: some View {
        let panel = VelovForecastMapPanel.companion.at(originEpochMs: originEpochMs, step: step)
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(panel.title)
                        .font(.title3.bold())
                        .monospacedDigit()
                    // La ligne garde sa place quand la consigne s'efface : le curseur ne bouge pas sous le doigt.
                    Text(panel.hint ?? " ")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let nowButton = panel.nowButton {
                    Button {
                        onSelect(0)
                    } label: {
                        Text(nowButton)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.appAccent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .lineLimit(1)

            VelovForecastSlider(step: step, trackLevels: nil, ticks: panel.ticks, valueText: panel.title, onSelect: onSelect)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassSurface(RoundedRectangle(cornerRadius: 26))
    }
}
