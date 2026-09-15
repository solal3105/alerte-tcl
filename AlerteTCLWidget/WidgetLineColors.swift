import SwiftUI

/// Couleurs de ligne pour l'extension widget, qui ne lie pas le module Kotlin (limite mémoire
/// des widgets). Elle relit la palette officielle que l'application enregistre dans le conteneur
/// partagé (même format JSON que `LinePalette.encode()` côté Kotlin) et, pour une ligne inconnue,
/// retombe sur un badge neutre plutôt que sur une seconde copie de la charte.
struct LineColorHelper {

    private struct Colors: Decodable {
        let backgroundHex: String
        let textHex: String
    }

    /// Palette lue une fois par rendu du widget (le processus est de courte durée).
    private static let palette: [String: Colors] = {
        guard let encoded = AppGroup.defaults?.string(forKey: AppGroup.linePaletteKey),
              let data = encoded.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Colors].self, from: data) else { return [:] }
        return decoded
    }()

    private static func key(for ligne: String) -> String {
        String(ligne.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    static func backgroundColor(for ligne: String) -> Color {
        palette[key(for: ligne)].map { Color(hex: $0.backgroundHex) } ?? Color(.systemGray5)
    }

    static func textColor(for ligne: String) -> Color {
        palette[key(for: ligne)].map { Color(hex: $0.textHex) } ?? .primary
    }

    static func needsBorder(for ligne: String) -> Bool {
        guard let colors = palette[key(for: ligne)] else { return true }
        let clean = colors.backgroundHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return false }
        let r = Double((value >> 16) & 0xFF), g = Double((value >> 8) & 0xFF), b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.85
    }
}
