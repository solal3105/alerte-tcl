import Foundation
import SwiftUI
import Shared

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case metro = "Métro"
    case tramway = "Tramway"
    case busC = "Bus C"
    case bus = "Bus"
    case funiculaire = "Funiculaire"
    case navigone = "Navigone"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .metro: return "tram.fill"
        case .tramway: return "tram"
        case .busC: return "bus.fill"
        case .bus: return "bus.fill"
        case .funiculaire: return "cablecar.fill"
        case .navigone: return "ferry.fill"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .metro: return 0
        case .funiculaire: return 1
        case .tramway: return 2
        case .busC: return 3
        case .bus: return 4
        case .navigone: return 5
        }
    }

    var shortName: String {
        switch self {
        case .metro: return "Métro"
        case .tramway: return "Tram"
        case .busC: return "Bus C"
        case .bus: return "Bus"
        case .funiculaire: return "Funi"
        case .navigone: return "Navigone"
        }
    }
}

struct TransportLine: Identifiable, Hashable, Codable {
    let id: String
    let ligneCom: String
    let ligneCli: String
    let mode: TransportMode
    
    var displayName: String {
        ligneCli.isEmpty ? ligneCom : ligneCli
    }
    
    init(ligneCom: String, ligneCli: String, mode: TransportMode) {
        self.id = "\(mode.rawValue)-\(ligneCom)"
        self.ligneCom = ligneCom
        self.ligneCli = ligneCli
        self.mode = mode
    }
}

extension TransportLine {
    init(shared: Shared.TransportLine) {
        self.init(ligneCom: shared.ligneCom, ligneCli: shared.ligneCli, mode: TransportMode(shared: shared.mode))
    }
}

extension TransportMode {
    init(shared: Shared.TransportMode) {
        switch shared {
        case .metro: self = .metro
        case .tramway: self = .tramway
        case .funicular: self = .funiculaire
        case .busC: self = .busC
        case .navigone: self = .navigone
        default: self = .bus
        }
    }

    /// Mode d'après le code d'une ligne : listes canoniques du réseau puis heuristique, règle partagée.
    static func detectFromLine(_ ligne: String) -> TransportMode {
        TransportMode(shared: Shared.TransportMode.companion.detectFromLine(line: ligne))
    }
}
