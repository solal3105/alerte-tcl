import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Parking Widget Provider

struct ParkingWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ParkingWidgetEntry {
        ParkingWidgetEntry(
            date: Date(),
            configuration: ParkingWidgetConfigurationIntent(),
            parkingId: "",
            parkingName: "Parking",
            availableSpots: nil,
            totalCapacity: nil
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
        var totalCapacity: Int? = nil
        
        // Récupérer les données temps réel si un parking est sélectionné
        if !parkingId.isEmpty {
            if let parking = await WidgetParkingService.fetchParking(withId: parkingId) {
                availableSpots = parking.placesDisponibles
                totalCapacity = parking.capaciteTotale
            }
        }
        
        return ParkingWidgetEntry(
            date: Date(),
            configuration: configuration,
            parkingId: parkingId,
            parkingName: parkingName,
            availableSpots: availableSpots,
            totalCapacity: totalCapacity
        )
    }
}

struct ParkingWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ParkingWidgetConfigurationIntent
    let parkingId: String
    let parkingName: String
    let availableSpots: Int?
    let totalCapacity: Int?
}

// MARK: - Parking Widget View

struct ParkingWidgetEntryView : View {
    var entry: ParkingWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ParkingWidgetContentView(entry: entry, family: family)
            .widgetURL(URL(string: "alertetcl://parking/\(entry.parkingId)"))
    }
}

struct ParkingWidgetContentView: View {
    let entry: ParkingWidgetEntry
    let family: WidgetFamily
    
    var occupancyRate: Double {
        guard let spots = entry.availableSpots,
              let total = entry.totalCapacity,
              total > 0 else { return 0 }
        return Double(total - spots) / Double(total)
    }
    
    var occupancyColor: Color {
        switch occupancyRate {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        if let spots = entry.availableSpots, let total = entry.totalCapacity {
            VStack(spacing: 0) {
                // Header avec nom du parking
                HStack(spacing: 8) {
                    Image(systemName: "parkingsign.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(entry.parkingName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
                
                // Cercle de progression central
                ZStack {
                    // Cercle de fond
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    // Cercle de progression
                    Circle()
                        .trim(from: 0, to: occupancyRate)
                        .stroke(
                            occupancyColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: occupancyRate)
                    
                    // Texte central
                    VStack(spacing: 2) {
                        Text("\(spots)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(occupancyColor)
                        
                        Text("/ \(total)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Footer avec info et heure
                VStack(spacing: 4) {
                    Text("places disponibles")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                        Text(timeAgo(from: entry.date))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        } else if entry.parkingId.isEmpty {
            // Empty state - Aucun parking sélectionné
            VStack(spacing: 16) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "parkingsign.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 6) {
                    Text("Parking TCL")
                        .font(.system(size: 15, weight: .bold))
                    
                    Text("Maintenez appuyé\npour configurer")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(16)
        } else {
            // État erreur données
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "parkingsign.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(entry.parkingName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Données\nindisponibles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(16)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        
        if minutes < 1 {
            return "À l'instant"
        } else if minutes == 1 {
            return "Il y a 1 min"
        } else if minutes < 60 {
            return "Il y a \(minutes) min"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
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
        parkingId: "test-parking",
        parkingName: "Parking Part-Dieu",
        availableSpots: 42,
        totalCapacity: 150
    )
}

