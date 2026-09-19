import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Parking choisi (entité de réglage)

/// Un parking ou un parc relais de la Métropole, cherché par son nom au réglage du widget.
struct ParkingEntity: AppEntity {
    let id: String
    let name: String
    let isParcRelais: Bool

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Parking") }
    static var defaultQuery = ParkingEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: isParcRelais ? "Parc relais TCL" : "Parking")
    }

    init(item: WidgetParkingCatalogItem) {
        id = item.id
        name = item.name
        isParcRelais = item.isParcRelais
    }

    init(snapshot: WidgetParkingSnapshot) {
        id = snapshot.id
        name = snapshot.name
        isParcRelais = snapshot.isParcRelais
    }
}

struct ParkingEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ParkingEntity] {
        let catalog = await ParkingsService.catalog()
        return identifiers.compactMap { id in
            if let item = catalog.first(where: { $0.id == id }) { return ParkingEntity(item: item) }
            // Sans réseau, la dernière disponibilité connue garde au moins le nom.
            return ParkingsService.lastKnown(id: id).map { ParkingEntity(snapshot: $0) }
        }
    }

    func entities(matching string: String) async throws -> [ParkingEntity] {
        let needle = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return await ParkingsService.catalog()
            .filter { $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(needle) }
            .map { ParkingEntity(item: $0) }
    }

    func suggestedEntities() async throws -> [ParkingEntity] {
        await ParkingsService.catalog().map { ParkingEntity(item: $0) }
    }
}

// MARK: - Réglage

/// Nom du type et du paramètre conservés d'avant la refonte : les réglages des widgets déjà posés restent lus.
struct ParkingWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Places de parking"
    static var description = IntentDescription("Les places libres d'un parking ou d'un parc relais, en direct.")

    @Parameter(title: "Parking")
    var selectedParking: ParkingEntity?

    init() {}
}

// MARK: - Chronologie

struct ParkingProvider: AppIntentTimelineProvider {
    private static let refreshInterval: TimeInterval = 10 * 60

    func placeholder(in context: Context) -> ParkingEntry {
        WidgetSamples.parking
    }

    func snapshot(for configuration: ParkingWidgetConfigurationIntent, in context: Context) async -> ParkingEntry {
        if context.isPreview { return WidgetSamples.parking }
        return await entry(for: configuration, now: Date())
    }

    func timeline(for configuration: ParkingWidgetConfigurationIntent, in context: Context) async -> Timeline<ParkingEntry> {
        let now = Date()
        let entry = await entry(for: configuration, now: now)
        let delay = entry.status == .notConfigured ? 30 * 60 : Self.refreshInterval
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(delay)))
    }

    private func entry(for configuration: ParkingWidgetConfigurationIntent, now: Date) async -> ParkingEntry {
        guard let chosen = configuration.selectedParking else { return .notConfigured(date: now) }
        guard let result = await ParkingsService.snapshot(id: chosen.id, now: now) else {
            let known = ParkingsService.lastKnown(id: chosen.id)
                ?? WidgetParkingSnapshot(id: chosen.id, name: chosen.name, available: nil, capacity: nil, isParcRelais: chosen.isParcRelais, open: true)
            return ParkingEntry(date: now, status: .unavailable, parking: known, fetchedAt: nil, stale: false)
        }
        return ParkingEntry(date: now, status: .ready, parking: result.parking, fetchedAt: result.fetchedAt, stale: result.stale)
    }
}

// MARK: - Widget

struct ParkingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.parking.rawValue, intent: ParkingWidgetConfigurationIntent.self, provider: ParkingProvider()) { entry in
            ParkingEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetKind.parking.title)
        .description(WidgetKind.parking.summary)
        .supportedFamilies(WidgetKind.parking.families)
    }
}

private struct ParkingEntryView: View {
    let entry: ParkingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ParkingWidgetView(entry: entry, family: family)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL((entry.parking.map { WidgetLink.parking($0.id) } ?? .widgets).url)
    }
}

#Preview("Parking, petit", as: .systemSmall) {
    ParkingWidget()
} timeline: {
    WidgetSamples.parking
    ParkingEntry.notConfigured()
}

#Preview("Parking, moyen", as: .systemMedium) {
    ParkingWidget()
} timeline: {
    WidgetSamples.parking
}
