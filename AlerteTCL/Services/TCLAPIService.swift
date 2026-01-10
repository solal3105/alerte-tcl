import Foundation

actor TCLAPIService {
    static let shared = TCLAPIService()
    
    private init() {}
    
    func fetchAlerts() async throws -> [TCLAlert] {
        // L'API Grand Lyon nécessite une authentification
        // En attendant une clé API, on utilise des données réelles extraites manuellement
        return loadLocalAlerts()
    }
    
    private func loadLocalAlerts() -> [TCLAlert] {
        let now = Date()
        let tomorrow = now.addingTimeInterval(86400)
        let nextWeek = now.addingTimeInterval(86400 * 7)
        
        return [
            // Alertes neige actuelles
            TCLAlert(id: "1", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .metro, ligneCom: "A", ligneCli: "A", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            TCLAlert(id: "2", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .metro, ligneCom: "B", ligneCli: "B", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            TCLAlert(id: "3", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .metro, ligneCom: "C", ligneCli: "C", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            TCLAlert(id: "4", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .metro, ligneCom: "D", ligneCli: "D", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            
            // Tramways
            TCLAlert(id: "7", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .tramway, ligneCom: "T1", ligneCli: "T1", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            TCLAlert(id: "11", type: "Information", cause: "événement", debut: now, fin: nextWeek, mode: .tramway, ligneCom: "T5", ligneCli: "T5", titre: "Du 9 au 11/01", message: "A l'occasion du Salon de l'étudiant et du Festival Magic The Gathering, la ligne de tramway T5 sera renforcée."),
            TCLAlert(id: "20", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .tramway, ligneCom: "TB11", ligneCli: "TB11", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            
            // Bus C
            TCLAlert(id: "24", type: "Perturbation", cause: "travaux", debut: now.addingTimeInterval(-86400 * 30), fin: now.addingTimeInterval(86400 * 8), mode: .bus, ligneCom: "C2", ligneCli: "C2", titre: "Déviée deux sens - 09/12 au 16/01", message: "Les arrêts de Charpennes Charles Hernu à Cité Inter Transbordeur ne sont plus desservis dans les deux sens de circulation. Des travaux sont en cours boulevard Stalingrad à Villeurbanne."),
            TCLAlert(id: "29", type: "Perturbation", cause: "travaux", debut: now.addingTimeInterval(-86400 * 13), fin: now.addingTimeInterval(86400 * 52), mode: .bus, ligneCom: "C7", ligneCli: "C7", titre: "Déviée dir. St-Genis-Laval - jusqu'au 01/03", message: "Les arrêts de Garibaldi - Gambetta à Domer - Chevreul ne sont plus desservis en direction de St-Genis-Laval HÔp. Sud uniquement. Des travaux sont en cours rue Garibaldi à Lyon 7ème."),
            TCLAlert(id: "35", type: "Perturbation", cause: "travaux de voirie", debut: now.addingTimeInterval(-86400), fin: now.addingTimeInterval(86400 * 32), mode: .bus, ligneCom: "C9", ligneCli: "C9", titre: "Terminus Gare P.-Dieu V. Merle - 07/01 au 08/02", message: "Les arrêts de Bellecour à Gare Part-Dieu Auditorium ne sont plus desservis. Des travaux de voirie sont en cours rue de Bonnel, Lyon 3."),
            
            // Bus numérotés
            TCLAlert(id: "85", type: "Perturbation", cause: "travaux", debut: now.addingTimeInterval(-86400 * 3), fin: now.addingTimeInterval(86400 * 23), mode: .bus, ligneCom: "12", ligneCli: "12", titre: "Déviée deux sens - 5 au 30/01", message: "L'arrêt Misery n'est plus desservi dans les deux sens de circulation. Des travaux sont en cours rue Jean et Antoine Josserand à Chaponost."),
            TCLAlert(id: "90", type: "Perturbation", cause: "manifestation", debut: now.addingTimeInterval(-600), fin: tomorrow, mode: .bus, ligneCom: "15", ligneCli: "15", titre: "Terminus Le Péage - 08/01", message: "La ligne circule uniquement entre Saules-Jaures et Le Péage. Une manifestation est en cours sur la M7."),
            
            // Funiculaires
            TCLAlert(id: "5", type: "Information", cause: "chutes de neige", debut: now.addingTimeInterval(-3600), fin: now.addingTimeInterval(18000), mode: .funiculaire, ligneCom: "F1", ligneCli: "F1", titre: "08/01- Chutes de neige", message: "Jeudi 8 janvier à 16h15 - reprise de la circulation sur l'ensemble des lignes du réseau TCL."),
            
            // NavigÔne
            TCLAlert(id: "21", type: "Information ligne", cause: "information ligne", debut: now.addingTimeInterval(-86400 * 120), fin: now.addingTimeInterval(86400 * 365 * 10), mode: .navette, ligneCom: "7601", ligneCli: "NAVI1", titre: "Tarification spéciale NavigÔne", message: "NavigÔne est inclus dans tous les abonnements TCL contenant la zone tarifaire 1, sans surcoût."),
        ]
    }
    
    func fetchAlertsForLines(_ lineIds: [String]) async throws -> [TCLAlert] {
        let allAlerts = try await fetchAlerts()
        return allAlerts.filter { alert in
            lineIds.contains(alert.ligneCom) || lineIds.contains(alert.ligneCli)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .unauthorized:
            return "Accès non autorisé - Clé API requise"
        case .notFound:
            return "Données non trouvées"
        case .serverError(let code):
            return "Erreur serveur (\(code))"
        case .decodingError:
            return "Erreur de décodage des données"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        }
    }
}
