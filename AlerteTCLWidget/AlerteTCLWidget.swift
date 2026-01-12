import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Stop Widget Provider

struct StopWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StopWidgetEntry {
        StopWidgetEntry(
            date: Date(),
            configuration: StopWidgetConfigurationIntent(),
            stopName: "Part-Dieu",
            passages: []
        )
    }

    func snapshot(for configuration: StopWidgetConfigurationIntent, in context: Context) async -> StopWidgetEntry {
        await fetchStopData(for: configuration)
    }

    func timeline(for configuration: StopWidgetConfigurationIntent, in context: Context) async -> Timeline<StopWidgetEntry> {
        let entry = await fetchStopData(for: configuration)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        return timeline
    }
    
    private func fetchStopData(for configuration: StopWidgetConfigurationIntent) async -> StopWidgetEntry {
        let stopName = configuration.selectedStop?.name ?? "Aucun arrêt"
        let stopId = configuration.selectedStop?.id ?? ""
        
        // TODO: Récupérer les vrais passages depuis l'API
        let passages: [String] = []
        
        return StopWidgetEntry(
            date: Date(),
            configuration: configuration,
            stopName: stopName,
            passages: passages
        )
    }
}

struct StopWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: StopWidgetConfigurationIntent
    let stopName: String
    let passages: [String]
}

// MARK: - Parking Widget Provider

struct ParkingWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ParkingWidgetEntry {
        ParkingWidgetEntry(
            date: Date(),
            configuration: ParkingWidgetConfigurationIntent(),
            parkingName: "Parking",
            availableSpots: nil
        )
    }

    func snapshot(for configuration: ParkingWidgetConfigurationIntent, in context: Context) async -> ParkingWidgetEntry {
        await fetchParkingData(for: configuration)
    }

    func timeline(for configuration: ParkingWidgetConfigurationIntent, in context: Context) async -> Timeline<ParkingWidgetEntry> {
        let entry = await fetchParkingData(for: configuration)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        return timeline
    }
    
    private func fetchParkingData(for configuration: ParkingWidgetConfigurationIntent) async -> ParkingWidgetEntry {
        let parkingName = configuration.selectedParking?.name ?? "Aucun parking"
        let parkingId = configuration.selectedParking?.id ?? ""
        
        // TODO: Récupérer les vraies places depuis l'API
        let availableSpots: Int? = nil
        
        return ParkingWidgetEntry(
            date: Date(),
            configuration: configuration,
            parkingName: parkingName,
            availableSpots: availableSpots
        )
    }
}

struct ParkingWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ParkingWidgetConfigurationIntent
    let parkingName: String
    let availableSpots: Int?
}

// MARK: - Stop Widget View

struct StopWidgetEntryView : View {
    var entry: StopWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        StopWidgetContentView(entry: entry, family: family)
    }
}

// MARK: - Parking Widget View

struct ParkingWidgetEntryView : View {
    var entry: ParkingWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ParkingWidgetContentView(entry: entry, family: family)
    }
}

struct StopWidgetContentView: View {
    let entry: StopWidgetEntry
    let family: WidgetFamily
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bus.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text(entry.stopName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                
                Spacer()
            }
            
            Divider()
            
            if entry.passages.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    
                    Text("Aucun passage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.passages.prefix(family == .systemSmall ? 2 : 4), id: \.self) { passage in
                        Text(passage)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Text("Mis à jour: \(entry.date, style: .time)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct ParkingWidgetContentView: View {
    let entry: ParkingWidgetEntry
    let family: WidgetFamily
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text(entry.parkingName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                
                Spacer()
            }
            
            Spacer()
            
            if let spots = entry.availableSpots {
                VStack(spacing: 8) {
                    Text("\(spots)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(spotsColor(spots))
                    
                    Text("places disponibles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Données indisponibles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Text("Mis à jour: \(entry.date, style: .time)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func spotsColor(_ spots: Int) -> Color {
        if spots > 50 {
            return .green
        } else if spots > 20 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Stop Widget

struct StopWidget: Widget {
    let kind: String = "StopWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StopWidgetConfigurationIntent.self, provider: StopWidgetProvider()) { entry in
            StopWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Arrêt TCL")
        .description("Prochains passages à un arrêt TCL")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Parking Widget

struct ParkingWidget: Widget {
    let kind: String = "ParkingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ParkingWidgetConfigurationIntent.self, provider: ParkingWidgetProvider()) { entry in
            ParkingWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Parking TCL")
        .description("Places disponibles dans un parking")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    StopWidget()
} timeline: {
    StopWidgetEntry(
        date: .now,
        configuration: StopWidgetConfigurationIntent(),
        stopName: "Part-Dieu",
        passages: ["T1 → Debourg - 3min", "C3 → Gare Part-Dieu - 7min"]
    )
}

#Preview(as: .systemSmall) {
    ParkingWidget()
} timeline: {
    ParkingWidgetEntry(
        date: .now,
        configuration: ParkingWidgetConfigurationIntent(),
        parkingName: "Parking Part-Dieu",
        availableSpots: 42
    )
}

