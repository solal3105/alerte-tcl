import Foundation
import Combine

@MainActor
public final class FavoriteLinesService: ObservableObject {
    public static let shared = FavoriteLinesService()
    
    @Published public private(set) var favoriteLines: Set<String> = []
    
    private let favoritesKey = "favoriteLines"
    
    private init() {
        loadFavorites()
    }
    
    public func isFavorite(_ line: String) -> Bool {
        favoriteLines.contains(line)
    }
    
    public func toggleFavorite(_ line: String) {
        if favoriteLines.contains(line) {
            favoriteLines.remove(line)
        } else {
            favoriteLines.insert(line)
        }
        saveFavorites()
        objectWillChange.send()
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteLines = Set(data)
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteLines), forKey: favoritesKey)
    }
}
