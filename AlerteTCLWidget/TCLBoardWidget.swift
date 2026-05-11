//
//  TCLBoardWidget.swift
//  AlerteTCLWidget
//
//  Reproduction fidèle du panneau d'affichage « Prochain Passage » TCL
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Board Colors

private let tclGold  = Color(red: 0.91, green: 0.76, blue: 0.04)
private let ledGreen = Color(red: 0.20, green: 0.92, blue: 0.20)
private let ledAmber = Color(red: 1.00, green: 0.56, blue: 0.00)
private let boardBg  = Color(red: 0.04, green: 0.04, blue: 0.04)

// MARK: - Line Badge

private struct TCLLineBadge: View {
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(WidgetLineColorHelper.backgroundColor(for: name))
                .frame(width: size, height: size)
            Text(name)
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundColor(WidgetLineColorHelper.textColor(for: name))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
    }
}

// MARK: - Board Row (small)

private struct TCLBoardRow: View {
    let label: String
    let passage: WidgetPassage?
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 54, alignment: .leading)
                .padding(.leading, 12)

            Text(": ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color.opacity(0.75))

            if let p = passage {
                Text(p.smartDelay)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Text("—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(color.opacity(0.25))
            }

            Spacer(minLength: 6)

            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(passage != nil ? color : color.opacity(0.18))
                .padding(.trailing, 12)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Board Row (medium) — colonne horaire à gauche comme le vrai panneau

private struct MediumBoardRow: View {
    let scheduledTime: String? // heure théorique affichée en vert sur la 1ère ligne
    let label: String
    let passage: WidgetPassage?
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            // Colonne horaire (verte, style "13:36" sur le vrai panneau)
            Text(scheduledTime ?? "     ")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(scheduledTime != nil ? ledGreen : .clear)
                .frame(width: 42, alignment: .leading)
                .padding(.leading, 13)

            // Label
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 56, alignment: .leading)

            Text(": ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color.opacity(0.75))

            // Délai
            if let p = passage {
                Text(p.smartDelay)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(color.opacity(0.25))
            }

            Spacer(minLength: 6)

            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(passage != nil ? color : color.opacity(0.18))
                .padding(.trailing, 14)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Separator

private var boardSeparator: some View {
    Rectangle()
        .fill(Color.white.opacity(0.07))
        .frame(height: 1)
}

// MARK: - Unconfigured

private struct TCLBoardUnconfigured: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("ARRÊT NON CONFIGURÉ")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(ledAmber.opacity(0.7))
            Text("Maintenez pour configurer")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(ledGreen.opacity(0.45))
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Small Board

struct TCLBoardSmallView: View {
    let entry: NextDeparturesEntry
    private var icon: String { TCLBoardWidget.vehicleIcon(for: entry.lineName) }

    var body: some View {
        VStack(spacing: 0) {

            // ── Barre dorée
            HStack(spacing: 7) {
                TCLLineBadge(name: entry.lineName, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.direction)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(entry.stopName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(tclGold)

            // ── Écran LED
            VStack(spacing: 0) {
                Spacer()

                if entry.error == .noStopSelected {
                    TCLBoardUnconfigured()
                } else {
                    TCLBoardRow(
                        label: "Prochain",
                        passage: entry.passages.first,
                        icon: icon,
                        color: ledGreen
                    )
                    boardSeparator
                    TCLBoardRow(
                        label: "Suivant",
                        passage: entry.passages.count > 1 ? entry.passages[1] : nil,
                        icon: icon,
                        color: ledAmber
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(boardBg)
    }
}

// MARK: - Medium Board

struct TCLBoardMediumView: View {
    let entry: NextDeparturesEntry
    private var icon: String { TCLBoardWidget.vehicleIcon(for: entry.lineName) }

    var body: some View {
        VStack(spacing: 0) {

            // ── Barre dorée
            HStack(spacing: 9) {
                TCLLineBadge(name: entry.lineName, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.direction)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("arrêt \(entry.stopName)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                if entry.passages.first?.isRealTime == true {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.65))
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(tclGold)

            // ── Écran LED
            VStack(spacing: 0) {
                Spacer()

                if entry.error == .noStopSelected {
                    TCLBoardUnconfigured()
                } else {
                    // Ligne 1 — Prochain (colonne horaire verte sur la gauche)
                    MediumBoardRow(
                        scheduledTime: entry.passages.first.flatMap {
                            $0.isRelativeDelay ? $0.time : nil
                        },
                        label: "Prochain",
                        passage: entry.passages.first,
                        icon: icon,
                        color: ledGreen
                    )
                    boardSeparator

                    // Ligne 2 — Suivant
                    MediumBoardRow(
                        scheduledTime: nil,
                        label: "Suivant ",
                        passage: entry.passages.count > 1 ? entry.passages[1] : nil,
                        icon: icon,
                        color: ledAmber
                    )

                    // Ligne 3 — Dans (si disponible)
                    if entry.passages.count > 2 {
                        boardSeparator
                        MediumBoardRow(
                            scheduledTime: nil,
                            label: "Dans    ",
                            passage: entry.passages[2],
                            icon: icon,
                            color: ledAmber.opacity(0.55)
                        )
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(boardBg)
    }
}

// MARK: - Entry View

private struct TCLBoardEntryView: View {
    let entry: NextDeparturesEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            TCLBoardMediumView(entry: entry)
        default:
            TCLBoardSmallView(entry: entry)
        }
    }
}

// MARK: - Widget

struct TCLBoardWidget: Widget {
    let kind: String = "TCLBoardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NextDeparturesConfigurationIntent.self,
            provider: NextDeparturesProvider()
        ) { entry in
            TCLBoardEntryView(entry: entry)
                .containerBackground(boardBg, for: .widget)
        }
        .configurationDisplayName("Panneau TCL")
        .description("Style panneau d'affichage TCL")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }

    static func vehicleIcon(for line: String) -> String {
        let u = line.uppercased()
        if u.hasPrefix("M") || u == "A" || u == "B" || u == "C" || u == "D" { return "tram.fill" }
        if u.hasPrefix("T") { return "tram.fill" }
        return "bus.fill"
    }
}

// MARK: - Previews

#Preview("Panneau Small — C", as: .systemSmall) {
    TCLBoardWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Croix-Rousse",
        lineName: "C",
        direction: "Cuire par Croix-Rousse",
        passages: [
            WidgetPassage(delay: "0 min", time: "13:36", isRealTime: true),
            WidgetPassage(delay: "8 min", time: "13:44", isRealTime: true)
        ],
        error: nil
    )
}

#Preview("Panneau Small — MA", as: .systemSmall) {
    TCLBoardWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Bellecour",
        lineName: "MA",
        direction: "Vaulx-en-Velin La Soie",
        passages: [
            WidgetPassage(delay: "3 min", time: "14:33", isRealTime: true),
            WidgetPassage(delay: "11 min", time: "14:41", isRealTime: true)
        ],
        error: nil
    )
}

#Preview("Panneau Medium — MA", as: .systemMedium) {
    TCLBoardWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Bellecour",
        lineName: "MA",
        direction: "Vaulx-en-Velin La Soie",
        passages: [
            WidgetPassage(delay: "2 min", time: "14:32", isRealTime: true),
            WidgetPassage(delay: "9 min", time: "14:39", isRealTime: true),
            WidgetPassage(delay: "17 min", time: "14:47", isRealTime: false)
        ],
        error: nil
    )
}

#Preview("Panneau Medium — T1", as: .systemMedium) {
    TCLBoardWidget()
} timeline: {
    NextDeparturesEntry(
        date: .now,
        configuration: NextDeparturesConfigurationIntent(),
        stopName: "Part-Dieu",
        lineName: "T1",
        direction: "IUT Feyssine",
        passages: [
            WidgetPassage(delay: "0 min", time: "14:30", isRealTime: true),
            WidgetPassage(delay: "7 min", time: "14:37", isRealTime: true),
            WidgetPassage(delay: "14 min", time: "14:44", isRealTime: true)
        ],
        error: nil
    )
}
