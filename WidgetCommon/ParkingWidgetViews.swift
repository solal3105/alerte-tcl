import SwiftUI
import WidgetKit

/// Vue du widget « Places de parking », dans toutes ses tailles.
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

    // MARK: Tailles

    private func small(_ parking: WidgetParkingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetHeader(symbol: "parkingsign", title: parking.kindLabel)
            Text(parking.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            if let available = parking.available, parking.open {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(available)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(color(parking))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    Text(available > 1 ? "places libres" : "place libre")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                capacityBar(parking)
            } else {
                Text(parking.statusText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(parking.open ? Color.secondary : WidgetTheme.error)
            }
            Spacer(minLength: 2)
            WidgetFooter(fetchedAt: entry.fetchedAt, stale: entry.stale)
        }
    }

    private func medium(_ parking: WidgetParkingSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetHeader(symbol: "parkingsign", title: parking.kindLabel)
                Text(parking.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sentence(parking))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                WidgetFooter(fetchedAt: entry.fetchedAt, stale: entry.stale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                WidgetRing(fraction: parking.open ? parking.freeFraction : 0, color: color(parking), lineWidth: 10)
                VStack(spacing: 0) {
                    if let available = parking.available, parking.open {
                        Text("\(available)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(color(parking))
                            .minimumScaleFactor(0.6)
                            .widgetAccentable()
                        if let capacity = parking.capacity {
                            Text("sur \(capacity)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: parking.open ? "questionmark" : "xmark")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(color(parking))
                    }
                }
            }
            .frame(width: 100, height: 100)
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

    // MARK: Éléments

    /// Barre de capacité : la part des places libres, à la couleur de disponibilité.
    private func capacityBar(_ parking: WidgetParkingSnapshot) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color(parking).opacity(0.18))
                Capsule().fill(color(parking)).frame(width: geometry.size.width * parking.freeFraction)
            }
        }
        .frame(height: 5)
    }

    /// « 42 places libres sur 150, il reste de la place. »
    private func sentence(_ parking: WidgetParkingSnapshot) -> String {
        guard parking.open else { return "Le parking est fermé pour l'instant." }
        guard let available = parking.available else { return "L'exploitant ne transmet pas la disponibilité en temps réel." }
        let count = parking.capacity.map { "\(parking.statusText) sur \($0)" } ?? parking.statusText
        switch parking.availability {
        case .good: return "\(count), il reste de la place."
        case .medium: return "\(count), il se remplit."
        case .low: return available <= 0 ? "Complet pour l'instant." : "\(count), presque complet."
        case .unknown: return count
        }
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
