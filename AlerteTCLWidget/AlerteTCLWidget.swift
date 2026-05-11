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

    private var occupancyRate: Double {
        guard let spots = entry.availableSpots,
              let total = entry.totalCapacity,
              total > 0 else { return 0 }
        return Double(total - spots) / Double(total)
    }

    private var availabilityRate: Double { 1 - occupancyRate }

    private var occupancyColor: Color {
        switch occupancyRate {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    var body: some View {
        if let spots = entry.availableSpots, let total = entry.totalCapacity {
            if family == .systemMedium {
                mediumContent(spots: spots, total: total)
            } else {
                smallContent(spots: spots, total: total)
            }
        } else if entry.parkingId.isEmpty {
            emptyState
        } else {
            errorState
        }
    }

    // MARK: - Small

    private func smallContent(spots: Int, total: Int) -> some View {
        VStack(spacing: 0) {
            // ── Nom (2 lignes max, scale down si besoin)
            HStack(spacing: 5) {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 16)
                Text(entry.parkingName)
                    .font(.system(size: 11, weight: .bold))
                    .minimumScaleFactor(0.65)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()

            // ── Jauge + nombre
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: occupancyRate)
                    .stroke(occupancyColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(spots)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(occupancyColor)
                    Text("/ \(total)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // ── Heure de mise à jour
            HStack(spacing: 3) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 8, weight: .medium))
                Text(entry.date, style: .time)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Medium

    private func mediumContent(spots: Int, total: Int) -> some View {
        HStack(spacing: 0) {
            // ── Gauche : nom + méta
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "parkingsign.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("P+R")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }

                Spacer().frame(height: 8)

                Text(entry.parkingName)
                    .font(.system(size: 14, weight: .bold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(occupancyColor)
                            .frame(width: 6, height: 6)
                        Text("\(Int(availabilityRate * 100))% libre")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8, weight: .medium))
                        Text(entry.date, style: .time)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── Droite : jauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 11)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: occupancyRate)
                    .stroke(occupancyColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(spots)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(occupancyColor)
                    Text("/ \(total)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Empty / Error

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "parkingsign.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.blue)
            VStack(spacing: 4) {
                Text("Parking TCL")
                    .font(.system(size: 14, weight: .bold))
                Text("Dans AlerteTCL, appuyez sur\nun parking pour l'ajouter au widget")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(14)
    }

    private var errorState: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text(entry.parkingName)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            Text("Données indisponibles")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 6)

            Spacer()
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
        .contentMarginsDisabled()
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

