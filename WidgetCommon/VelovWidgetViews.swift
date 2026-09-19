import SwiftUI
import WidgetKit

/// Vue du widget « Station Vélo'v », dans toutes ses tailles.
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

    private var headerTitle: String { entry.nearest ? "Vélo'v la plus proche" : "Vélo'v" }

    private func color(_ station: WidgetVelovSnapshot) -> Color {
        WidgetTheme.availability(station.availability)
    }

    // MARK: Tailles

    private func small(_ station: WidgetVelovSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetHeader(symbol: "bicycle", title: headerTitle, tint: WidgetTheme.velov)
            Text(station.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            if station.open {
                HStack(alignment: .top, spacing: 14) {
                    WidgetFigure(value: "\(station.bikes)", unit: station.bikes > 1 ? "vélos" : "vélo", size: 30, color: color(station))
                    WidgetFigure(value: "\(station.stands)", unit: station.stands > 1 ? "places" : "place", size: 30)
                }
                if station.ebikes > 0 {
                    Text(station.ebikes > 1 ? "dont \(station.ebikes) électriques" : "dont 1 électrique")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Station fermée")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WidgetTheme.error)
            }
            Spacer(minLength: 2)
            WidgetFooter(fetchedAt: station.updated ?? entry.fetchedAt, stale: entry.stale, trailing: station.distanceText)
        }
    }

    private func medium(_ station: WidgetVelovSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetHeader(symbol: "bicycle", title: headerTitle, tint: WidgetTheme.velov)
                Text(station.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !station.address.isEmpty {
                    Text(station.address)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                WidgetFooter(fetchedAt: station.updated ?? entry.fetchedAt, stale: entry.stale, trailing: station.distanceText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if station.open {
                HStack(spacing: 6) {
                    pill(value: "\(station.bikes)", unit: station.bikes > 1 ? "vélos" : "vélo", color: color(station))
                    pill(value: "\(station.ebikes)", unit: "élec.", color: WidgetTheme.accent)
                    pill(value: "\(station.stands)", unit: station.stands > 1 ? "places" : "place", color: .primary)
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(WidgetTheme.error)
                    Text("Fermée")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 90)
            }
        }
    }

    private func pill(value: String, unit: String, color: Color) -> some View {
        WidgetFigure(value: value, unit: unit, size: 24, color: color, alignment: .center)
            .frame(width: 52)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    Text("\(station.bikesText) · \(station.standsText)").font(.caption2).lineLimit(1)
                    if station.ebikes > 0 {
                        Text(station.ebikes > 1 ? "dont \(station.ebikes) électriques" : "dont 1 électrique").font(.caption2).lineLimit(1)
                    }
                } else {
                    Text("Station fermée").font(.caption2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func inline(_ station: WidgetVelovSnapshot) -> some View {
        Label(station.open ? "\(station.name) · \(station.bikes) vélos, \(station.stands) places" : "\(station.name) · fermée", systemImage: "bicycle")
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
