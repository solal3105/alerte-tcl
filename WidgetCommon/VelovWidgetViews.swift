import SwiftUI
import WidgetKit

/// Vue du widget « Station Vélo'v », dans toutes ses tailles : le nom de la station, les vélos
/// disponibles en grand, et le détail en une rangée. Pas de titre, pas d'adresse.
struct VelovWidgetView: View {
    let entry: VelovEntry
    let family: WidgetFamily

    var body: some View {
        switch entry.status {
        case .notConfigured:
            notConfigured
        case .unavailable:
            unavailable
        case .ready:
            if let station = entry.station {
                switch family {
                case .systemSmall: small(station)
                case .accessoryCircular: circular(station)
                case .accessoryRectangular: rectangular(station)
                case .accessoryInline: inline(station)
                default: medium(station)
                }
            } else {
                unavailable
            }
        }
    }

    private func color(_ station: WidgetVelovSnapshot) -> Color {
        WidgetTheme.availability(station.availability)
    }

    /// « 3 élec · 12 places », le détail sur une seule ligne.
    private func detailLine(_ station: WidgetVelovSnapshot) -> String {
        var parts: [String] = []
        if station.ebikes > 0 { parts.append("\(station.ebikes) élec") }
        parts.append("\(station.stands) \(station.stands > 1 ? "places" : "place")")
        return parts.joined(separator: " · ")
    }

    // MARK: Tailles

    private func small(_ station: WidgetVelovSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(station.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let distance = station.distanceText {
                Text(distance)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if station.open {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color(station))
                        .widgetAccentable()
                    Text("\(station.bikes)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(color(station))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                }
                HStack(spacing: 4) {
                    if station.ebikes > 0 {
                        WidgetChip(text: "\(station.ebikes)", symbol: "bolt.fill", color: WidgetTheme.accent)
                    }
                    WidgetChip(text: "\(station.stands)", symbol: "parkingsign")
                }
            } else {
                closed(size: 17)
            }
            Spacer(minLength: 4)
            WidgetStamp(fetchedAt: station.updated ?? entry.fetchedAt, now: entry.date, stale: entry.stale)
        }
    }

    private func medium(_ station: WidgetVelovSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "bicycle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(WidgetTheme.velov)
                    .widgetAccentable()
                Text(station.name)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let distance = station.distanceText {
                    Text(distance)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                WidgetStamp(fetchedAt: station.updated ?? entry.fetchedAt, now: entry.date, stale: entry.stale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if station.open {
                HStack(spacing: 7) {
                    WidgetStat(symbol: "bicycle", value: "\(station.bikes)", color: color(station), width: 52)
                    WidgetStat(symbol: "bolt.fill", value: "\(station.ebikes)", color: WidgetTheme.accent, width: 52)
                    WidgetStat(symbol: "parkingsign", value: "\(station.stands)", color: WidgetTheme.neutral, width: 52)
                }
            } else {
                closed(size: 15).frame(width: 90)
            }
        }
    }

    /// Station fermée : le seul cas où il n'y a aucun chiffre à montrer.
    private func closed(size: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: size + 3))
                .foregroundStyle(WidgetTheme.error)
            Text("Fermée")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(WidgetTheme.error)
        }
    }

    private func circular(_ station: WidgetVelovSnapshot) -> some View {
        Gauge(value: Double(station.open ? station.bikes : 0), in: 0...Double(max(station.capacity, 1))) {
            Image(systemName: "bicycle")
        } currentValueLabel: {
            Text(station.open ? "\(station.bikes)" : "✕")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private func rectangular(_ station: WidgetVelovSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bicycle.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(station.name).font(.headline).lineLimit(1)
                if station.open {
                    Text("\(station.bikes) vélos · \(detailLine(station))")
                        .font(.caption2)
                        .lineLimit(1)
                } else {
                    Text("Fermée").font(.caption2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func inline(_ station: WidgetVelovSnapshot) -> some View {
        Label(
            station.open ? "\(station.name) · \(station.bikes) vélos · \(station.stands) places" : "\(station.name) · fermée",
            systemImage: "bicycle"
        )
    }

    // MARK: États

    private var notConfiguredTitle: String { entry.needsLocation ? "Position inconnue" : "Choisissez une station" }

    private var notConfiguredText: String {
        entry.needsLocation
            ? "Autorisez Lyon Pocket à utiliser votre position, ou maintenez ce widget appuyé pour choisir une station."
            : "Maintenez ce widget appuyé pour chercher une station par son nom."
    }

    @ViewBuilder
    private var notConfigured: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.needsLocation ? "location.slash" : "bicycle").font(.system(size: 18, weight: .bold))
            }
        case .accessoryRectangular:
            WidgetLockMessage(symbol: entry.needsLocation ? "location.slash" : "bicycle", title: notConfiguredTitle, text: notConfiguredText)
        case .accessoryInline:
            Label(notConfiguredTitle, systemImage: "bicycle")
        default:
            WidgetMessage(
                symbol: entry.needsLocation ? "location.slash" : "bicycle",
                title: notConfiguredTitle,
                text: notConfiguredText,
                tint: WidgetTheme.velov,
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
            WidgetLockMessage(symbol: "wifi.slash", title: entry.station?.name ?? "Vélo'v", text: "Station indisponible pour l'instant.")
        case .accessoryInline:
            Label("Vélo'v · indisponible", systemImage: "wifi.slash")
        default:
            WidgetMessage(
                symbol: "wifi.slash",
                title: "Station indisponible",
                text: "Le réseau n'a pas répondu. Le widget réessaie tout seul dans quelques minutes.",
                tint: WidgetTheme.warning,
                compact: family == .systemSmall
            )
        }
    }
}
