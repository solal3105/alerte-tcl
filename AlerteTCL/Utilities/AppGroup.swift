import Foundation

/// Conteneur partagé entre l'app et l'extension widget.
///
/// Membre des deux targets : l'identifiant était auparavant recopié à cinq endroits,
/// une seule divergence suffisant à faire lire un stockage vide côté widget.
enum AppGroup {
    static let identifier = "group.com.solal.alertetcl"

    /// `UserDefaults` du conteneur partagé (nil si le groupe n'est pas provisionné).
    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }

    /// Palette officielle des couleurs de lignes (JSON encodé par `LinePalette` côté Kotlin),
    /// écrite par l'application et relue par le widget.
    static let linePaletteKey = "linePalette"
    static var paletteStorage: UserDefaults { defaults ?? .standard }
}
