import Foundation
import Shared
import WidgetKit

/// Passerelle de l'application vers ses widgets.
///
/// Les arrêts choisis pour les passages, les lignes suivies et les couleurs de `AppColors` sont
/// écrits dans le conteneur partagé (`WidgetStore`), puis les chronologies des widgets concernés
/// sont rechargées. L'extension ne lie pas le module Kotlin : tout ce qu'elle affiche vient d'ici
/// ou des données ouvertes.
@MainActor
final class WidgetBridge: ObservableObject {
    static let shared = WidgetBridge()

    private static let maxStops = 30

    /// Arrêts enregistrés pour les widgets « Prochains passages » et « Tableau de départs », dans l'ordre d'affichage.
    @Published private(set) var stops: [WidgetStop] = WidgetStore.stops

    private init() {}

    // MARK: - Arrêts

    func contains(_ stop: WidgetStop) -> Bool {
        stops.contains { $0.id == stop.id }
    }

    /// Ajoute des arrêts en tête de liste (un arrêt déjà présent remonte), dans la limite de trente.
    func add(_ newStops: [WidgetStop]) {
        var merged = newStops
        merged.append(contentsOf: stops.filter { existing in !newStops.contains { $0.id == existing.id } })
        stops = Array(merged.prefix(Self.maxStops))
        persistStops()
    }

    func remove(at offsets: IndexSet) {
        stops.remove(atOffsets: offsets)
        persistStops()
    }

    func move(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
        persistStops()
    }

    private func persistStops() {
        WidgetStore.stops = stops
        reload([.departures, .board])
    }

    // MARK: - Lignes suivies et couleurs

    /// Les abonnements aux notifications, pour le widget « Trafic sur mes lignes ».
    func publishSubscriptions(_ lineIds: Set<String>) {
        let sorted = lineIds.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        guard sorted != WidgetStore.subscribedLines else { return }
        WidgetStore.subscribedLines = sorted
        reload([.traffic])
    }

    /// Les jetons de `AppColors`, publiés à chaque lancement : l'extension dessine avec les mêmes couleurs.
    func publishTheme() {
        let colors = AppColors.shared
        func themed(_ color: ThemedColor) -> WidgetThemeTokens.Themed { .init(light: color.light, dark: color.dark) }
        let tokens = WidgetThemeTokens(
            accent: themed(colors.accent),
            success: themed(colors.success),
            warning: themed(colors.warning),
            error: themed(colors.error),
            neutral: themed(colors.neutral),
            neutralFill: themed(colors.neutralFill),
            neutralBorder: themed(colors.neutralBorder),
            velov: themed(colors.velov),
            worksProgress: (0...10).map { colors.travauxProgress(percent: Double($0 * 10)) }
        )
        guard tokens != WidgetStore.theme else { return }
        WidgetStore.theme = tokens
        reload(WidgetKind.allCases)
    }

    // MARK: - Rechargement

    func reload(_ kinds: [WidgetKind]) {
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind.rawValue)
        }
    }

    /// Au passage en arrière-plan : l'écran d'accueil arrive, les passages doivent être du moment.
    func reloadTimeSensitive() {
        reload([.departures, .board, .traffic])
    }
}
