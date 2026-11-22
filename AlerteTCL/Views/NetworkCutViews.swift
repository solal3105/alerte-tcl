import SwiftUI
import Shared

// MARK: - Coupures du réseau : briques des fiches et de la feuille Trafic
//
// Tout ce qui est écrit ou décidé ici vient de `NetworkCuts` (module partagé) : ces vues ne font que
// dessiner. Règles dans DESIGN.md (« Coupures du réseau »). La carte est dans `NetworkCutsMapLayer`.

/// « Voir sur la carte » d'une coupure annoncée : la carte Transport la montre comme elle sera.
/// Absent (nil) hors de la carte Transport, et le bouton n'apparaît pas.
private struct ShowNetworkCutKey: EnvironmentKey {
    static let defaultValue: ((NetworkCut) -> Void)? = nil
}

extension EnvironmentValues {
    var showNetworkCut: ((NetworkCut) -> Void)? {
        get { self[ShowNetworkCutKey.self] }
        set { self[ShowNetworkCutKey.self] = newValue }
    }
}

extension MergedStop {
    /// Ses lignes coupées ici, maintenant ou plus tard aujourd'hui.
    func networkCuts(in file: NetworkCutsFile?, nowEpoch: Int64) -> [NetworkCuts.StopCut] {
        guard let file else { return [] }
        return NetworkCuts.shared.stopCuts(
            file: file, name: nom, position: LatLng(latitude: coordinate.latitude, longitude: coordinate.longitude),
            lines: allLines, nowEpoch: nowEpoch
        )
    }
}

/// Phrase d'une carte de passages quand la ligne ne passe pas ici, maintenant ou ce soir.
struct CutNoticeRow: View {
    let stopCut: NetworkCuts.StopCut
    let nowEpoch: Int64

    var body: some View {
        let now = stopCut.timing.phase == .now
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: now ? "minus.circle.fill" : "clock.fill")
                .font(.subheadline)
                .foregroundStyle(now ? Color.appError : Color.appWarning)
            Text(NetworkCuts.shared.stopNotice(stopCut: stopCut, nowEpoch: nowEpoch))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Fiche de ligne

/// Bloc en haut de la fiche d'une ligne : ce qui ne circule pas, quand, et où sur un petit schéma.
struct CutLineBlockView: View {
    let block: NetworkCuts.LineBlock
    /// « Voir sur la carte » : seulement pour une coupure à venir (celle en cours est déjà sur la carte).
    var onShowOnMap: (() -> Void)? = nil

    private var isNow: Bool { block.phase == .now }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isNow ? "minus.circle.fill" : "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(isNow ? Color.appError : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.headline)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = block.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let note = block.note {
                        Label(note, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Color.appWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !block.diagram.isEmpty {
                CutDiagram(stops: block.diagram, line: block.cut.ligne, isNow: isNow)
            }
            if let onShowOnMap {
                Button(action: onShowOnMap) {
                    Label("Voir sur la carte", systemImage: "map")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(Color.appAccent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Schéma de la ligne : arrêts desservis en anneaux à la couleur de la ligne, tronçon coupé en
/// pointillé gris et arrêts barrés quand c'est maintenant, en tirets à sa couleur quand c'est à venir.
private struct CutDiagram: View {
    let stops: [NetworkCuts.DiagramStop]
    let line: String
    let isNow: Bool

    private static let height: CGFloat = 64
    private static let rowY: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let xs = positions(width: geo.size.width)
            let lineColor = LineColorHelper.backgroundColor(for: line)
            ZStack(alignment: .topLeading) {
                ForEach(Array(stops.dropLast().enumerated()), id: \.offset) { i, stop in
                    segment(from: xs[i], to: xs[i + 1], stop: stop, lineColor: lineColor)
                }
                ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                    node(stop, lineColor: lineColor)
                        .position(x: xs[i], y: Self.rowY)
                    let labelWidth = geo.size.width / CGFloat(stops.count)
                    Text(stop.name)
                        .font(.caption.weight(stop.bound ? .semibold : .regular))
                        .foregroundStyle(stop.cut && isNow ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: labelWidth)
                        .position(x: min(max(xs[i], labelWidth / 2), geo.size.width - labelWidth / 2), y: Self.rowY + 30)
                }
            }
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stops.map(\.name).joined(separator: ", "))
    }

    private func positions(width: CGFloat) -> [CGFloat] {
        let inset: CGFloat = 12
        guard stops.count > 1 else { return [width / 2] }
        let step = (width - 2 * inset) / CGFloat(stops.count - 1)
        return stops.indices.map { inset + CGFloat($0) * step }
    }

    @ViewBuilder
    private func segment(from a: CGFloat, to b: CGFloat, stop: NetworkCuts.DiagramStop, lineColor: Color) -> some View {
        let gap: CGFloat = stop.gapAfter ? 18 : 0
        let mid = (a + b) / 2
        let style: StrokeStyle = !stop.cutAfter
            ? StrokeStyle(lineWidth: 4, lineCap: .round)
            : isNow
                ? StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.1, 7])
                : StrokeStyle(lineWidth: 4, lineCap: .butt, dash: [7, 5])
        let color = stop.cutAfter && isNow ? Color.appCutTrace : lineColor
        Path { p in
            p.move(to: CGPoint(x: a, y: Self.rowY)); p.addLine(to: CGPoint(x: mid - gap / 2, y: Self.rowY))
            p.move(to: CGPoint(x: mid + gap / 2, y: Self.rowY)); p.addLine(to: CGPoint(x: b, y: Self.rowY))
        }
        .stroke(color, style: style)
        if stop.gapAfter {
            Text("…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .position(x: mid, y: Self.rowY - 2)
        }
    }

    @ViewBuilder
    private func node(_ stop: NetworkCuts.DiagramStop, lineColor: Color) -> some View {
        if stop.cut && isNow {
            Image(systemName: "xmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        } else {
            let size: CGFloat = stop.bound ? 18 : 13
            Circle()
                .fill(Color(.secondarySystemBackground))
                .overlay(Circle().strokeBorder(lineColor, lineWidth: 3))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Feuille Trafic

/// « Coupures annoncées » : ce que TCL a publié pour plus tard, par jours. Touchez une ligne pour sa fiche.
struct UpcomingCutsSection: View {
    let groups: [NetworkCuts.UpcomingGroup]
    let onSelect: (NetworkCut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coupures annoncées")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Ce que TCL a déjà publié pour les prochains jours. Ce qui est coupé en ce moment est sur la carte.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title.uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        ForEach(Array(group.rows.enumerated()), id: \.offset) { index, row in
                            rowView(row)
                            if index < group.rows.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func rowView(_ row: NetworkCuts.UpcomingRow) -> some View {
        Button { onSelect(row.cut) } label: {
            HStack(spacing: 12) {
                LineBadge(line: row.cut.ligne, size: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(row.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pastille de la carte

/// Pastille d'une coupure sur la carte : badge de la ligne et sens interdit (coupé) ou horloge (plus
/// tard aujourd'hui), avec la fin ou le début écrit dessous. Rendue en image par `NetworkCutsMapLayer`.
struct CutPastille: View {
    let line: String
    let soon: Bool
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                LineBadge(line: line, size: 12)
                Image(systemName: soon ? "clock.fill" : "minus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white, soon ? Color.appWarning : Color.appError)
            }
            .padding(4)
            .background(Color(.systemBackground), in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(.systemBackground), in: Capsule())
                .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
        }
        .padding(5)
    }
}
