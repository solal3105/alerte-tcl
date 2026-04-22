//
//  NextDeparturesWidget.swift
//  AlerteTCLWidget
//
//  Widget ultra-design pour afficher les prochains passages d'un arrêt
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Provider

struct NextDeparturesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NextDeparturesEntry {
        NextDeparturesEntry(
            date: Date(),
            configuration: NextDeparturesConfigurationIntent(),
            stopName: "Bellecour",
            lineName: "MA",
            direction: "Vaulx-en-Velin",
            passages: [
                WidgetPassage(delay: "2 min", time: "14:32", isRealTime: true),
                WidgetPassage(delay: "8 min", time: "14:38", isRealTime: true),
                WidgetPassage(delay: "15 min", time: "14:45", isRealTime: false)
            ],
            error: nil
        )
    }

    func snapshot(for configuration: NextDeparturesConfigurationIntent, in context: Context) async -> NextDeparturesEntry {
        await fetchData(for: configuration)
    }

    func timeline(for configuration: NextDeparturesConfigurationIntent, in context: Context) async -> Timeline<NextDeparturesEntry> {
        let base = await fetchData(for: configuration)
        // Generate entries every minute for the next 8 minutes so countdowns stay
        // accurate even if the widget isn't refreshed from the network.
        let calendar = Calendar.current
        let now = Date()
        var entries: [NextDeparturesEntry] = []
        for minuteOffset in 0..<8 {
            guard let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: now) else { continue }
            let decayed = base.passages.compactMap { passage -> WidgetPassage? in
                guard let minutes = passage.delayMinutes else { return passage }
                let remaining = minutes - minuteOffset
                guard remaining >= 0 else { return nil }
                return WidgetPassage(
                    delay: remaining == 0 ? "À l'approche" : "\(remaining) min",
                    time: passage.time,
                    isRealTime: passage.isRealTime
                )
            }
            entries.append(NextDeparturesEntry(
                date: entryDate,
                configuration: base.configuration,
                stopName: base.stopName,
                lineName: base.lineName,
                direction: base.direction,
                passages: decayed,
                error: decayed.isEmpty && base.error == nil ? .noPassages : base.error
            ))
        }
        let nextUpdate = now.addingTimeInterval(8 * 60)
        return Timeline(entries: entries, policy: .after(nextUpdate))
    }
    
    private func fetchData(for configuration: NextDeparturesConfigurationIntent) async -> NextDeparturesEntry {
        guard let selectedStop = configuration.selectedStop else {
            return NextDeparturesEntry(
                date: Date(),
                configuration: configuration,
                stopName: "Aucun arrêt",
                lineName: "",
                direction: "",
                passages: [],
                error: .noStopSelected
            )
        }
        
        let stopName = selectedStop.stopName
        let lineName = selectedStop.lineName
        let direction = selectedStop.direction
        let stopId = selectedStop.stopId
        
        // Récupérer les passages
        do {
            let passages = try await WidgetPassageService.fetchPassages(
                stopId: stopId,
                line: lineName,
                direction: direction
            )
            
            return NextDeparturesEntry(
                date: Date(),
                configuration: configuration,
                stopName: stopName,
                lineName: lineName,
                direction: direction,
                passages: passages,
                error: passages.isEmpty ? .noPassages : nil
            )
        } catch {
            return NextDeparturesEntry(
                date: Date(),
                configuration: configuration,
                stopName: stopName,
                lineName: lineName,
                direction: direction,
                passages: [],
                error: .networkError
            )
        }
    }
}

// MARK: - Widget Entry

struct NextDeparturesEntry: TimelineEntry {
    let date: Date
    let configuration: NextDeparturesConfigurationIntent
    let stopName: String
    let lineName: String
    let direction: String
    let passages: [WidgetPassage]
    let error: WidgetPassageError?
}

struct WidgetPassage: Identifiable, Codable {
    var id: String { "\(time)-\(delay)" }
    let delay: String
    let time: String
    let isRealTime: Bool

    var delayMinutes: Int? {
        let cleaned = delay.lowercased()
            .replacingOccurrences(of: " min", with: "")
            .replacingOccurrences(of: "min", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Int(cleaned)
    }

    private enum CodingKeys: String, CodingKey {
        case delay, time, isRealTime
    }
}

enum WidgetPassageError {
    case noStopSelected
    case noPassages
    case networkError
}

// MARK: - Widget View

struct NextDeparturesEntryView: View {
    var entry: NextDeparturesProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: NextDeparturesEntry
    
