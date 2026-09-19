import SwiftUI
import WidgetKit

/// Vue du widget « Trafic sur mes lignes », dans toutes ses tailles.
struct TrafficWidgetView: View {
    let entry: TrafficEntry
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
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: medium
            }
        }
    }

    /// Couleur et pictogramme de l'état : vert quand tout roule, orange perturbé, rouge majeur.
    private var tone: Color {
        if entry.hasMajor { return WidgetTheme.error }
        if !entry.disrupted.isEmpty { return WidgetTheme.warning }
        return WidgetTheme.success
    }

    private var symbol: String {
        if entry.hasMajor { return "xmark.octagon.fill" }
        if !entry.disrupted.isEmpty { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    // MARK: Tailles

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(symbol: symbol, title: "Mes lignes", tint: tone)
            Spacer(minLength: 0)
            Text(entry.headline)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = entry.detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            badges(entry.disrupted.isEmpty ? entry.subscribed : entry.disrupted.map(\.line), limit: 4, size: 22)
            Spacer(minLength: 0)
            WidgetFooter(fetchedAt: entry.fetchedAt, stale: entry.stale)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(symbol: "exclamationmark.triangle.fill", title: "Trafic sur mes lignes")
            if entry.disrupted.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 30))
                        .foregroundStyle(tone)
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.headline)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(2)
                        if let detail = entry.detail {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        badges(entry.subscribed, limit: 7, size: 22)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                ForEach(entry.disrupted.prefix(3)) { line in
                    Link(destination: WidgetLink.traffic.url) {
                        HStack(spacing: 8) {
                            WidgetLineBadge(line: line.line, size: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(line.title.isEmpty ? line.severity.label : line.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Text(line.severity.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(WidgetTheme.severity(line.severity))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                if entry.disrupted.count > 3 {
                    Text(entry.disrupted.count - 3 == 1 ? "et 1 autre ligne" : "et \(entry.disrupted.count - 3) autres lignes")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            WidgetFooter(fetchedAt: entry.fetchedAt, stale: entry.stale)
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.headline).font(.headline).lineLimit(2)
                Text(entry.disrupted.isEmpty
                     ? (entry.detail ?? "Lignes suivies : " + entry.subscribed.joined(separator: ", "))
                     : entry.disrupted.map(\.line).joined(separator: ", "))
                    .font(.caption2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var inline: some View {
        Label(entry.disrupted.isEmpty ? "TCL : vos lignes circulent" : "TCL : \(entry.disrupted.map(\.line).joined(separator: ", ")) perturbée\(entry.disrupted.count > 1 ? "s" : "")", systemImage: symbol)
    }

    /// Une rangée de badges, avec « +3 » au-delà de la limite.
    private func badges(_ lines: [String], limit: Int, size: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(lines.prefix(limit), id: \.self) { line in
                WidgetLineBadge(line: line, size: size)
            }
            if lines.count > limit {
                Text("+\(lines.count - limit)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: États

    @ViewBuilder
    private var notConfigured: some View {
        switch family {
        case .accessoryRectangular:
            WidgetLockMessage(symbol: "bell.badge", title: "Suivez vos lignes", text: "Abonnez-vous à vos lignes dans Lyon Pocket.")
        case .accessoryInline:
            Label("Suivez vos lignes dans Lyon Pocket", systemImage: "bell.badge")
        default:
            WidgetMessage(
                symbol: "bell.badge",
                title: "Suivez vos lignes",
                text: "Abonnez-vous à vos lignes dans Lyon Pocket, depuis le trafic de la carte : leur état s'affichera ici.",
                compact: family == .systemSmall
            )
        }
    }

    @ViewBuilder
    private var unavailable: some View {
        switch family {
        case .accessoryRectangular:
            WidgetLockMessage(symbol: "wifi.slash", title: "Trafic indisponible", text: "Le réseau n'a pas répondu.")
        case .accessoryInline:
            Label("TCL : trafic indisponible", systemImage: "wifi.slash")
        default:
            WidgetMessage(
                symbol: "wifi.slash",
                title: "Trafic indisponible",
                text: "Le réseau n'a pas répondu. Le widget réessaie tout seul dans quelques minutes.",
                tint: WidgetTheme.warning,
                compact: family == .systemSmall
            )
        }
    }
}
