import AppIntents
import CoreLocation
import SwiftUI
import WidgetKit

// MARK: - Station choisie (entité de réglage)

struct VelovStationEntity: AppEntity {
    let id: Int
    let name: String
    let address: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Station Vélo'v") }
    static var defaultQuery = VelovStationEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: address.isEmpty ? nil : "\(address)")
    }

    init(station: VelovService.Station) {
        id = station.id
        name = station.displayName
        address = station.address ?? ""
    }
}

struct VelovStationEntityQuery: EntityStringQuery {
    func entities(for identifiers: [Int]) async throws -> [VelovStationEntity] {
        guard let result = await VelovService.stations() else { return [] }
        return identifiers.compactMap { id in result.stations.first(where: { $0.id == id }) }.map { VelovStationEntity(station: $0) }
    }

    func entities(matching string: String) async throws -> [VelovStationEntity] {
        await VelovService.search(string).map { VelovStationEntity(station: $0) }
    }

    func suggestedEntities() async throws -> [VelovStationEntity] {
        guard let result = await VelovService.stations() else { return [] }
        return VelovService.sorted(result.stations).map { VelovStationEntity(station: $0) }
    }
}

// MARK: - Réglage

struct VelovIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Station Vélo'v"
    static var description = IntentDescription("Les vélos et les places d'une station, ou de la plus proche de vous.")

    @Parameter(title: "La station la plus proche de moi", default: true)
    var nearest: Bool

    @Parameter(title: "Station")
    var station: VelovStationEntity?

    init() {}
}

// MARK: - Chronologie

struct VelovProvider: AppIntentTimelineProvider {
    private static let refreshInterval: TimeInterval = 10 * 60

    func placeholder(in context: Context) -> VelovEntry {
        WidgetSamples.velov
    }

    func snapshot(for configuration: VelovIntent, in context: Context) async -> VelovEntry {
        if context.isPreview { return WidgetSamples.velov }
        return await entry(for: configuration, now: Date())
    }

    func timeline(for configuration: VelovIntent, in context: Context) async -> Timeline<VelovEntry> {
        let now = Date()
        let entry = await entry(for: configuration, now: now)
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.refreshInterval)))
    }

    /// Une station fixée passe avant tout ; sinon la plus proche de la position, si elle est connue.
    private func entry(for configuration: VelovIntent, now: Date) async -> VelovEntry {
        if let chosen = configuration.station, !configuration.nearest {
            return await fixed(stationId: chosen.id, now: now)
        }
        if let location = await WidgetLocation.current() {
            guard let found = await VelovService.nearest(to: location) else {
                return VelovEntry(date: now, status: .unavailable, station: nil, needsLocation: false, fetchedAt: nil, stale: false)
            }
            return VelovEntry(
                date: now, status: .ready,
                station: found.station.snapshot(distanceMeters: found.distance),
                needsLocation: false, fetchedAt: found.fetchedAt, stale: found.stale
            )
        }
        if let chosen = configuration.station {
            return await fixed(stationId: chosen.id, now: now)
        }
        return .notConfigured(needsLocation: configuration.nearest, date: now)
    }

    private func fixed(stationId: Int, now: Date) async -> VelovEntry {
        guard let found = await VelovService.station(id: stationId) else {
            return VelovEntry(date: now, status: .unavailable, station: nil, needsLocation: false, fetchedAt: nil, stale: false)
        }
        return VelovEntry(
            date: now, status: .ready,
            station: found.station.snapshot(distanceMeters: nil),
            needsLocation: false, fetchedAt: found.fetchedAt, stale: found.stale
        )
    }
}

// MARK: - Widget

struct VelovWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.velov.rawValue, intent: VelovIntent.self, provider: VelovProvider()) { entry in
            VelovEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetKind.velov.title)
        .description(WidgetKind.velov.summary)
        .supportedFamilies(WidgetKind.velov.families)
    }
}

private struct VelovEntryView: View {
    let entry: VelovEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VelovWidgetView(entry: entry, family: family)
            .containerBackground(for: .widget) { WidgetSurface(tint: entry.surfaceTint) }
            .widgetURL((entry.station.map { WidgetLink.velov($0.id) } ?? .widgets).url)
    }
}

#Preview("Vélo'v, petit", as: .systemSmall) {
    VelovWidget()
} timeline: {
    WidgetSamples.velov
    VelovEntry.notConfigured(needsLocation: true)
}

#Preview("Vélo'v, moyen", as: .systemMedium) {
    VelovWidget()
} timeline: {
    WidgetSamples.velov
}
