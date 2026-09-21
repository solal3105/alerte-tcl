import SwiftUI
import WidgetKit

// MARK: - Prochains passages

/// Vue du widget « Prochains passages », dans toutes ses tailles : la ligne et l'arrêt, puis le
/// prochain passage en grand. Partagée avec l'application, qui l'affiche telle quelle dans sa
/// galerie de widgets.
struct DeparturesWidgetView: View {
    let entry: DeparturesEntry
    let family: WidgetFamily

    var body: some View {
        switch entry.status {
        case .notConfigured:
            notConfigured
        case .unavailable:
            unavailable
        case .ready:
            switch family {
            case .systemSmall: small
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: medium
            }
        }
    }

    private var stop: WidgetStop? { entry.stop }
    private var first: WidgetDeparture? { entry.departures.first }

    /// Mention quand les passages affichés viennent des fiches horaires et non du direct.
    private var plannedNote: String? { entry.theoretical ? "horaires prévus" : nil }

    // MARK: Tailles

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let stop {
                HStack(spacing: 8) {
                    WidgetLineBadge(line: stop.line, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(stop.stopName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text(stop.direction)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 6)
            if let first {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(first.figure(at: entry.date))
                        .font(.system(size: first.isCountdown(at: entry.date) ? 52 : 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(lineColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    if first.isCountdown(at: entry.date) {
                        Text("min")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.secondary)
                    } else if let day = first.dayLabel(at: entry.date) {
                        Text(day)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    if first.realTime { WidgetLiveDot() }
                }
                HStack(spacing: 4) {
                    ForEach(entry.departures.dropFirst().prefix(3), id: \.id) { departure in
                        WidgetChip(text: departure.label(at: entry.date))
                    }
                }
            } else {
                noDeparture
            }
            Spacer(minLength: 4)
            WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale, note: plannedNote)
        }
    }

    /// Couleur de la ligne, celle du badge : le chiffre du prochain passage la reprend.
    private var lineColor: Color {
        stop.map { WidgetLinePalette.background(for: $0.line) } ?? WidgetTheme.accent
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                if let stop {
                    WidgetLineBadge(line: stop.line, size: 46)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stop.stopName)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("vers \(stop.direction)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale, note: plannedNote)
            }
            .frame(maxWidth: 132, alignment: .leading)

            if entry.departures.isEmpty {
                VStack(alignment: .leading) {
                    Spacer(minLength: 0)
                    noDeparture
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.departures.prefix(3).enumerated()), id: \.element.id) { index, departure in
                        if index > 0 { WidgetRule() }
                        departureRow(departure, highlighted: index == 0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Une ligne du tableau : le temps d'attente à gauche, l'heure de passage à droite.
    private func departureRow(_ departure: WidgetDeparture, highlighted: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(departure.label(at: entry.date))
                .font(.system(size: highlighted ? 26 : 16, weight: highlighted ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(highlighted ? lineColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .widgetAccentable()
            if departure.realTime { WidgetLiveDot() }
            Spacer(minLength: 4)
            Text(departure.timeText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, highlighted ? 7 : 6)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -1) {
                if let stop {
                    Text(stop.line)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if let first {
                    Text(first.figure(at: entry.date))
                        .font(.system(size: first.isCountdown(at: entry.date) ? 22 : 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    if first.isCountdown(at: entry.date) {
                        Text("min").font(.system(size: 9, weight: .semibold))
                    } else if let day = first.dayLabel(at: entry.date) {
                        Text(day).font(.system(size: 8, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                } else {
                    Image(systemName: "clock").font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(4)
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            if let stop { WidgetLineBadge(line: stop.line, size: 30) }
            VStack(alignment: .leading, spacing: 1) {
                Text(stop?.stopName ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Text(stop?.direction ?? "")
                    .font(.caption2)
                    .lineLimit(1)
                Text(entry.departures.isEmpty ? "Aucun passage prévu" : entry.departures.prefix(3).map { $0.label(at: entry.date) }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
        }
    }

    private var inline: some View {
        let text: String
        if let stop, let first {
            text = "\(stop.line) \(stop.stopName) · \(first.label(at: entry.date))"
        } else if let stop {
            text = "\(stop.line) \(stop.stopName) · aucun passage"
        } else {
            text = "Choisissez un arrêt"
        }
        return Label(text, systemImage: WidgetTransportMode.of(line: stop?.line ?? "").symbol)
    }

    // MARK: États

    private var noDeparture: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Aucun passage prévu")
                .font(.system(size: 14, weight: .bold))
            Text("Ni en direct ni dans les fiches horaires des trois prochains jours.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var notConfigured: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "clock.badge.questionmark").font(.system(size: 18, weight: .semibold))
            }
        case .accessoryRectangular:
            WidgetLockMessage(symbol: "clock.badge.questionmark", title: "Choisissez un arrêt", text: "Enregistrez un arrêt dans Lyon Pocket, puis réglez ce widget.")
        case .accessoryInline:
            Label("Choisissez un arrêt dans Lyon Pocket", systemImage: "clock.badge.questionmark")
        default:
            WidgetMessage(
                symbol: "clock.badge.questionmark",
                title: "Choisissez un arrêt",
                text: "Enregistrez un arrêt depuis sa fiche dans Lyon Pocket, puis maintenez ce widget appuyé pour le choisir.",
                compact: family == .systemSmall
            )
        }
    }

    @ViewBuilder
    private var unavailable: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "wifi.slash").font(.system(size: 18, weight: .semibold))
            }
        case .accessoryRectangular:
            WidgetLockMessage(symbol: "wifi.slash", title: stop?.stopName ?? "Passages", text: "Passages indisponibles pour l'instant.")
        case .accessoryInline:
            Label("\(stop?.line ?? "") \(stop?.stopName ?? "") · indisponible", systemImage: "wifi.slash")
        default:
            VStack(alignment: .leading, spacing: 8) {
                if let stop {
                    HStack(spacing: 8) {
                        WidgetLineBadge(line: stop.line, size: 30)
                        Text(stop.stopName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    }
                }
                WidgetMessage(
                    symbol: "wifi.slash",
                    title: "Passages indisponibles",
                    text: "Le réseau n'a pas répondu. Le widget réessaie tout seul dans quelques minutes.",
                    tint: WidgetTheme.warning,
                    compact: family == .systemSmall
                )
            }
        }
    }
}

// MARK: - Tableau de départs

/// Vue du widget « Tableau de départs » : un arrêt par ligne, ses deux prochains passages à droite.
/// Aucun titre : les arrêts se suffisent.
struct BoardWidgetView: View {
    let entry: BoardEntry
    let family: WidgetFamily

    private var isLarge: Bool { family == .systemLarge || family == .systemExtraLarge }
    private var rowLimit: Int { isLarge ? 8 : 4 }

    var body: some View {
        if entry.status == .notConfigured || entry.rows.isEmpty {
            WidgetMessage(
                symbol: "list.bullet.rectangle",
                title: "Aucun arrêt enregistré",
                text: "Enregistrez vos arrêts depuis leur fiche dans Lyon Pocket : ils s'affichent ici, du premier au dernier."
            )
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entry.rows.prefix(rowLimit).enumerated()), id: \.element.id) { index, row in
                    if index > 0 { WidgetRule() }
                    Link(destination: WidgetLink.stop(row.stop.stopId).url) {
                        boardRow(row)
                    }
                }
                Spacer(minLength: 0)
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date)
            }
        }
    }

    private func boardRow(_ row: BoardRow) -> some View {
        HStack(spacing: 10) {
            WidgetLineBadge(line: row.stop.line, size: isLarge ? 30 : 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.stop.stopName)
                    .font(.system(size: isLarge ? 13 : 12, weight: .bold))
                    .lineLimit(1)
                Text(row.stop.direction)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            times(row)
        }
        .padding(.vertical, isLarge ? 6 : 5)
    }

    /// À droite de chaque arrêt : le prochain passage en grand, le suivant en capsule.
    @ViewBuilder
    private func times(_ row: BoardRow) -> some View {
        if row.failed {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.warning)
        } else if row.departures.isEmpty {
            Text("aucun passage")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(row.departures[0].label(at: entry.date))
                    .font(.system(size: isLarge ? 18 : 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetLinePalette.background(for: row.stop.line))
                    .widgetAccentable()
                if row.departures[0].realTime { WidgetLiveDot() }
                if row.departures.count > 1 {
                    WidgetChip(text: row.departures[1].label(at: entry.date))
                }
            }
            .lineLimit(1)
        }
    }
}
