import WidgetKit
import SwiftUI
import AppIntents

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
        // Rafraîchir toutes les 5 minutes pour les places de parking
        let nextUpdate = Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        return timeline
    }
    
    private func fetchParkingData(for configuration: ParkingWidgetConfigurationIntent) async -> ParkingWidgetEntry {
        let parkingName = configuration.selectedParking?.name ?? "Aucun parking"
        let parkingId = configuration.selectedParking?.id ?? ""
        
        var availableSpots: Int? = nil
        
        // Récupérer les places disponibles temps réel si un parking est sélectionné
        if !parkingId.isEmpty {
            availableSpots = await WidgetParkingService.fetchParking(withId: parkingId)
        }
        
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

// MARK: - Parking Widget View

struct ParkingWidgetEntryView : View {
    var entry: ParkingWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ParkingWidgetContentView(entry: entry, family: family)
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
    ParkingWidget()
} timeline: {
    ParkingWidgetEntry(
        date: .now,
        configuration: ParkingWidgetConfigurationIntent(),
        parkingName: "Parking Part-Dieu",
        availableSpots: 42
    )
}

