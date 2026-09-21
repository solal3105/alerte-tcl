import SwiftUI
import WidgetKit

/// Vue du widget « Places de parking », dans toutes ses tailles : le nom du parking, les places
/// libres en grand, et le remplissage. Le nombre n'est écrit qu'une fois.
struct ParkingWidgetView: View {
    let entry: ParkingEntry
    let family: WidgetFamily

    var body: some View {
        switch entry.status {
        case .notConfigured:
            notConfigured
        case .unavailable:
            unavailable
        case .ready:
            if let parking = entry.parking {
                switch family {
                case .systemSmall: small(parking)
                case .accessoryCircular: circular(parking)
                case .accessoryRectangular: rectangular(parking)
                case .accessoryInline: inline(parking)
                default: medium(parking)
                }
            } else {
                unavailable
            }
        }
    }

    private func color(_ parking: WidgetParkingSnapshot) -> Color {
        WidgetTheme.availability(parking.availability)
    }

    /// Seuls les parcs relais sont nommés : un parking public n'a pas besoin d'être annoncé comme tel.
    private func detail(_ parking: WidgetParkingSnapshot) -> String? {
        parking.isParcRelais ? "Parc relais" : nil
    }

    // MARK: Tailles

    private func small(_ parking: WidgetParkingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(parking.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = detail(parking) {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if let available = parking.available, parking.open {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "parkingsign")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color(parking))
                        .widgetAccentable()
                    Text("\(available)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(color(parking))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                }
                WidgetSegmentedBar(fraction: parking.freeFraction, color: color(parking), segments: 12)
                    .padding(.top, 4)
            } else {
                Text(parking.statusText)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(parking.open ? Color.secondary : WidgetTheme.error)
            }
            Spacer(minLength: 4)
            WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale)
        }
    }

    private func medium(_ parking: WidgetParkingSnapshot) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "parkingsign")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color(parking))
                    .widgetAccentable()
                Text(parking.name)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = detail(parking) {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if parking.open, parking.available != nil {
                    WidgetSegmentedBar(fraction: parking.freeFraction, color: color(parking), segments: 16)
                }
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: -4) {
                if let available = parking.available, parking.open {
                    Text("\(available)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .foregroundStyle(color(parking))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    WidgetLabel(text: parking.capacity.map { "libres sur \($0)" } ?? "libres")
                } else {
                    Image(systemName: parking.open ? "questionmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(color(parking))
                    Text(parking.statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            .frame(width: 118, alignment: .trailing)
        }
    }

    private func circular(_ parking: WidgetParkingSnapshot) -> some View {
        Gauge(value: Double(parking.open ? (parking.available ?? 0) : 0), in: 0...Double(max(parking.capacity ?? 1, 1))) {
            Image(systemName: "parkingsign")
        } currentValueLabel: {
            Text(parking.open ? (parking.available.map { "\($0)" } ?? "?") : "✕")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private func rectangular(_ parking: WidgetParkingSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "parkingsign.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text(parking.name).font(.headline).lineLimit(1)
                Text(parking.capacity.map { "\(parking.statusText) sur \($0)" } ?? parking.statusText)
                    .font(.caption)
                    .lineLimit(1)
                if parking.open, parking.available != nil {
                    Gauge(value: parking.freeFraction) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func inline(_ parking: WidgetParkingSnapshot) -> some View {
        Label("\(parking.name) · \(parking.statusText)", systemImage: "parkingsign")
    }

    // MARK: États

    @ViewBuilder
    private var notConfigured: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "parkingsign").font(.system(size: 20, weight: .bold))
            }
        case .accessoryRectangular:
            WidgetLockMessage(symbol: "parkingsign", title: "Choisissez un parking", text: "Maintenez le widget appuyé pour le régler.")
        case .accessoryInline:
            Label("Choisissez un parking", systemImage: "parkingsign")
        default:
            WidgetMessage(
                symbol: "parkingsign",
                title: "Choisissez un parking",
                text: "Maintenez ce widget appuyé, puis cherchez un parking ou un parc relais par son nom.",
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
            WidgetLockMessage(symbol: "wifi.slash", title: entry.parking?.name ?? "Parking", text: "Disponibilité indisponible pour l'instant.")
        case .accessoryInline:
            Label("\(entry.parking?.name ?? "Parking") · indisponible", systemImage: "wifi.slash")
        default:
            VStack(alignment: .leading, spacing: 8) {
                if let parking = entry.parking {
                    Text(parking.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                WidgetMessage(
                    symbol: "wifi.slash",
                    title: "Disponibilité indisponible",
                    text: "Le réseau n'a pas répondu. Le widget réessaie tout seul dans quelques minutes.",
                    tint: WidgetTheme.warning,
                    compact: family == .systemSmall
                )
            }
        }
    }
}
