import Foundation

struct TCLAlert: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let cause: String
    let debut: Date?
    let fin: Date?
    let mode: TransportMode
    let ligneCom: String
    let ligneCli: String
    let titre: String
    let message: String
    let lastUpdateFme: String?
    let n: Int?
    let typeSeverite: String?
    let niveauSeverite: Int?
    let typeObjet: String?
    let listeObjet: String?
    
    enum CodingKeys: String, CodingKey {
        case type, cause, debut, fin, mode, titre, message
        case ligneCom = "ligne_com"
        case ligneCli = "ligne_cli"
        case lastUpdateFme = "last_update_fme"
        case n
        case typeSeverite = "typeseverite"
        case niveauSeverite = "niveauseverite"
        case typeObjet = "typeobjet"
        case listeObjet = "listeobjet"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Information"
        self.cause = try container.decodeIfPresent(String.self, forKey: .cause) ?? ""
        self.ligneCom = try container.decodeIfPresent(String.self, forKey: .ligneCom) ?? ""
        self.ligneCli = try container.decodeIfPresent(String.self, forKey: .ligneCli) ?? ""
        self.titre = try container.decodeIfPresent(String.self, forKey: .titre) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.lastUpdateFme = try container.decodeIfPresent(String.self, forKey: .lastUpdateFme)
        self.n = try container.decodeIfPresent(Int.self, forKey: .n)
        self.typeSeverite = try container.decodeIfPresent(String.self, forKey: .typeSeverite)
        self.niveauSeverite = try container.decodeIfPresent(Int.self, forKey: .niveauSeverite)
        self.typeObjet = try container.decodeIfPresent(String.self, forKey: .typeObjet)
        self.listeObjet = try container.decodeIfPresent(String.self, forKey: .listeObjet)
        
        let modeString = try container.decodeIfPresent(String.self, forKey: .mode) ?? "Bus"
        let ligneCom = try container.decodeIfPresent(String.self, forKey: .ligneCom) ?? ""
        
        // Déterminer si c'est un Bus C
        if modeString == "Bus" && ligneCom.hasPrefix("C") && ligneCom.count >= 2 {
            let secondChar = ligneCom[ligneCom.index(ligneCom.startIndex, offsetBy: 1)]
            if secondChar.isNumber {
                self.mode = .busC
            } else {
                self.mode = TransportMode(rawValue: modeString) ?? .bus
            }
        } else if modeString == "Navette maritime/fluviale" || modeString == "Navette" {
            self.mode = .navigone
        } else {
            self.mode = TransportMode(rawValue: modeString) ?? .bus
        }
        
        if let debutString = try container.decodeIfPresent(String.self, forKey: .debut) {
            self.debut = Self.parseDate(debutString)
        } else {
            self.debut = nil
        }
        
        if let finString = try container.decodeIfPresent(String.self, forKey: .fin) {
            self.fin = Self.parseDate(finString)
        } else {
            self.fin = nil
        }
        
        self.id = "\(n ?? 0)-\(ligneCom)-\(ligneCli)"
    }
    
    init(id: String, type: String, cause: String, debut: Date?, fin: Date?, mode: TransportMode, ligneCom: String, ligneCli: String, titre: String, message: String) {
        self.id = id
        self.type = type
        self.cause = cause
        self.debut = debut
        self.fin = fin
        self.mode = mode
        self.ligneCom = ligneCom
        self.ligneCli = ligneCli
        self.titre = titre
        self.message = message
        self.lastUpdateFme = nil
        self.n = nil
        self.typeSeverite = nil
        self.niveauSeverite = nil
        self.typeObjet = nil
        self.listeObjet = nil
    }
    
    static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    var severity: AlertSeverity {
        switch type.lowercased() {
        case let t where t.contains("majeure"):
            return .major
        case let t where t.contains("perturbation"):
            return .disruption
        default:
            return .info
        }
    }
    
    var isActive: Bool {
        let now = Date()
        if let end = fin {
            return now <= end
        }
        return true
    }
    
    /// L'alerte a déjà commencé (debut <= maintenant ou pas de date de début)
    var hasStarted: Bool {
        guard let debut = debut else { return true }
        return debut <= Date()
    }
    
    /// Perturbation en cours (active ET déjà commencée)
    var isOngoing: Bool {
        isActive && hasStarted
    }
    
    /// Perturbation à venir (active mais pas encore commencée)
    var isUpcoming: Bool {
        isActive && !hasStarted
    }
}

enum AlertSeverity: String, CaseIterable, Identifiable {
    case major = "Perturbation majeure"
    case disruption = "Perturbation"
    case info = "Information"
    
    var id: String { rawValue }
    
    var sortOrder: Int {
        switch self {
        case .major: return 0
        case .disruption: return 1
        case .info: return 2
        }
    }
    
    var color: String {
        switch self {
        case .info: return "alertInfo"
        case .disruption: return "alertWarning"
        case .major: return "alertDanger"
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .disruption: return "exclamationmark.triangle.fill"
        case .major: return "xmark.octagon.fill"
        }
    }
    
}

struct APIResponse: Codable {
    let values: [TCLAlert]
}

enum AlertNotificationPhase: String {
    case announced
    case active
}

extension TCLAlert {
    func notificationKey(phase: AlertNotificationPhase) -> String {
        "\(id)|\(phase.rawValue)"
    }
}

