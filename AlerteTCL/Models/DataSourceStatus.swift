import Foundation

/// Représente le statut d'une source de données
struct DataSourceStatus: Identifiable {
    let id: String
    let name: String
    var error: String?
    var lastAttempt: Date?
    var isLoading: Bool = false
    
    var hasError: Bool {
        error != nil
    }
    
    static func == (lhs: DataSourceStatus, rhs: DataSourceStatus) -> Bool {
        lhs.id == rhs.id
    }
}

/// Sources de données disponibles
enum DataSource: String, CaseIterable, Identifiable {
    case vehicles = "vehicles"
    case busLines = "busLines"
    case transitLines = "transitLines"
    case transitStops = "transitStops"
    case alerts = "alerts"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .vehicles: return "Véhicules en temps réel"
        case .busLines: return "Lignes de bus"
        case .transitLines: return "Lignes métro/tram"
        case .transitStops: return "Arrêts de transport"
        case .alerts: return "Alertes trafic"
        }
    }
    
    var icon: String {
        switch self {
        case .vehicles: return "bus.fill"
        case .busLines: return "point.topleft.down.to.point.bottomright.curvepath"
        case .transitLines: return "tram.fill"
        case .transitStops: return "mappin.circle.fill"
        case .alerts: return "exclamationmark.triangle.fill"
        }
    }
}
