import SwiftUI
import WidgetKit

/// Vue du widget « Travaux autour de moi » : la carte des chantiers autour de la position et la
/// liste des plus proches. Les marges du widget sont désactivées pour que la carte aille au bord ;
/// les textes reprennent la marge du système.
struct WorksWidgetView: View {
    let entry: WorksEntry
    let family: WidgetFamily
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetContentMargins) private var systemMargins

    /// Les marges du widget ; dans l'application (galerie), celles d'un widget.
    private var margins: EdgeInsets {
        systemMargins.leading > 0 ? systemMargins : EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    }

    var body: some View {
        switch entry.status {
        case .notConfigured, .unavailable:
            unavailable.padding(margins)
        case .ready:
            switch family {
            case .systemSmall: small.padding(margins)
            case .systemLarge, .systemExtraLarge: large
            default: medium
            }
        }
    }

    private var map: UIImage? { colorScheme == .dark ? (entry.mapDark ?? entry.mapLight) : (entry.mapLight ?? entry.mapDark) }
    private var headerTitle: String { "Travaux à \(entry.radiusText)" }
    private var placeLabel: String? { entry.hasLocation ? nil : "Centre de Lyon" }

    // MARK: Tailles

    private var small: some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetHeader(symbol: "hammer.fill", title: "Travaux", subtitle: entry.radiusText)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(entry.works.count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .widgetAccentable()
                Text(entry.works.count == 1 ? "chantier" : "chantiers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if let nearest = entry.works.first {
                Text(nearest.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text("\(nearest.address) · \(nearest.distanceText)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Rien à signaler autour de vous.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            WidgetFooter(fetchedAt: entry.fetchedAt, trailing: placeLabel)
        }
    }

    private var medium: some View {
        HStack(spacing: 0) {
            mapView
                .frame(width: 150)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                WidgetHeader(symbol: "hammer.fill", title: headerTitle)
                Text(entry.countText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .widgetAccentable()
                ForEach(entry.works.prefix(2)) { work in
                    workRow(work)
                }
                Spacer(minLength: 0)
                WidgetFooter(fetchedAt: entry.fetchedAt, trailing: placeLabel)
            }
            .padding(.leading, 12)
            .padding(.trailing, margins.trailing)
            .padding(.vertical, margins.top)
        }
    }

    private var large: some View {
        VStack(spacing: 0) {
            mapView
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetHeader(symbol: "hammer.fill", title: headerTitle)
                    Text(entry.countText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .widgetAccentable()
                }
                if entry.works.isEmpty {
                    Text("Rien à signaler autour de vous.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                ForEach(entry.works.prefix(4)) { work in
                    workRow(work)
                }
                Spacer(minLength: 0)
                WidgetFooter(fetchedAt: entry.fetchedAt, trailing: placeLabel)
            }
            .padding(.horizontal, margins.leading)
            .padding(.top, 10)
            .padding(.bottom, margins.bottom)
        }
    }

    // MARK: Éléments

    @ViewBuilder
    private var mapView: some View {
        if let map {
            Image(uiImage: map)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(Color.primary.opacity(0.06))
                Image(systemName: "map")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func workRow(_ work: WidgetWork) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(WidgetTheme.worksProgress(percent: work.progress))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(work.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(work.commune.isEmpty ? work.address : "\(work.address), \(work.commune)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(work.distanceText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var unavailable: some View {
        WidgetMessage(
            symbol: "wifi.slash",
            title: "Chantiers indisponibles",
            text: "Le réseau n'a pas répondu. Le widget réessaie tout seul dans l'heure.",
            tint: WidgetTheme.warning,
            compact: family == .systemSmall
        )
    }
}