    private var lineColor: Color {
        WidgetLineColorHelper.backgroundColor(for: entry.lineName)
    }
    
    private var textColor: Color {
        WidgetLineColorHelper.textColor(for: entry.lineName)
    }
    
    var body: some View {
        if let error = entry.error {
            ErrorStateView(error: error, lineName: entry.lineName)
        } else {
            VStack(spacing: 0) {
                // Header avec ligne
                HStack(spacing: 8) {
                    // Badge ligne
                    Text(entry.lineName)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(lineColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Indicateur temps réel
                    if entry.passages.first?.isRealTime == true {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                
                Spacer()
                
                // Prochain passage (grand)
                if let next = entry.passages.first {
                    VStack(spacing: 4) {
                        Text(formatDelay(next.delay))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(delayColor(for: next))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        
                        Text(next.time)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Footer avec direction
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(entry.direction)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }
    
    private func formatDelay(_ delay: String) -> String {
        let cleaned = delay.lowercased()
        if cleaned.contains("min") {
            if let minutes = Int(cleaned.replacingOccurrences(of: " min", with: "").replacingOccurrences(of: "min", with: "").trimmingCharacters(in: .whitespaces)) {
                return "\(minutes)'"
            }
        }
        return delay
    }
    
    private func delayColor(for passage: WidgetPassage) -> Color {
        guard let minutes = passage.delayMinutes else { return .primary }
        if minutes <= 2 { return .red }
        if minutes <= 5 { return .orange }
        return .primary
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: NextDeparturesEntry
    
    private var lineColor: Color {
        WidgetLineColorHelper.backgroundColor(for: entry.lineName)
    }
    
    private var textColor: Color {
        WidgetLineColorHelper.textColor(for: entry.lineName)
    }
    
    var body: some View {
        if let error = entry.error {
            ErrorStateView(error: error, lineName: entry.lineName)
        } else {
            HStack(spacing: 0) {
                // Partie gauche - Info arrêt
                VStack(alignment: .leading, spacing: 8) {
                    // Badge ligne
                    Text(entry.lineName)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(lineColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Nom arrêt
                    Text(entry.stopName)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    // Direction
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(lineColor)
                        
                        Text(entry.direction)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Indicateur temps réel
                    if entry.passages.first?.isRealTime == true {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Temps réel")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Séparateur
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                    .padding(.vertical, 16)
                
                // Partie droite - Prochains passages
                VStack(spacing: 8) {
                    ForEach(Array(entry.passages.prefix(3).enumerated()), id: \.offset) { index, passage in
                        PassageRow(passage: passage, isFirst: index == 0, lineColor: lineColor)
                    }
                    
                    if entry.passages.count < 3 {
                        Spacer()
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: NextDeparturesEntry
    
    private var lineColor: Color {
        WidgetLineColorHelper.backgroundColor(for: entry.lineName)
    }
    
    private var textColor: Color {
        WidgetLineColorHelper.textColor(for: entry.lineName)
    }
    
    var body: some View {
        if let error = entry.error {
            ErrorStateView(error: error, lineName: entry.lineName)
        } else {
            VStack(spacing: 0) {
                // Header
                HStack {
                    // Badge ligne
                    Text(entry.lineName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(lineColor)
                        .clipShape(Capsule())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.stopName)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                            Text(entry.direction)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Indicateur temps réel
                    if entry.passages.first?.isRealTime == true {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(20)
                .background(lineColor.opacity(0.1))
                
                // Liste des passages
                VStack(spacing: 0) {
                    ForEach(Array(entry.passages.prefix(5).enumerated()), id: \.offset) { index, passage in
                        LargePassageRow(passage: passage, isFirst: index == 0, lineColor: lineColor)
                        
                        if index < min(entry.passages.count - 1, 4) {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                // Footer avec heure de mise à jour
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text("Mis à jour à \(formatTime(entry.date))")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Passage Row Components

struct PassageRow: View {
    let passage: WidgetPassage
    let isFirst: Bool
    let lineColor: Color
    
    var body: some View {
        HStack {
            // Délai
            Text(formatDelay(passage.delay))
                .font(.system(size: isFirst ? 28 : 18, weight: .bold, design: .rounded))
                .foregroundColor(isFirst ? delayColor : .primary)
                .frame(minWidth: 50, alignment: .leading)
            
            Spacer()
            
            // Heure
            VStack(alignment: .trailing, spacing: 2) {
                Text(passage.time)
                    .font(.system(size: isFirst ? 14 : 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                if passage.isRealTime && isFirst {
                    Text("temps réel")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, isFirst ? 8 : 4)
        .padding(.horizontal, isFirst ? 12 : 8)
        .background(isFirst ? lineColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var delayColor: Color {
        guard let minutes = passage.delayMinutes else { return .primary }
        if minutes <= 2 { return .red }
        if minutes <= 5 { return .orange }
        return lineColor
    }
    
    private func formatDelay(_ delay: String) -> String {
        let cleaned = delay.lowercased()
        if cleaned.contains("min") {
            if let minutes = Int(cleaned.replacingOccurrences(of: " min", with: "").replacingOccurrences(of: "min", with: "").trimmingCharacters(in: .whitespaces)) {
                return "\(minutes)'"
            }
        }
        return delay
    }
}

struct LargePassageRow: View {
    let passage: WidgetPassage
    let isFirst: Bool
    let lineColor: Color
    
    var body: some View {
        HStack {
            // Indicateur temps réel
            Circle()
                .fill(passage.isRealTime ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
            // Délai
            Text(passage.delay)
                .font(.system(size: isFirst ? 24 : 18, weight: .bold, design: .rounded))
                .foregroundColor(isFirst ? delayColor : .primary)
                .frame(minWidth: 80, alignment: .leading)
            
            Spacer()
            
            // Heure
            Text(passage.time)
                .font(.system(size: isFirst ? 16 : 14, weight: .medium))
                .foregroundColor(.secondary)
            
            // Type
            Text(passage.isRealTime ? "R" : "T")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(passage.isRealTime ? .green : .gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(passage.isRealTime ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isFirst ? lineColor.opacity(0.08) : Color.clear)
    }
    
    private var delayColor: Color {
        guard let minutes = passage.delayMinutes else { return lineColor }
        if minutes <= 2 { return .red }
        if minutes <= 5 { return .orange }
        return lineColor
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: WidgetPassageError
    let lineName: String
    
    var body: some View {
        switch error {
        case .noStopSelected:
            emptyStateView
        case .noPassages:
            noPassagesView
        case .networkError:
            networkErrorView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "tram.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text("Prochains passages")
                    .font(.system(size: 15, weight: .bold))
                
                Text("Maintenez appuyé\npour choisir un arrêt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    private var noPassagesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 4) {
                Text("Aucun passage")
                    .font(.system(size: 14, weight: .bold))
                
                Text("Aucun passage prévu\nprochainement")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    private var networkErrorView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 4) {
                Text("Erreur réseau")
                    .font(.system(size: 14, weight: .bold))
                
                Text("Vérifiez votre\nconnexion internet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Widget Definition

struct NextDeparturesWidget: Widget {
    let kind: String = "NextDeparturesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NextDeparturesConfigurationIntent.self,
            provider: NextDeparturesProvider()
        ) { entry in
            NextDeparturesEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prochains passages")
        .description("Affichez les prochains passages d'un arrêt TCL")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NextDeparturesWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Bellecour",
        lineName: "MA",
        direction: "Vaulx-en-Velin La Soie",
        passages: [
            WidgetPassage(delay: "2 min", time: "14:32", isRealTime: true),
            WidgetPassage(delay: "8 min", time: "14:38", isRealTime: true)
        ],
        error: nil
    )
}

#Preview("Medium", as: .systemMedium) {
    NextDeparturesWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Bellecour",
        lineName: "T1",
        direction: "IUT Feyssine",
        passages: [
            WidgetPassage(delay: "3 min", time: "14:33", isRealTime: true),
            WidgetPassage(delay: "9 min", time: "14:39", isRealTime: true),
            WidgetPassage(delay: "15 min", time: "14:45", isRealTime: false)
        ],
        error: nil
    )
}

#Preview("Large", as: .systemLarge) {
    NextDeparturesWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Part-Dieu",
        lineName: "MB",
        direction: "Charpennes",
        passages: [
            WidgetPassage(delay: "1 min", time: "14:31", isRealTime: true),
            WidgetPassage(delay: "4 min", time: "14:34", isRealTime: true),
            WidgetPassage(delay: "7 min", time: "14:37", isRealTime: true),
            WidgetPassage(delay: "10 min", time: "14:40", isRealTime: false),
            WidgetPassage(delay: "13 min", time: "14:43", isRealTime: false)
        ],
        error: nil
    )
}

#Preview("No Stop Selected", as: .systemSmall) {
    NextDeparturesWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "",
        lineName: "",
        direction: "",
        passages: [],
        error: .noStopSelected
    )
}
