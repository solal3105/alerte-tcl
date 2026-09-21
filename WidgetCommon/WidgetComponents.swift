import SwiftUI
import WidgetKit

// MARK: - Règles communes
//
// Un widget n'a pas de titre : son contenu dit ce qu'il montre. Ce qu'on lit d'abord est le chiffre
// du moment, puis ce qu'il concerne (un arrêt, un parking, une station), puis rien d'autre. Une
// information n'est écrite qu'une fois, et les unités sont les plus courtes possibles.

/// Compteur secondaire : un pictogramme et un chiffre sur une pastille, sans un mot (un vélo, un
/// éclair, un P disent mieux et plus court que « vélos », « électriques », « places »).
struct WidgetStat: View {
    let symbol: String
    let value: String
    var color: Color = .primary
    var width: CGFloat? = nil

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .widgetAccentable()
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: width ?? .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - État du trafic

extension TrafficEntry {
    /// Vert quand tout roule, orange perturbé, rouge dès une alerte majeure.
    var tone: Color {
        if hasMajor { return WidgetTheme.error }
        if !disrupted.isEmpty { return WidgetTheme.warning }
        return WidgetTheme.success
    }

    var symbol: String {
        if hasMajor { return "exclamationmark.octagon.fill" }
        if !disrupted.isEmpty { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }
}

/// Étiquette en petites capitales espacées, comme sur les panneaux de quai. Une seule par widget.
struct WidgetLabel: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Capsule d'un chiffre secondaire : « 24 min », ou un pictogramme et un nombre.
struct WidgetChip: View {
    let text: String
    var symbol: String? = nil
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(color == .primary ? 0.07 : 0.14), in: Capsule())
    }
}

/// Barre de remplissage en segments, comme les panneaux de places libres d'un parking.
struct WidgetSegmentedBar: View {
    let fraction: Double
    let color: Color
    var segments: Int = 14
    var height: CGFloat = 7

    private var filled: Int {
        max(0, min(segments, Int((Double(segments) * min(1, max(0, fraction))).rounded())))
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(index < filled ? color : color.opacity(0.16))
            }
        }
        .frame(height: height)
    }
}

/// Trait de séparation d'un tableau de départs : présent, mais presque invisible.
struct WidgetRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }
}

// MARK: - Mention de fraîcheur

/// Une seule ligne, en bas, et seulement quand il y a quelque chose à dire : des données qui datent,
/// ou des horaires théoriques au lieu du direct. Quand tout est frais, le widget ne dit rien.
struct WidgetStamp: View {
    let fetchedAt: Date?
    var now: Date = Date()
    var stale: Bool = false
    var note: String? = nil

    /// Au-delà de ce délai, l'heure des données est écrite pour ne pas les faire passer pour du direct.
    private static let showAfter: TimeInterval = 15 * 60

    private var age: String? {
        guard let fetchedAt, stale || now.timeIntervalSince(fetchedAt) > Self.showAfter else { return nil }
        return "données de \(WidgetDeparture.timeFormatter.string(from: fetchedAt))"
    }

    private var line: String? {
        let parts = [age, note].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        if let line {
            Text(line)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(stale ? WidgetTheme.warning : Color.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Point de temps réel

/// Point vert des passages suivis en direct, comme dans la fiche d'un arrêt.
struct WidgetLiveDot: View {
    var body: some View {
        Circle()
            .fill(WidgetTheme.success)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Messages

/// État sans donnée (réglage manquant, réseau injoignable) : un pictogramme, une phrase, une action.
struct WidgetMessage: View {
    let symbol: String
    let title: String
    let text: String
    var tint: Color = WidgetTheme.accent
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 18 : 22, weight: .semibold))
                .foregroundStyle(tint)
                .widgetAccentable()
            Text(title)
                .font(.system(size: compact ? 13 : 14, weight: .bold))
                .lineLimit(2)
            Text(text)
                .font(.system(size: compact ? 10 : 11))
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 3 : 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Version écran verrouillé d'un message : une ligne d'icône, deux de texte.
struct WidgetLockMessage: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline).lineLimit(1)
                Text(text).font(.caption2).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}
