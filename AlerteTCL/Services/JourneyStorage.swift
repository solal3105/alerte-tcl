import Foundation

final class JourneyStorage {
    static let shared = JourneyStorage()
    
    private let recentJourneysKey = "recentJourneys"
    private let favoritePlacesKey = "favoritePlaces"
    private let maxRecentJourneys = 10
    
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {}
    
    // MARK: - Recent Journeys
    
    func saveRecentJourney(_ journey: Journey) {
        var recents = getRecentJourneys()
        
        let newRecent = RecentJourney(from: journey)
        
        recents.removeAll { recent in
            recent.departure.name == newRecent.departure.name &&
            recent.arrival.name == newRecent.arrival.name
        }
        
        recents.insert(newRecent, at: 0)
        
        if recents.count > maxRecentJourneys {
            recents = Array(recents.prefix(maxRecentJourneys))
        }
        
        saveRecentJourneys(recents)
    }
    
    func getRecentJourneys() -> [RecentJourney] {
        guard let data = defaults.data(forKey: recentJourneysKey),
              let journeys = try? decoder.decode([RecentJourney].self, from: data) else {
            return []
        }
        return journeys.sorted { $0.lastUsed > $1.lastUsed }
    }
    
    func clearRecentJourneys() {
        defaults.removeObject(forKey: recentJourneysKey)
    }
    
    func removeRecentJourney(_ journey: RecentJourney) {
        var recents = getRecentJourneys()
        recents.removeAll { $0.id == journey.id }
        saveRecentJourneys(recents)
    }
    
    private func saveRecentJourneys(_ journeys: [RecentJourney]) {
        if let data = try? encoder.encode(journeys) {
            defaults.set(data, forKey: recentJourneysKey)
        }
    }
    
    // MARK: - Favorite Places
    
    func saveFavoritePlace(_ place: FavoritePlace) {
        var favorites = getFavoritePlaces()
        
        favorites.removeAll { $0.location.name == place.location.name }
        favorites.append(place)
        
        saveFavoritePlaces(favorites)
    }
    
    func getFavoritePlaces() -> [FavoritePlace] {
        guard let data = defaults.data(forKey: favoritePlacesKey),
              let places = try? decoder.decode([FavoritePlace].self, from: data) else {
            return []
        }
        return places.sorted { $0.createdAt < $1.createdAt }
    }
    
    func removeFavoritePlace(_ place: FavoritePlace) {
        var favorites = getFavoritePlaces()
        favorites.removeAll { $0.id == place.id }
        saveFavoritePlaces(favorites)
    }
    
    func updateFavoritePlace(_ place: FavoritePlace, newName: String) {
        var favorites = getFavoritePlaces()
        if let index = favorites.firstIndex(where: { $0.id == place.id }) {
            let updated = FavoritePlace(
                name: place.name,
                customName: newName,
                location: place.location,
                icon: place.icon
            )
            favorites[index] = updated
            saveFavoritePlaces(favorites)
        }
    }
    
    func hasFavoritePlace(named name: String) -> Bool {
        getFavoritePlaces().contains { $0.displayName.lowercased() == name.lowercased() }
    }
    
    func getHomePlace() -> FavoritePlace? {
        getFavoritePlaces().first { $0.icon == "house.fill" }
    }
    
    func getWorkPlace() -> FavoritePlace? {
        getFavoritePlaces().first { $0.icon == "briefcase.fill" }
    }
    
    private func saveFavoritePlaces(_ places: [FavoritePlace]) {
        if let data = try? encoder.encode(places) {
            defaults.set(data, forKey: favoritePlacesKey)
        }
    }
}
