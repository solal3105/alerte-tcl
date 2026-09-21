import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Arrêt choisi (entité de réglage)

/// Un arrêt enregistré dans l'application, proposé dans le réglage des widgets de passages.
struct StopEntity: AppEntity {
    let stop: WidgetStop

    var id: String { stop.id }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Arrêt") }
    static var defaultQuery = StopEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(stop.stopName)", subtitle: "\(stop.line) vers \(stop.direction)")
    }
}

struct StopEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StopEntity] {
        identifiers.compactMap { WidgetStore.stop(id: $0) }.map { StopEntity(stop: $0) }
    }

    func suggestedEntities() async throws -> [StopEntity] {
        WidgetStore.stops.map { StopEntity(stop: $0) }
    }

    func defaultResult() async -> StopEntity? {
        WidgetStore.stops.first.map { StopEntity(stop: $0) }
    }
}

// MARK: - Réglages

/// Nom du type et du paramètre conservés d'avant la refonte : les réglages des widgets déjà posés restent lus.
struct NextDeparturesConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Prochains passages"
    static var description = IntentDescription("Un arrêt, une ligne, un sens : les prochains passages en direct.")

    @Parameter(title: "Arrêt")
    var selectedStop: StopEntity?

    init() {}
}

struct BoardIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Tableau de départs"
    static var description = IntentDescription("Le prochain départ de plusieurs arrêts. Sans réglage, tous vos arrêts enregistrés, du premier au dernier.")

    @Parameter(title: "Arrêts")
    var stops: [StopEntity]?

    init() {}
}

// MARK: - Chronologies

/// Les passages changent chaque minute sans nouvelle requête : une entrée par minute, calculée
/// depuis les heures absolues, et un rechargement au plus tard cinq minutes plus tard.
enum WidgetTimelines {
    static let refreshInterval: TimeInterval = 5 * 60
    static let minutesCovered = 30
    /// Un passage reste affiché trente secondes après son heure.
    static let pastTolerance: TimeInterval = 30

    /// Maintenant, puis chaque minute pleine.
    static func minuteDates(from now: Date) -> [Date] {
        var dates = [now]
        var next = Calendar.current.dateInterval(of: .minute, for: now)?.end ?? now.addingTimeInterval(60)
        for _ in 0..<minutesCovered {
            dates.append(next)
            next = next.addingTimeInterval(60)
        }
        return dates
    }

    static func remaining(_ departures: [WidgetDeparture], at date: Date) -> [WidgetDeparture] {
        departures.filter { $0.time >= date.addingTimeInterval(-pastTolerance) }
    }

    /// Au-delà d'une heure avant le premier passage, inutile de recharger toutes les cinq minutes.
    static let quietLead: TimeInterval = 60 * 60
    static let quietMaxInterval: TimeInterval = 6 * 3600

    /// Rechargement : dans cinq minutes, ou dès que la liste s'épuise ; quand le premier passage est
    /// loin (fin de service, lendemain), une heure avant celui-ci au plus tôt, six heures au plus tard.
    static func refreshDate(now: Date, exhaustedAt: Date?, firstDeparture: Date?) -> Date {
        if let exhaustedAt {
            return min(now.addingTimeInterval(refreshInterval), max(exhaustedAt, now.addingTimeInterval(60)))
        }
        if let firstDeparture, firstDeparture.timeIntervalSince(now) > quietLead + refreshInterval {
            return min(firstDeparture.addingTimeInterval(-quietLead), now.addingTimeInterval(quietMaxInterval))
        }
        return now.addingTimeInterval(refreshInterval)
    }
}

