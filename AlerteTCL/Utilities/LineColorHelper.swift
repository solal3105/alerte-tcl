import SwiftUI
import Combine
import Shared

/// Couleurs de ligne de l'application : délègue au module partagé (palette officielle du GTFS,
/// puis charte historique en secours), pour que iOS et Android calculent exactement les mêmes couleurs.
/// L'extension widget, qui ne lie pas le module Kotlin, a sa propre lecture de la palette
/// (`AlerteTCLWidget/WidgetLineColors.swift`).
struct LineColorHelper {

    /// Couleur de fond du badge de ligne.
    static func backgroundColor(for ligne: String) -> Color {
        Color(hex: LineColors.shared.backgroundHex(line: ligne))
    }

    /// Couleur du texte du badge de ligne.
    static func textColor(for ligne: String) -> Color {
        Color(hex: LineColors.shared.textHex(line: ligne))
    }

    /// Indique si une bordure est nécessaire (fond clair, proche du blanc).
    static func needsBorder(for ligne: String) -> Bool {
        LineColors.shared.needsBorder(line: ligne)
    }
}

/// Signale aux vues SwiftUI que la palette officielle a changé : un badge rendu avant son
/// chargement (démarrage à froid) se redessine avec les bonnes couleurs.
@MainActor
final class LinePaletteObserver: ObservableObject {
    static let shared = LinePaletteObserver()
    @Published private(set) var version = 0
    private init() {}

    func paletteDidChange() { version += 1 }
}
