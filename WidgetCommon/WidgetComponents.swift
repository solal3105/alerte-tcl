import SwiftUI
import WidgetKit

// MARK: - En-tête et pied

/// Première ligne d'un widget : un pictogramme à l'accent, le nom de ce qu'on regarde, un détail.
struct WidgetHeader: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = WidgetTheme.accent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .widgetAccentable()
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Dernière ligne d'un widget : l'heure des données, et un avertissement si elles ne sont plus fraîches.
struct WidgetFooter: View {
    let fetchedAt: Date?
    var stale: Bool = false
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let fetchedAt {
                Image(systemName: stale ? "wifi.slash" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 8, weight: .semibold))
                Text(stale ? "Données de \(WidgetDeparture.timeFormatter.string(from: fetchedAt))" : WidgetDeparture.timeFormatter.string(from: fetchedAt))
            }
            if let trailing {
                if fetchedAt != nil { Text("·") }
                Text(trailing)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(stale ? WidgetTheme.warning : Color.secondary)
        .lineLimit(1)
    }
}

// MARK: - Jauge

/// Anneau de remplissage, le même dessin que les fiches des parkings et des chantiers.
struct WidgetRing: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
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

// MARK: - Point de temps réel

/// Point vert des passages suivis en direct, comme dans la fiche d'un arrêt.
struct WidgetLiveDot: View {
    var body: some View {
        Circle()
            .fill(WidgetTheme.success)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Grand chiffre

/// Un chiffre en grand avec son unité dessous ou à côté ; les nombres des widgets ont tous cette forme.
struct WidgetFigure: View {
    let value: String
    let unit: String?
    var size: CGFloat = 34
    var color: Color = .primary
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: -2) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            if let unit {
                Text(unit)
                    .font(.system(size: max(10, size * 0.32), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
