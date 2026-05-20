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
        // Generate entries every minute for 15 minutes so countdowns stay
        // accurate even when iOS delays the scheduled widget refresh.
        let calendar = Calendar.current
        let now = Date()
        var entries: [NextDeparturesEntry] = []
        for minuteOffset in 0..<60 {
            guard let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: now) else { continue }
            let decayed = base.passages.compactMap { passage -> WidgetPassage? in
                guard let minutes = passage.delayMinutes else { return passage }
                let remaining = minutes - minuteOffset
                // Délai écoulé : bascule sur l'heure absolue pour que l'entrée
                // ne soit jamais vide pendant un retard de rafraîchissement iOS.
                if remaining < 0 {
                    return WidgetPassage(delay: passage.time, time: passage.time, isRealTime: false)
                }
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
        // Refresh toutes les 5 min : adapté aux données temps-réel de transport.
        // Le budget WidgetKit (~40-70 refreshes/jour) permet cette fréquence.
        // Les 60 entrées (1 par minute) couvrent 1 heure si iOS retarde exceptionnellement.
        let nextUpdate = now.addingTimeInterval(5 * 60)
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

        // Résoudre le nom du terminus depuis le stockage local (enregistré à l'ajout)
        let terminusRaw = Self.terminusName(forStopId: stopId, lineName: lineName, direction: direction)
        let directionDisplay = terminusRaw.isEmpty ? "—" : terminusRaw
        
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
                direction: directionDisplay,
                passages: passages,
                error: passages.isEmpty ? .noPassages : nil
            )
        } catch {
            return NextDeparturesEntry(
                date: Date(),
                configuration: configuration,
                stopName: stopName,
                lineName: lineName,
                direction: directionDisplay,
                passages: [],
                error: .networkError
            )
        }
    }

    private static func terminusName(forStopId stopId: Int, lineName: String, direction: String) -> String {
        let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
        let savedStops = defaults?.array(forKey: "widgetStops") as? [[String: Any]] ?? []
        let id = "\(stopId)-\(lineName)-\(direction)"
        return savedStops.first(where: { ($0["id"] as? String) == id })?["terminusName"] as? String ?? ""
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

    /// True si le délai est exprimé en minutes restantes (vs heure absolue)
    var isRelativeDelay: Bool { delayMinutes != nil }

    /// Format principal : minutes restantes ou heure absolue, jamais les deux
    var smartDelay: String {
        if let minutes = delayMinutes {
            return minutes == 0 ? "À l'approche" : "\(minutes) min"
        }
        return time
    }

    /// Format compact pour le petit widget : "X'" ou "HH:mm"
    var compactDelay: String {
        if let minutes = delayMinutes {
            return minutes == 0 ? "~0'" : "\(minutes)'"
        }
        return time
    }

    /// Couleur d'urgence basée sur le délai ; fallback si délai absolu
    func urgencyColor(fallback: Color) -> Color {
        guard let minutes = delayMinutes else { return fallback }
        if minutes <= 2 { return .red }
        if minutes <= 5 { return .orange }
        return fallback
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

    private var lineColor: Color { WidgetLineColorHelper.backgroundColor(for: entry.lineName) }
    private var textColor: Color { WidgetLineColorHelper.textColor(for: entry.lineName) }

    var body: some View {
        if let error = entry.error {
            ErrorStateView(error: error, lineName: entry.lineName)
        } else {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header : ligne + direction
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.lineName)
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(lineColor)
                            .clipShape(Capsule())

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 7, weight: .bold))
                            Text(entry.direction)
                                .font(.system(size: 9))
                                .lineLimit(2)
                        }
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    if entry.passages.first?.isRealTime == true {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

                // ── Passages
                VStack(spacing: 0) {
                    ForEach(Array(entry.passages.prefix(3).enumerated()), id: \.offset) { index, passage in
                        HStack(spacing: 6) {
                            Text(passage.compactDelay)
                                .font(.system(size: index == 0 ? 26 : 14, weight: index == 0 ? .bold : .semibold, design: .rounded))
                                .foregroundColor(passage.urgencyColor(fallback: index == 0 ? lineColor : .primary))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if passage.isRelativeDelay {
                                Text(passage.time)
                                    .font(.system(size: index == 0 ? 11 : 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, index == 0 ? 5 : 3)
                        if index < min(entry.passages.count - 1, 2) {
                            Divider().padding(.leading, 12)
                        }
                    }
                }

                Spacer(minLength: 0)

                // ── Footer : arrêt
                Text(entry.stopName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: NextDeparturesEntry

    private var lineColor: Color { WidgetLineColorHelper.backgroundColor(for: entry.lineName) }
    private var textColor: Color { WidgetLineColorHelper.textColor(for: entry.lineName) }

    var body: some View {
        if let error = entry.error {
            ErrorStateView(error: error, lineName: entry.lineName)
        } else {
            VStack(spacing: 0) {

                // ── Header : badge + arrêt + direction
                HStack(spacing: 10) {
                    Text(entry.lineName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(lineColor)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.stopName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(lineColor)
                            Text(entry.direction)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if entry.passages.first?.isRealTime == true {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("Temps réel")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(lineColor.opacity(0.08))

                // ── Passages
                VStack(spacing: 0) {
                    ForEach(Array(entry.passages.prefix(4).enumerated()), id: \.offset) { index, passage in
                        MediumPassageRow(passage: passage, isFirst: index == 0, lineColor: lineColor)
                        if index < min(entry.passages.count - 1, 3) {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: NextDeparturesEntry

    private var lineColor: Color { WidgetLineColorHelper.backgroundColor(for: entry.lineName) }
    private var textColor: Color { WidgetLineColorHelper.textColor(for: entry.lineName) }

    var body: some View {
        if let error = entry.error {
            ErrorStateView(error: error, lineName: entry.lineName)
        } else {
            VStack(spacing: 0) {

                // ── Header
                HStack(spacing: 12) {
                    Text(entry.lineName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(lineColor)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.stopName)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(lineColor)
                            Text(entry.direction)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if entry.passages.first?.isRealTime == true {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 7, height: 7)
                            Text("Temps réel")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(lineColor.opacity(0.09))

                // ── Premier passage mis en avant
                if let first = entry.passages.first {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prochain")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(first.smartDelay)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(first.urgencyColor(fallback: lineColor))
                        }
                        Spacer()
                        if first.isRelativeDelay {
                            Text(first.time)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(lineColor.opacity(0.05))
                }

                // ── Passages suivants
                VStack(spacing: 0) {
                    ForEach(Array(entry.passages.dropFirst().prefix(4).enumerated()), id: \.offset) { index, passage in
                        LargePassageRow(passage: passage, lineColor: lineColor)
                        if index < min(entry.passages.count - 2, 3) {
                            Divider().padding(.leading, 18)
                        }
                    }
                }

                Spacer(minLength: 0)

                // ── Footer
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                    Text(entry.date, style: .time)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Passage Row Components

/// Utilisé dans le medium widget
struct MediumPassageRow: View {
    let passage: WidgetPassage
    let isFirst: Bool
    let lineColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(passage.isRealTime ? Color.green : Color.gray.opacity(0.2))
                .frame(width: 6, height: 6)

            Text(passage.smartDelay)
                .font(.system(size: isFirst ? 17 : 14, weight: isFirst ? .bold : .semibold, design: .rounded))
                .foregroundColor(passage.urgencyColor(fallback: isFirst ? lineColor : .primary))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if passage.isRelativeDelay {
                Text(passage.time)
                    .font(.system(size: isFirst ? 12 : 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, isFirst ? 7 : 6)
        .padding(.horizontal, 14)
    }
}

/// Utilisé dans le large widget (passages secondaires)
struct LargePassageRow: View {
    let passage: WidgetPassage
    let lineColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(passage.isRealTime ? Color.green : Color.gray.opacity(0.25))
                .frame(width: 7, height: 7)

            Text(passage.smartDelay)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(passage.urgencyColor(fallback: .primary))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if passage.isRelativeDelay {
                Text(passage.time)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: WidgetPassageError
    let lineName: String

    @Environment(\..widgetFamily) var family
    private var isSmall: Bool { family == .systemSmall }

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
        let iconSize: CGFloat = isSmall ? 20 : 28
        let circleSize: CGFloat = isSmall ? 48 : 72
        return VStack(spacing: isSmall ? 8 : 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: circleSize, height: circleSize)

                Image(systemName: "tram.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: isSmall ? 3 : 6) {
                Text("Aucun arrêt configuré")
                    .font(.system(size: isSmall ? 12 : 15, weight: .bold))

                if !isSmall {
                    Text("Dans AlerteTCL, appuyez sur\nun arrêt sur la carte, puis\nsur \"Ajouter au widget\"")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Ouvrez AlerteTCL\net ajoutez un arrêt")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding(isSmall ? 12 : 16)
    }
    
    private var noPassagesView: some View {
        let circleSize: CGFloat = isSmall ? 44 : 64
        let iconSize: CGFloat = isSmall ? 20 : 28
        return VStack(spacing: isSmall ? 8 : 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: circleSize, height: circleSize)

                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: iconSize))
                    .foregroundColor(.orange)
            }

            VStack(spacing: isSmall ? 3 : 4) {
                Text("Aucun passage")
                    .font(.system(size: isSmall ? 12 : 14, weight: .bold))

                if !isSmall {
                    Text("Aucun passage prévu\nprochainement")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding(isSmall ? 12 : 16)
    }
    
    private var networkErrorView: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 22 || hour < 6
        let icon = isNight ? "moon.zzz.fill" : "wifi.slash"
        let color: Color = isNight ? .indigo : .red
        let title = isNight ? "Serveurs inactifs" : "Données indisponibles"
        let subtitle = isNight ? "Reprise après 6h ☀️" : "Serveur momentanément\nindisponible"
        let circleSize: CGFloat = isSmall ? 44 : 64
        let iconSize: CGFloat = isSmall ? 20 : 28
        return VStack(spacing: isSmall ? 8 : 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: circleSize, height: circleSize)

                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(color)
            }

            VStack(spacing: isSmall ? 3 : 4) {
                Text(title)
                    .font(.system(size: isSmall ? 12 : 14, weight: .bold))

                Text(subtitle)
                    .font(.system(size: isSmall ? 9 : 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(isSmall ? 12 : 16)
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
        .contentMarginsDisabled()
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
