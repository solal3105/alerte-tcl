import Foundation
import Shared

/// Les pastilles « Nouveau » (`NewBadges`, module partagé) : sur la tuile « Stations Vélo'v » de l'accueil
/// « Autour de moi » et sur l'onglet « Autour de moi », tant que la règle partagée le veut (prévision
/// Vélo'v disponible, carte des stations pas encore vue avec son curseur d'heure). Réévaluées au
/// lancement, à chaque retour au premier plan et à l'ouverture de l'onglet.
@MainActor
final class NewBadgesViewModel: ObservableObject {
    static let shared = NewBadgesViewModel()

    /// Vrai tant que la prévision Vélo'v mérite sa pastille.
    @Published private(set) var showsVelovForecast = false

    /// Vrai une fois la prévision vue sur la carte des stations : gardé d'un lancement à l'autre.
    private static let velovForecastOpenedKey = "badge.velovForecastOpened"
    /// Dernière réponse de la prévision : la règle est relue sans attendre quand la carte a été vue.
    private var velovForecastAvailable = false

    private init() {}

    /// Au lancement : le modèle de prévision se charge (et se met à jour au besoin) pour que la
    /// pastille puisse paraître, puis la règle est lue.
    func start() async {
        VelovForecastService.companion.shared.warmUp()
        await refresh()
    }

    /// Relit la disponibilité de la prévision, puis la règle.
    func refresh() async {
        let nowMs = Self.nowEpochMs
        let available = (try? await VelovForecastService.companion.shared.isAvailable(originEpochMs: nowMs))?.boolValue ?? false
        velovForecastAvailable = available
        evaluate(nowMs: nowMs)
    }

    /// La prévision a été vue sur la carte des stations : les pastilles s'effacent pour de bon.
    func markVelovForecastSeen() {
        UserDefaults.standard.set(true, forKey: Self.velovForecastOpenedKey)
        evaluate(nowMs: Self.nowEpochMs)
    }

    /// Ne publie qu'un changement : l'onglet et l'accueil ne sont pas redessinés pour rien.
    private func evaluate(nowMs: Int64) {
        let shows = NewBadges.shared.showsVelovForecast(
            opened: UserDefaults.standard.bool(forKey: Self.velovForecastOpenedKey),
            forecastAvailable: velovForecastAvailable,
            nowEpochMs: nowMs
        )
        if shows != showsVelovForecast { showsVelovForecast = shows }
    }

    private static var nowEpochMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
