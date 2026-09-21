import SwiftUI
import WidgetKit

/// Vue du widget « Trafic sur mes lignes », dans toutes ses tailles : l'état en un pictogramme et
/// une phrase courte, puis les lignes concernées en badges. Pas de titre.
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

    /// Les lignes à montrer : celles qui sont perturbées, ou toutes celles qu'on suit quand tout roule.
    private var shownLines: [String] {
        entry.disrupted.isEmpty ? entry.subscribed : entry.disrupted.map(\.line)
    }

    // MARK: Tailles

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
            Spacer(minLength: 8)
            badges(shownLines, limit: 4, size: 26)
            if let detail = entry.detail {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            Spacer(minLength: 4)
            WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale)
        }
    }

    @ViewBuilder
    private var medium: some View {
        if entry.disrupted.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                banner
                badges(entry.subscribed, limit: 8, size: 30)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                banner
                    .padding(.bottom, 6)
                ForEach(Array(entry.disrupted.prefix(3).enumerated()), id: \.element.id) { index, line in
                    if index > 0 { WidgetRule() }
                    Link(destination: WidgetLink.traffic.url) { disruptedRow(line) }
                }
                Spacer(minLength: 0)
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, stale: entry.stale)
            }
        }
    }

    /// Le bandeau d'état : plein, à la couleur de l'état, le texte en blanc dessus.
    private var banner: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.symbol)
                .font(.system(size: 13, weight: .bold))
            Text(entry.headline.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .widgetAccentable()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.tone, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func disruptedRow(_ line: WidgetTrafficLine) -> some View {
        HStack(spacing: 10) {
            WidgetLineBadge(line: line.line, size: 28)
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
        .padding(.vertical, 5)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.symbol)
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.headline).font(.headline).lineLimit(2)
                Text(shownLines.joined(separator: ", "))
                    .font(.caption2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var inline: some View {
        Label(
            entry.disrupted.isEmpty
                ? "TCL : vos lignes circulent"
                : "TCL : \(entry.disrupted.map(\.line).joined(separator: ", ")) perturbée\(entry.disrupted.count > 1 ? "s" : "")",
            systemImage: entry.symbol
        )
    }

    /// Une rangée de badges, avec « +3 » au-delà de la limite.
    private func badges(_ lines: [String], limit: Int, size: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(lines.prefix(limit), id: \.self) { line in
                WidgetLineBadge(line: line, size: size)
            }
            if lines.count > limit {
                Text("+\(lines.count - limit)")
                    .font(.system(size: 11, weight: .semibold))
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
