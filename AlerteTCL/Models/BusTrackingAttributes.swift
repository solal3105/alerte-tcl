import ActivityKit
import Foundation

/// Suivi d'un bus jusqu'à un arrêt, affiché sur l'écran verrouillé et dans la Dynamic Island.
/// Membre de l'application et de l'extension widget ; ne dépend pas du module Kotlin.
struct BusTrackingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// « Au prochain arrêt », « À 3 arrêts » (texte de la règle partagée `ApproachingVehicle`).
        var stopsText: String
        /// Arrivée estimée : horaire prévu de la course corrigé du retard constaté ; nil sans course identifiée.
        var estimatedArrival: Date?
        /// Dernière position transmise par TCL, affichée en délai relatif.
        var positionRecordedAt: Date?
        /// Dernière mise à jour par l'application.
        var updatedAt: Date
        /// Renseigné quand le suivi est terminé (bus passé, position perdue, arrêt par l'utilisateur).
        var endedText: String?
    }

    var line: String
    var lineColorHex: String
    var lineTextColorHex: String
    var destination: String
    var stopName: String
    var vehicleId: String
}
