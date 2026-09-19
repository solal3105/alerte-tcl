import SwiftUI
import UIKit

/// Couleurs des widgets : les jetons publiés par l'application (`AppColors`, module partagé).
///
/// Tant que l'application n'a jamais été lancée, la palette documentée dans DESIGN.md sert de
/// secours ; c'est le seul endroit où elle est recopiée.
enum WidgetTheme {
    private static let tokens: WidgetThemeTokens = WidgetStore.theme ?? .documented

    static var accent: Color { color(tokens.accent) }
    static var success: Color { color(tokens.success) }
    static var warning: Color { color(tokens.warning) }
    static var error: Color { color(tokens.error) }
    static var neutral: Color { color(tokens.neutral) }
    static var neutralFill: Color { color(tokens.neutralFill) }
    static var neutralBorder: Color { color(tokens.neutralBorder) }
    static var velov: Color { color(tokens.velov) }

    /// Disponibilité d'un parking ou d'une station : gris, vert, orange, rouge.
    static func availability(_ level: WidgetAvailability) -> Color {
        switch level {
        case .unknown: neutral
        case .good: success
        case .medium: warning
        case .low: error
        }
    }

    static func severity(_ severity: WidgetSeverity) -> Color {
        switch severity {
        case .major: error
        case .disruption: warning
        case .info: accent
        }
    }

    /// Avancement d'un chantier (0 à 100 %), du rouge au vert en onze paliers.
    static func worksProgress(percent: Double) -> Color {
        let index = min(10, max(0, Int(percent / 10)))
        return Color(hex: tokens.worksProgress[index])
    }

    private static func color(_ themed: WidgetThemeTokens.Themed) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? themed.dark : themed.light))
        })
    }
}

extension WidgetThemeTokens {
    /// Palette de DESIGN.md, utilisée seulement avant la première publication par l'application.
    static let documented = WidgetThemeTokens(
        accent: Themed(light: "#1565C0", dark: "#0A84FF"),
        success: Themed(light: "#2E7D32", dark: "#66BB6A"),
        warning: Themed(light: "#EF6C00", dark: "#FFA726"),
        error: Themed(light: "#D32F2F", dark: "#EF5350"),
        neutral: Themed(light: "#8E8E93", dark: "#98989D"),
        neutralFill: Themed(light: "#E5E5EA", dark: "#3A3A3C"),
        neutralBorder: Themed(light: "#C7C7CC", dark: "#48484A"),
        velov: Themed(light: "#C62828", dark: "#EF5350"),
        worksProgress: ["#DC2626", "#EF4444", "#F97316", "#FB923C", "#FBBF24", "#EAB308", "#CA8A04", "#84CC16", "#65A30D", "#22C55E", "#16A34A"]
    )
}

/// Niveau de disponibilité, commun aux parkings et aux stations Vélo'v.
enum WidgetAvailability: Codable, Hashable {
    case unknown, good, medium, low
}

/// Sévérité d'une alerte trafic, dans l'ordre de gravité.
enum WidgetSeverity: Int, Codable, Hashable, Comparable {
    case major = 0
    case disruption = 1
    case info = 2

    static func < (lhs: WidgetSeverity, rhs: WidgetSeverity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .major: "Perturbation majeure"
        case .disruption: "Perturbation"
        case .info: "Information"
        }
    }
}

/// Palette officielle des lignes, relue depuis le JSON que l'application enregistre
/// (même format que `LinePalette.encode()` côté Kotlin). Ligne inconnue : badge neutre.
enum WidgetLinePalette {
    private struct Pair: Decodable {
        let backgroundHex: String
        let textHex: String
    }

    private static let palette: [String: Pair] = {
        guard let encoded = AppGroup.defaults?.string(forKey: AppGroup.linePaletteKey),
              let data = encoded.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Pair].self, from: data) else { return [:] }
        return decoded
    }()

    /// Même clé que `TimetableKeys.keyFor` : majuscules, lettres et chiffres ASCII seulement.
    static func key(for line: String) -> String {
        String(line.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    static func background(for line: String) -> Color {
        palette[key(for: line)].map { Color(hex: $0.backgroundHex) } ?? WidgetTheme.neutralFill
    }

    static func text(for line: String) -> Color {
        palette[key(for: line)].map { Color(hex: $0.textHex) } ?? .primary
    }

    /// Liseré quand le fond est clair (luminance au-delà de 0,85), comme `LineColors.needsBorder`.
    static func needsBorder(for line: String) -> Bool {
        guard let pair = palette[key(for: line)] else { return true }
        let clean = pair.backgroundHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return false }
        let r = Double((value >> 16) & 0xFF), g = Double((value >> 8) & 0xFF), b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.85
    }
}

/// Badge de ligne des widgets : la forme de la charte, un carré aux coins arrondis à 20 %,
/// texte en graisse maximale, liseré discret sur fond clair.
struct WidgetLineBadge: View {
    let line: String
    var size: CGFloat = 32

    var body: some View {
        Text(line)
            .font(.system(size: size * (line.count > 2 ? 0.30 : 0.38), weight: .black, design: .rounded))
            .foregroundStyle(WidgetLinePalette.text(for: line))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.horizontal, 3)
            .frame(width: size, height: size)
            .background(WidgetLinePalette.background(for: line), in: RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .stroke(WidgetTheme.neutralBorder, lineWidth: WidgetLinePalette.needsBorder(for: line) ? 1 : 0)
            )
    }
}

/// Mode d'une ligne d'après son nom, seulement pour choisir un pictogramme (la règle du module
/// partagé pour une ligne absente de l'index des fiches horaires).
enum WidgetTransportMode {
    case metro, funicular, tram, bus, navigone

    static func of(line: String) -> WidgetTransportMode {
        let u = line.uppercased()
        if u.hasPrefix("M") && u.count <= 3 { return .metro }
        if ["A", "B", "C", "D"].contains(u) { return .metro }
        if u.hasPrefix("TB") { return .tram }
        if u.count == 2, u.first == "T", u.last?.isNumber == true { return .tram }
        if u.hasPrefix("F") && u.count <= 3 { return .funicular }
        if u == "RHONEXPRESS" { return .tram }
        if u.hasPrefix("NAVI") || u == "7601" || u == "N1" { return .navigone }
        return .bus
    }

    var symbol: String {
        switch self {
        case .metro: "train.side.front.car"
        case .funicular: "cablecar.fill"
        case .tram: "tram.fill"
        case .bus: "bus.fill"
        case .navigone: "ferry.fill"
        }
    }
}
