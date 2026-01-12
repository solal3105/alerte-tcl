import Foundation
import SwiftUI

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case metro = "Métro"
    case tramway = "Tramway"
    case busC = "Bus C"
    case bus = "Bus"
    case funiculaire = "Funiculaire"
    case navette = "Navette maritime/fluviale"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .metro: return "tram.fill"
        case .tramway: return "tram"
        case .busC: return "bus.fill"
        case .bus: return "bus.fill"
        case .funiculaire: return "cablecar.fill"
        case .navette: return "ferry.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .metro: return .orange
        case .tramway: return .blue
        case .busC: return .purple
        case .bus: return .indigo
        case .funiculaire: return .green
        case .navette: return .cyan
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .metro: return 0
        case .funiculaire: return 1
        case .tramway: return 2
        case .busC: return 3
        case .bus: return 4
        case .navette: return 5
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
    static let metroLines: [TransportLine] = [
        TransportLine(ligneCom: "MA", ligneCli: "A", mode: .metro),
        TransportLine(ligneCom: "MB", ligneCli: "B", mode: .metro),
        TransportLine(ligneCom: "MC", ligneCli: "C", mode: .metro),
        TransportLine(ligneCom: "MD", ligneCli: "D", mode: .metro),
    ]
    
    static let tramwayLines: [TransportLine] = [
        TransportLine(ligneCom: "T1", ligneCli: "T1", mode: .tramway),
        TransportLine(ligneCom: "T2", ligneCli: "T2", mode: .tramway),
        TransportLine(ligneCom: "T3", ligneCli: "T3", mode: .tramway),
        TransportLine(ligneCom: "T4", ligneCli: "T4", mode: .tramway),
        TransportLine(ligneCom: "T5", ligneCli: "T5", mode: .tramway),
        TransportLine(ligneCom: "T6", ligneCli: "T6", mode: .tramway),
        TransportLine(ligneCom: "T7", ligneCli: "T7", mode: .tramway),
        TransportLine(ligneCom: "RX", ligneCli: "RX", mode: .tramway),
        TransportLine(ligneCom: "TS", ligneCli: "TS", mode: .tramway),
        TransportLine(ligneCom: "TB11", ligneCli: "TB11", mode: .tramway),
    ]
    
    static let funicularLines: [TransportLine] = [
        TransportLine(ligneCom: "F1", ligneCli: "F1", mode: .funiculaire),
        TransportLine(ligneCom: "F2", ligneCli: "F2", mode: .funiculaire),
    ]
    
    static let busCLines: [TransportLine] = [
        TransportLine(ligneCom: "C1", ligneCli: "C1", mode: .busC),
        TransportLine(ligneCom: "C2", ligneCli: "C2", mode: .busC),
        TransportLine(ligneCom: "C3", ligneCli: "C3", mode: .busC),
        TransportLine(ligneCom: "C4", ligneCli: "C4", mode: .busC),
        TransportLine(ligneCom: "C5", ligneCli: "C5", mode: .busC),
        TransportLine(ligneCom: "C6", ligneCli: "C6", mode: .busC),
        TransportLine(ligneCom: "C7", ligneCli: "C7", mode: .busC),
        TransportLine(ligneCom: "C8", ligneCli: "C8", mode: .busC),
        TransportLine(ligneCom: "C9", ligneCli: "C9", mode: .busC),
        TransportLine(ligneCom: "C10", ligneCli: "C10", mode: .busC),
        TransportLine(ligneCom: "C11", ligneCli: "C11", mode: .busC),
        TransportLine(ligneCom: "C12", ligneCli: "C12", mode: .busC),
        TransportLine(ligneCom: "C13", ligneCli: "C13", mode: .busC),
        TransportLine(ligneCom: "C14", ligneCli: "C14", mode: .busC),
        TransportLine(ligneCom: "C15", ligneCli: "C15", mode: .busC),
        TransportLine(ligneCom: "C16", ligneCli: "C16", mode: .busC),
        TransportLine(ligneCom: "C17", ligneCli: "C17", mode: .busC),
        TransportLine(ligneCom: "C18", ligneCli: "C18", mode: .busC),
        TransportLine(ligneCom: "C19", ligneCli: "C19", mode: .busC),
        TransportLine(ligneCom: "C20", ligneCli: "C20", mode: .busC),
        TransportLine(ligneCom: "C21", ligneCli: "C21", mode: .busC),
        TransportLine(ligneCom: "C22", ligneCli: "C22", mode: .busC),
        TransportLine(ligneCom: "C23", ligneCli: "C23", mode: .busC),
        TransportLine(ligneCom: "C24", ligneCli: "C24", mode: .busC),
        TransportLine(ligneCom: "C25", ligneCli: "C25", mode: .busC),
        TransportLine(ligneCom: "C26", ligneCli: "C26", mode: .busC),
    ]
    
    static let busLines: [TransportLine] = [
        TransportLine(ligneCom: "S1", ligneCli: "S1", mode: .bus),
        TransportLine(ligneCom: "S2", ligneCli: "S2", mode: .bus),
        TransportLine(ligneCom: "S3", ligneCli: "S3", mode: .bus),
        TransportLine(ligneCom: "S4", ligneCli: "S4", mode: .bus),
        TransportLine(ligneCom: "S5", ligneCli: "S5", mode: .bus),
        TransportLine(ligneCom: "S6", ligneCli: "S6", mode: .bus),
        TransportLine(ligneCom: "S7", ligneCli: "S7", mode: .bus),
        TransportLine(ligneCom: "S8", ligneCli: "S8", mode: .bus),
        TransportLine(ligneCom: "S9", ligneCli: "S9", mode: .bus),
        TransportLine(ligneCom: "S10", ligneCli: "S10", mode: .bus),
        TransportLine(ligneCom: "S11", ligneCli: "S11", mode: .bus),
        TransportLine(ligneCom: "S12", ligneCli: "S12", mode: .bus),
        TransportLine(ligneCom: "2", ligneCli: "2", mode: .bus),
        TransportLine(ligneCom: "3", ligneCli: "3", mode: .bus),
        TransportLine(ligneCom: "8", ligneCli: "8", mode: .bus),
        TransportLine(ligneCom: "9", ligneCli: "9", mode: .bus),
        TransportLine(ligneCom: "17", ligneCli: "17", mode: .bus),
        TransportLine(ligneCom: "19", ligneCli: "19", mode: .bus),
        TransportLine(ligneCom: "20", ligneCli: "20", mode: .bus),
        TransportLine(ligneCom: "21", ligneCli: "21", mode: .bus),
        TransportLine(ligneCom: "22", ligneCli: "22", mode: .bus),
        TransportLine(ligneCom: "23", ligneCli: "23", mode: .bus),
        TransportLine(ligneCom: "24", ligneCli: "24", mode: .bus),
        TransportLine(ligneCom: "25", ligneCli: "25", mode: .bus),
        TransportLine(ligneCom: "26", ligneCli: "26", mode: .bus),
        TransportLine(ligneCom: "27", ligneCli: "27", mode: .bus),
        TransportLine(ligneCom: "28", ligneCli: "28", mode: .bus),
        TransportLine(ligneCom: "29", ligneCli: "29", mode: .bus),
        TransportLine(ligneCom: "31", ligneCli: "31", mode: .bus),
        TransportLine(ligneCom: "33", ligneCli: "33", mode: .bus),
        TransportLine(ligneCom: "34", ligneCli: "34", mode: .bus),
        TransportLine(ligneCom: "35", ligneCli: "35", mode: .bus),
        TransportLine(ligneCom: "36", ligneCli: "36", mode: .bus),
        TransportLine(ligneCom: "37", ligneCli: "37", mode: .bus),
        TransportLine(ligneCom: "38", ligneCli: "38", mode: .bus),
        TransportLine(ligneCom: "39", ligneCli: "39", mode: .bus),
        TransportLine(ligneCom: "40", ligneCli: "40", mode: .bus),
        TransportLine(ligneCom: "41", ligneCli: "41", mode: .bus),
        TransportLine(ligneCom: "43", ligneCli: "43", mode: .bus),
        TransportLine(ligneCom: "44", ligneCli: "44", mode: .bus),
        TransportLine(ligneCom: "45", ligneCli: "45", mode: .bus),
        TransportLine(ligneCom: "46", ligneCli: "46", mode: .bus),
        TransportLine(ligneCom: "47", ligneCli: "47", mode: .bus),
        TransportLine(ligneCom: "48", ligneCli: "48", mode: .bus),
        TransportLine(ligneCom: "49", ligneCli: "49", mode: .bus),
        TransportLine(ligneCom: "52", ligneCli: "52", mode: .bus),
        TransportLine(ligneCom: "53", ligneCli: "53", mode: .bus),
        TransportLine(ligneCom: "54", ligneCli: "54", mode: .bus),
        TransportLine(ligneCom: "55", ligneCli: "55", mode: .bus),
        TransportLine(ligneCom: "57", ligneCli: "57", mode: .bus),
        TransportLine(ligneCom: "58", ligneCli: "58", mode: .bus),
        TransportLine(ligneCom: "59", ligneCli: "59", mode: .bus),
        TransportLine(ligneCom: "60", ligneCli: "60", mode: .bus),
        TransportLine(ligneCom: "61", ligneCli: "61", mode: .bus),
        TransportLine(ligneCom: "62", ligneCli: "62", mode: .bus),
        TransportLine(ligneCom: "63", ligneCli: "63", mode: .bus),
        TransportLine(ligneCom: "64", ligneCli: "64", mode: .bus),
        TransportLine(ligneCom: "65", ligneCli: "65", mode: .bus),
        TransportLine(ligneCom: "66", ligneCli: "66", mode: .bus),
        TransportLine(ligneCom: "67", ligneCli: "67", mode: .bus),
        TransportLine(ligneCom: "68", ligneCli: "68", mode: .bus),
        TransportLine(ligneCom: "69", ligneCli: "69", mode: .bus),
        TransportLine(ligneCom: "70", ligneCli: "70", mode: .bus),
        TransportLine(ligneCom: "71", ligneCli: "71", mode: .bus),
        TransportLine(ligneCom: "72", ligneCli: "72", mode: .bus),
        TransportLine(ligneCom: "73", ligneCli: "73", mode: .bus),
        TransportLine(ligneCom: "76", ligneCli: "76", mode: .bus),
        TransportLine(ligneCom: "77", ligneCli: "77", mode: .bus),
        TransportLine(ligneCom: "78", ligneCli: "78", mode: .bus),
        TransportLine(ligneCom: "79", ligneCli: "79", mode: .bus),
        TransportLine(ligneCom: "80", ligneCli: "80", mode: .bus),
        TransportLine(ligneCom: "81", ligneCli: "81", mode: .bus),
        TransportLine(ligneCom: "83", ligneCli: "83", mode: .bus),
        TransportLine(ligneCom: "84", ligneCli: "84", mode: .bus),
        TransportLine(ligneCom: "85", ligneCli: "85", mode: .bus),
        TransportLine(ligneCom: "89", ligneCli: "89", mode: .bus),
        TransportLine(ligneCom: "90", ligneCli: "90", mode: .bus),
        TransportLine(ligneCom: "93", ligneCli: "93", mode: .bus),
        TransportLine(ligneCom: "96", ligneCli: "96", mode: .bus),
        TransportLine(ligneCom: "98", ligneCli: "98", mode: .bus),
        TransportLine(ligneCom: "99", ligneCli: "99", mode: .bus),
    ]
    
    static let navetteLines: [TransportLine] = [
        TransportLine(ligneCom: "7601", ligneCli: "NAVI1", mode: .navette),
    ]
    
    static let allPredefinedLines: [TransportLine] = metroLines + funicularLines + tramwayLines + busCLines + busLines + navetteLines
}
