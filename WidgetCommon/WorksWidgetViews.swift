import SwiftUI
import WidgetKit

/// Vue du widget « Travaux autour de moi » : la carte des chantiers autour de la position, leur
/// nombre, et les plus proches. Les marges du widget sont désactivées pour que la carte aille au
/// bord ; les textes reprennent la marge du système.
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

    /// « chantiers à 1 km » : l'unité porte le rayon, il n'y a donc pas de titre à écrire.
    private var unit: String {
        "\(entry.works.count == 1 ? "chantier" : "chantiers") à \(entry.radiusText)"
    }

    /// Précision utile seulement quand la position est inconnue : la carte est alors centrée sur Lyon.
    private var placeNote: String? { entry.hasLocation ? nil : "autour du centre de Lyon" }

    // MARK: Tailles

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WidgetTheme.accent)
                .widgetAccentable()
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(entry.works.count)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .widgetAccentable()
                Text(unit)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let nearest = entry.works.first {
                HStack(spacing: 6) {
                    progressDot(nearest)
                    Text(nearest.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(nearest.distanceText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 4)
            WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, note: placeNote)
        }
    }

    /// La carte occupe tout le widget ; le compte et le chantier le plus proche flottent dessus.
    private var medium: some View {
        ZStack(alignment: .bottomLeading) {
            mapView
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(entry.works.count)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                if let nearest = entry.works.first {
                    HStack(spacing: 6) {
                        progressDot(nearest)
                        Text(nearest.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(nearest.distanceText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Rien à signaler autour de vous.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, note: placeNote)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(10)
        }
    }

    private var large: some View {
        VStack(spacing: 0) {
            mapView
                .frame(maxWidth: .infinity)
                .frame(height: 186)
                .clipped()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(entry.works.count)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .widgetAccentable()
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)
                if entry.works.isEmpty {
                    Text("Rien à signaler autour de vous.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(entry.works.prefix(4).enumerated()), id: \.element.id) { index, work in
                    if index > 0 { WidgetRule() }
                    workRow(work)
                }
                Spacer(minLength: 0)
                WidgetStamp(fetchedAt: entry.fetchedAt, now: entry.date, note: placeNote)
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

    /// Point à la couleur de l'avancement, le même barème que la carte des chantiers.
    private func progressDot(_ work: WidgetWork) -> some View {
        Circle()
            .fill(WidgetTheme.worksProgress(percent: work.progress))
            .frame(width: 8, height: 8)
    }

    private func workRow(_ work: WidgetWork) -> some View {
        HStack(spacing: 8) {
            progressDot(work)
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
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
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
