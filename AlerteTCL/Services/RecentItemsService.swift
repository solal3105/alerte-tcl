//
//  RecentItemsService.swift
//  AlerteTCL
//
//  Service pour sauvegarder les arrêts et parkings récents
//  pour la configuration des widgets
//

import Foundation

@MainActor
class RecentItemsService {
    static let shared = RecentItemsService()
    
    private let defaults = UserDefaults(suiteName: "group.com.solal.alertetcl")
    private let maxRecentItems = 20
    
    private init() {}
    
    // MARK: - Stops
    
    func getRecentStops() -> [[String: String]] {
        return defaults?.array(forKey: "recentStops") as? [[String: String]] ?? []
    }
    
    // MARK: - Parkings
    
    func saveRecentParking(id: String, name: String) {
        var recentParkings = getRecentParkings()
        
        // Supprimer le parking s'il existe déjà
        recentParkings.removeAll { $0["id"] == id }
        
        // Ajouter en première position
        recentParkings.insert(["id": id, "name": name], at: 0)
        
        // Limiter à maxRecentItems
        if recentParkings.count > maxRecentItems {
            recentParkings = Array(recentParkings.prefix(maxRecentItems))
        }
        
        defaults?.set(recentParkings, forKey: "recentParkings")
    }
    
    func getRecentParkings() -> [[String: String]] {
        return defaults?.array(forKey: "recentParkings") as? [[String: String]] ?? []
    }
    
}