struct DeparturesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DeparturesEntry {
        WidgetSamples.departures
    }

    func snapshot(for configuration: NextDeparturesConfigurationIntent, in context: Context) async -> DeparturesEntry {
        if context.isPreview { return WidgetSamples.departures }
        return await timeline(for: configuration, in: context).entries.first ?? .notConfigured()
    }

    func timeline(for configuration: NextDeparturesConfigurationIntent, in context: Context) async -> Timeline<DeparturesEntry> {
        let now = Date()
        // Sans réglage, le premier arrêt enregistré : le widget marche dès qu'un arrêt existe.
        guard let stop = configuration.selectedStop?.stop ?? WidgetStore.stops.first else {
            return Timeline(entries: [.notConfigured(date: now)], policy: .after(now.addingTimeInterval(30 * 60)))
        }
        guard let result = await PassagesService.departures(for: stop, now: now) else {
            return Timeline(entries: [.unavailable(stop: stop, date: now)], policy: .after(now.addingTimeInterval(WidgetTimelines.refreshInterval)))
        }
        var entries: [DeparturesEntry] = []
        var exhaustedAt: Date?
        for date in WidgetTimelines.minuteDates(from: now) {
            let remaining = WidgetTimelines.remaining(result.departures, at: date)
            entries.append(DeparturesEntry(date: date, status: .ready, stop: stop, departures: remaining, fetchedAt: result.fetchedAt, stale: result.stale, theoretical: result.theoretical))
            if remaining.isEmpty {
                exhaustedAt = date
                break
            }
        }
        let refresh = WidgetTimelines.refreshDate(now: now, exhaustedAt: exhaustedAt, firstDeparture: result.departures.first?.time)
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

struct BoardProvider: AppIntentTimelineProvider {
    private static let maxStops = 8

    func placeholder(in context: Context) -> BoardEntry {
        WidgetSamples.board
    }

    func snapshot(for configuration: BoardIntent, in context: Context) async -> BoardEntry {
        if context.isPreview { return WidgetSamples.board }
        return await timeline(for: configuration, in: context).entries.first ?? .notConfigured()
    }

    func timeline(for configuration: BoardIntent, in context: Context) async -> Timeline<BoardEntry> {
        let now = Date()
        let chosen = configuration.stops?.map(\.stop) ?? []
        let stops = Array((chosen.isEmpty ? WidgetStore.stops : chosen).prefix(Self.maxStops))
        guard !stops.isEmpty else {
            return Timeline(entries: [.notConfigured(date: now)], policy: .after(now.addingTimeInterval(30 * 60)))
        }
        // Tous les quais en parallèle : l'attente est celle du plus lent, pas la somme.
        let results = await withTaskGroup(of: (Int, PassagesService.Result?).self) { group in
            for (index, stop) in stops.enumerated() {
                group.addTask { (index, await PassagesService.departures(for: stop, now: now)) }
            }
            var collected = [PassagesService.Result?](repeating: nil, count: stops.count)
            for await (index, result) in group { collected[index] = result }
            return collected
        }
        var entries: [BoardEntry] = []
        var exhaustedAt: Date?
        for date in WidgetTimelines.minuteDates(from: now) {
            let rows = zip(stops, results).map { stop, result in
                BoardRow(stop: stop, departures: WidgetTimelines.remaining(result?.departures ?? [], at: date), failed: result == nil)
            }
            entries.append(BoardEntry(date: date, status: .ready, rows: rows, fetchedAt: now))
            if rows.allSatisfy({ $0.departures.isEmpty }) {
                exhaustedAt = date
                break
            }
        }
        let firstDeparture = results.compactMap { $0?.departures.first?.time }.min()
        let refresh = WidgetTimelines.refreshDate(now: now, exhaustedAt: exhaustedAt, firstDeparture: firstDeparture)
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

// MARK: - Widgets

struct DeparturesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.departures.rawValue, intent: NextDeparturesConfigurationIntent.self, provider: DeparturesProvider()) { entry in
            DeparturesEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetKind.departures.title)
        .description(WidgetKind.departures.summary)
        .supportedFamilies(WidgetKind.departures.families)
    }
}

private struct DeparturesEntryView: View {
    let entry: DeparturesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        DeparturesWidgetView(entry: entry, family: family)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL((entry.stop.map { WidgetLink.stop($0.stopId) } ?? .widgets).url)
    }
}

struct BoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.board.rawValue, intent: BoardIntent.self, provider: BoardProvider()) { entry in
            BoardEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetKind.board.title)
        .description(WidgetKind.board.summary)
        .supportedFamilies(WidgetKind.board.families)
    }
}

private struct BoardEntryView: View {
    let entry: BoardEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BoardWidgetView(entry: entry, family: family)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(WidgetLink.widgets.url)
    }
}

#Preview("Passages, petit", as: .systemSmall) {
    DeparturesWidget()
} timeline: {
    WidgetSamples.departures
    DeparturesEntry.notConfigured()
}

#Preview("Passages, moyen", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    WidgetSamples.departures
}

#Preview("Tableau, grand", as: .systemLarge) {
    BoardWidget()
} timeline: {
    WidgetSamples.board
}
