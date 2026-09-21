import SwiftUI
import WidgetKit

// MARK: - Chronologie

/// Aucun réglage : le widget suit les lignes auxquelles l'application est abonnée.
struct TrafficProvider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 15 * 60
    private static let idleInterval: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> TrafficEntry {
        WidgetSamples.traffic
    }

    func getSnapshot(in context: Context, completion: @escaping (TrafficEntry) -> Void) {
        if context.isPreview {
            completion(WidgetSamples.traffic)
            return
        }
        Task { completion(await Self.entry(now: Date())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrafficEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = await Self.entry(now: now)
            let delay = entry.status == .notConfigured ? Self.idleInterval : Self.refreshInterval
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(delay))))
        }
    }

    private static func entry(now: Date) async -> TrafficEntry {
        let subscribed = WidgetStore.subscribedLines
        guard !subscribed.isEmpty else { return .notConfigured(date: now) }
        guard let result = await AlertsService.traffic(subscribed: subscribed, now: now) else {
            return TrafficEntry(date: now, status: .unavailable, subscribed: subscribed, disrupted: [], networkMajor: 0, fetchedAt: nil, stale: false)
        }
        return TrafficEntry(
            date: now, status: .ready, subscribed: subscribed,
            disrupted: result.disrupted, networkMajor: result.networkMajor,
            fetchedAt: result.fetchedAt, stale: result.stale
        )
    }
}

// MARK: - Widget

struct TrafficWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.traffic.rawValue, provider: TrafficProvider()) { entry in
            TrafficEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetKind.traffic.title)
        .description(WidgetKind.traffic.summary)
        .supportedFamilies(WidgetKind.traffic.families)
    }
}

private struct TrafficEntryView: View {
    let entry: TrafficEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        TrafficWidgetView(entry: entry, family: family)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(WidgetLink.traffic.url)
    }
}

#Preview("Trafic, petit", as: .systemSmall) {
    TrafficWidget()
} timeline: {
    WidgetSamples.traffic
    WidgetSamples.trafficCalm
    TrafficEntry.notConfigured()
}

#Preview("Trafic, moyen", as: .systemMedium) {
    TrafficWidget()
} timeline: {
    WidgetSamples.traffic
    WidgetSamples.trafficCalm
}
