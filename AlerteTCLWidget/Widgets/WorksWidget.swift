import AppIntents
import CoreLocation
import SwiftUI
import WidgetKit

// MARK: - Réglage

enum WorksRadius: String, AppEnum {
    case m500
    case km1
    case km2

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Rayon") }
    static var caseDisplayRepresentations: [WorksRadius: DisplayRepresentation] = [
        .m500: "500 m",
        .km1: "1 km",
        .km2: "2 km",
    ]

    var meters: Int {
        switch self {
        case .m500: 500
        case .km1: 1000
        case .km2: 2000
        }
    }
}

struct WorksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Travaux autour de moi"
    static var description = IntentDescription("La carte des chantiers autour de votre position, avec les plus proches.")

    @Parameter(title: "Rayon", default: .km1)
    var radius: WorksRadius

    init() {}
}

// MARK: - Chronologie

struct WorksProvider: AppIntentTimelineProvider {
    private static let refreshInterval: TimeInterval = 60 * 60
    private static let retryInterval: TimeInterval = 20 * 60

    func placeholder(in context: Context) -> WorksEntry {
        WidgetSamples.works
    }

    func snapshot(for configuration: WorksIntent, in context: Context) async -> WorksEntry {
        if context.isPreview { return WidgetSamples.works }
        return await entry(for: configuration, in: context, now: Date())
    }

    func timeline(for configuration: WorksIntent, in context: Context) async -> Timeline<WorksEntry> {
        let now = Date()
        let entry = await entry(for: configuration, in: context, now: now)
        let delay = entry.status == .ready ? Self.refreshInterval : Self.retryInterval
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(delay)))
    }

    private func entry(for configuration: WorksIntent, in context: Context, now: Date) async -> WorksEntry {
        let radius = configuration.radius.meters
        let location = await WidgetLocation.current()
        let center = location?.coordinate ?? WorksMapSnapshot.lyonCenter
        do {
            let works = try await WorksService.nearby(center: center, radiusMeters: Double(radius), now: now)
            var light: UIImage?
            var dark: UIImage?
            if let mapSize = Self.mapSize(for: context.family, displaySize: context.displaySize) {
                let shapes = works.map(\.shape)
                let scale = Self.displayScale
                light = await WorksMapSnapshot.render(center: center, radiusMeters: Double(radius), shapes: shapes, size: mapSize, scale: scale, dark: false, showUser: location != nil)
                dark = await WorksMapSnapshot.render(center: center, radiusMeters: Double(radius), shapes: shapes, size: mapSize, scale: scale, dark: true, showUser: location != nil)
            }
            return WorksEntry(
                date: now, status: .ready, works: works.map(\.item), radiusMeters: radius,
                hasLocation: location != nil, mapLight: light, mapDark: dark, fetchedAt: now
            )
        } catch {
            AppLogger.debug("Chantiers injoignables : \(error.localizedDescription)", category: .widget)
            return WorksEntry(date: now, status: .unavailable, works: [], radiusMeters: radius, hasLocation: location != nil, mapLight: nil, mapDark: nil, fetchedAt: nil)
        }
    }

    /// Emprise de la carte dans le widget : la colonne de gauche en moyen, le bandeau du haut en grand.
    static func mapSize(for family: WidgetFamily, displaySize: CGSize) -> CGSize? {
        switch family {
        case .systemMedium: CGSize(width: 150, height: displaySize.height)
        case .systemLarge, .systemExtraLarge: CGSize(width: displaySize.width, height: 190)
        default: nil
        }
    }

    private static var displayScale: CGFloat {
        let scale = UIScreen.main.scale
        return scale > 0 ? scale : 3
    }
}

// MARK: - Widget

struct WorksWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.works.rawValue, intent: WorksIntent.self, provider: WorksProvider()) { entry in
            WorksEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetKind.works.title)
        .description(WidgetKind.works.summary)
        .supportedFamilies(WidgetKind.works.families)
        .contentMarginsDisabled()
    }
}

private struct WorksEntryView: View {
    let entry: WorksEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WorksWidgetView(entry: entry, family: family)
            .containerBackground(for: .widget) { WidgetSurface(tint: entry.surfaceTint) }
            .widgetURL(WidgetLink.works(entry.works.first?.id).url)
    }
}

#Preview("Travaux, moyen", as: .systemMedium) {
    WorksWidget()
} timeline: {
    WidgetSamples.works
}

#Preview("Travaux, grand", as: .systemLarge) {
    WorksWidget()
} timeline: {
    WidgetSamples.works
}
