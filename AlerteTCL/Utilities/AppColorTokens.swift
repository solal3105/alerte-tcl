import SwiftUI
import UIKit
import Shared

// MARK: - Jetons partagés → couleurs SwiftUI
//
// Toutes les couleurs sémantiques de l'application viennent du module Kotlin (`AppColors`),
// pour être identiques sur iOS et Android. Les vues n'emploient jamais une couleur système nommée.

extension Color {
    /// Couleur d'un jeton, qui suit le mode clair ou sombre du téléphone.
    init(token: ThemedColor) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? token.dark : token.light))
        })
    }

    /// Jeton facultatif : neutre quand la valeur n'est pas renseignée.
    static func token(_ token: ThemedColor?) -> Color {
        Color(token: token ?? AppColors.shared.neutral)
    }

    static let appAccent = Color(token: AppColors.shared.accent)
    static let appSuccess = Color(token: AppColors.shared.success)
    static let appWarning = Color(token: AppColors.shared.warning)
    static let appError = Color(token: AppColors.shared.error)
    static let appFavorite = Color(token: AppColors.shared.favorite)
    static let appNeutral = Color(token: AppColors.shared.neutral)
    static let appNeutralFill = Color(token: AppColors.shared.neutralFill)
    static let appNeutralBorder = Color(token: AppColors.shared.neutralBorder)
    static let stopMarker = Color(hex: AppColors.shared.stopMarker)
}

// MARK: - Passerelles vers les énumérations Kotlin

extension TransportMode {
    var shared: Shared.TransportMode {
        switch self {
        case .metro: .metro
        case .tramway: .tramway
        case .busC: .busC
        case .bus: .bus
        case .funiculaire: .funicular
        case .navigone: .navigone
        }
    }

    /// Couleur d'iconographie du mode (filtres, onglets), jamais celle d'une ligne précise.
    var color: Color { Color(hex: AppColors.shared.mode(mode: shared)) }
}

extension TransportLine {
    var shared: Shared.TransportLine {
        Shared.TransportLine.companion.create(ligneCom: ligneCom, ligneCli: ligneCli, mode: mode.shared)
    }
}

extension VehicleType {
    var shared: Shared.VehicleType {
        switch self {
        case .metro: .metro
        case .tram: .tram
        case .bus: .bus
        case .trolley: .trolley
        case .funicular: .funicular
        case .navigone: .navigone
        }
    }

    /// Couleur d'iconographie du type de véhicule (filtres, regroupements sur la carte).
    var clusterColor: Color { Color(hex: AppColors.shared.vehicleType(type: shared)) }
}

extension Vehicle.PositionFreshness {
    var color: Color {
        switch self {
        case .fresh: .appSuccess
        case .aging: .appWarning
        case .stale: .appError
        }
    }
}

extension AlertSeverity {
    var shared: Shared.AlertSeverity {
        switch self {
        case .major: .major
        case .disruption: .disruption
        case .info: .info
        }
    }

    init?(shared: Shared.AlertSeverity) {
        self.init(rawValue: shared.displayName)
    }

    var color: Color { Color(token: AppColors.shared.alertSeverity(severity: shared)) }

    /// Ce que la feuille d'options dit de ce type d'alerte.
    var summary: String { shared.description_ }
}

extension TCLAlert {
    var shared: Shared.TCLAlert {
        Shared.TCLAlert(
            id: id, type: type, cause: cause,
            debutEpoch: debut.map { KotlinLong(value: Int64($0.timeIntervalSince1970)) },
            finEpoch: fin.map { KotlinLong(value: Int64($0.timeIntervalSince1970)) },
            mode: mode.shared, ligneCom: ligneCom, ligneCli: ligneCli, titre: titre, message: message,
            niveauSeverite: niveauSeverite.map { KotlinInt(int: Int32($0)) }
        )
    }
}

extension TravauxNatureChantier {
    var shared: Shared.TravauxNatureChantier {
        switch self {
        case .transportsCommun: .transportsCommun
        case .cyclab: .cyclab
        case .espacePublic: .espacePublic
        case .carrefour: .carrefour
        case .assainissement: .assainissement
        case .autre: .autre
        }
    }

    var color: Color { Color(hex: shared.colorHex) }
}

extension TravauxImportance {
    var shared: Shared.TravauxImportance {
        switch self {
        case .tresPerturbant: .tresPerturbant
        case .perturbant: .perturbant
        case .peuPerturbant: .peuPerturbant
        case .inconnu: .inconnu
        }
    }

    var color: Color { Color.token(AppColors.shared.travauxImportance(importance: shared)) }
}

extension TravauxAvancement {
    var shared: Shared.TravauxAvancement {
        switch self {
        case .enCours: .enCours
        case .prevu: .prevu
        case .termine: .termine
        case .inconnu: .inconnu
        }
    }

    var color: Color { Color.token(AppColors.shared.travauxAvancement(avancement: shared)) }
}

extension Travaux {
    /// Avancement du chantier : du rouge (0 %) au vert (100 %), par paliers de 10 %.
    var progressColor: Color { Color(hex: AppColors.shared.travauxProgress(percent: completionPercentage)) }
}

extension ParkingType {
    var shared: Shared.ParkingType {
        switch self {
        case .car: .car
        case .bike: .bike
        case .motorized2Wheel: .motorized2w
        case .velov: .velov
        }
    }

    var color: Color { Color(token: AppColors.shared.parkingType(type: shared)) }

    init?(shared: Shared.ParkingType) {
        guard let match = ParkingType.allCases.first(where: { $0.shared == shared }) else { return nil }
        self = match
    }
}

extension CityTile {
    var color: Color { Color(token: AppColors.shared.cityTile(tile: self)) }

    /// Pictogramme de la tuile : celui de son type de stationnement, un marteau pour les chantiers.
    var icon: String { parkingType.flatMap(ParkingType.init(shared:))?.icon ?? "hammer.fill" }
}

extension Parking {
    /// Disponibilité : gris sans temps réel ou parking fermé, puis vert, orange, rouge selon le remplissage.
    var availabilityColor: Color {
        let state: Shared.AvailabilityColor
        if !hasRealtimeData || (!isParcRelais && etat != .ouvert) {
            state = .gray
        } else if tauxOccupation < 0.5 {
            state = .green
        } else if tauxOccupation < 0.8 {
            state = .orange
        } else {
            state = .red
        }
        return Color(token: AppColors.shared.parkingAvailability(color: state))
    }
}
