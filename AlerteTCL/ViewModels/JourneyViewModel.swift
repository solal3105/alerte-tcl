import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

@MainActor
final class JourneyViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var departureLocation: JourneyLocation?
    @Published var arrivalLocation: JourneyLocation?
    
    @Published var departureText: String = ""
    @Published var arrivalText: String = ""
    
    @Published var isCalculating = false
    @Published var error: String?
    
    @Published var transitJourney: Journey?
    @Published var bikingJourney: Journey?
    @Published var drivingJourney: Journey?
    
    @Published var selectedMode: JourneyMode = .transit
    
    @Published var timeOption: JourneyTimeOption = .leaveNow
    @Published var customTime: Date = Date()
    
    @Published var recentJourneys: [RecentJourney] = []
    @Published var favoritePlaces: [FavoritePlace] = []
    
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    @Published var nearbyStops: [TransitStop] = []
    
    // MARK: - Private Properties
    
    private let journeyService = JourneyService.shared
    private let storage = JourneyStorage.shared
    private var searchTask: Task<Void, Never>?
    
    enum JourneyMode: String, CaseIterable {
        case transit = "TC"
        case biking = "Vélo"
        case driving = "Voiture"
        
        var icon: String {
            switch self {
            case .transit: return "tram.fill"
            case .biking: return "bicycle"
            case .driving: return "car.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .transit: return .purple
            case .biking: return .green
            case .driving: return .blue
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadStoredData()
    }
    
    // MARK: - Public Methods
    
    func loadStoredData() {
        recentJourneys = storage.getRecentJourneys()
        favoritePlaces = storage.getFavoritePlaces()
    }
    
    func setDeparture(location: JourneyLocation) {
        departureLocation = location
        departureText = location.name
    }
    
    func setArrival(location: JourneyLocation) {
        arrivalLocation = location
        arrivalText = location.name
    }
    
    func setDepartureToCurrentLocation(_ coordinate: CLLocationCoordinate2D) {
        let location = JourneyLocation(name: "Ma position", coordinate: coordinate)
        setDeparture(location: location)
    }
    
    func swapLocations() {
        let tempLocation = departureLocation
        let tempText = departureText
        
        departureLocation = arrivalLocation
        departureText = arrivalText
        
        arrivalLocation = tempLocation
        arrivalText = tempText
    }
    
    func clearDeparture() {
        departureLocation = nil
        departureText = ""
    }
    
    func clearArrival() {
        arrivalLocation = nil
        arrivalText = ""
    }
    
    func clearAll() {
        clearDeparture()
        clearArrival()
        transitJourney = nil
        bikingJourney = nil
        drivingJourney = nil
        error = nil
    }
    
    var currentJourney: Journey? {
        switch selectedMode {
        case .transit: return transitJourney
        case .biking: return bikingJourney
        case .driving: return drivingJourney
        }
    }
    
    var hasResults: Bool {
        transitJourney != nil || bikingJourney != nil || drivingJourney != nil
    }
    
    func calculateJourneys() async {
        guard let departure = departureLocation,
              let arrival = arrivalLocation else {
            error = "Veuillez sélectionner une destination"
            return
        }
        
        isCalculating = true
        error = nil
        transitJourney = nil
        bikingJourney = nil
        drivingJourney = nil
        
        defer { isCalculating = false }
        
        async let transitTask: Journey? = calculateTransit(departure: departure, arrival: arrival)
        async let bikingTask: Journey? = calculateBiking(departure: departure, arrival: arrival)
        async let drivingTask: Journey? = calculateDriving(departure: departure, arrival: arrival)
        
        let (transit, biking, driving) = await (transitTask, bikingTask, drivingTask)
        
        transitJourney = transit
        bikingJourney = biking
        drivingJourney = driving
        
        if !hasResults {
            error = "Aucun itinéraire disponible"
        } else if let journey = currentJourney {
            storage.saveRecentJourney(journey)
            recentJourneys = storage.getRecentJourneys()
        }
    }
    
    func selectMode(_ mode: JourneyMode) {
        selectedMode = mode
    }
    
    func loadRecentJourney(_ recent: RecentJourney) {
        setDeparture(location: recent.departure)
        setArrival(location: recent.arrival)
    }
    
    func deleteRecentJourney(_ recent: RecentJourney) {
        storage.removeRecentJourney(recent)
        recentJourneys = storage.getRecentJourneys()
    }
    
    func saveFavoritePlace(_ place: FavoritePlace) {
        storage.saveFavoritePlace(place)
        favoritePlaces = storage.getFavoritePlaces()
    }
    
    func deleteFavoritePlace(_ place: FavoritePlace) {
        storage.removeFavoritePlace(place)
        favoritePlaces = storage.getFavoritePlaces()
    }
    
    // MARK: - Search
    
    func searchLocations(query: String, near coordinate: CLLocationCoordinate2D?) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                
                let center = coordinate ?? CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
                request.region = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                )
                
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                if !Task.isCancelled {
                    searchResults = response.mapItems
                    isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    func cancelSearch() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
    }
    
    func selectSearchResult(_ mapItem: MKMapItem) -> JourneyLocation {
        let name = mapItem.name ?? "Lieu inconnu"
        let address = formatAddress(mapItem.placemark)
        return JourneyLocation(
            name: name,
            coordinate: mapItem.placemark.coordinate,
            address: address
        )
    }
    
    func selectTransitStop(_ stop: TransitStop) -> JourneyLocation {
        JourneyLocation(
            name: stop.nom,
            coordinate: stop.coordinate,
            stopId: stop.id
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateTransit(departure: JourneyLocation, arrival: JourneyLocation) async -> Journey? {
        do {
            return try await journeyService.calculateTransitJourney(
                from: departure.clCoordinate,
                to: arrival.clCoordinate,
                departureName: departure.name,
                arrivalName: arrival.name,
                timeOption: timeOption
            )
        } catch {
            return nil
        }
    }
    
    private func calculateDriving(departure: JourneyLocation, arrival: JourneyLocation) async -> Journey? {
        do {
            return try await journeyService.calculateDrivingJourney(
                from: departure.clCoordinate,
                to: arrival.clCoordinate,
                departureName: departure.name,
                arrivalName: arrival.name
            )
        } catch {
            return nil
        }
    }
    
    private func calculateBiking(departure: JourneyLocation, arrival: JourneyLocation) async -> Journey? {
        do {
            return try await journeyService.calculateBikingJourney(
                from: departure.clCoordinate,
                to: arrival.clCoordinate,
                departureName: departure.name,
                arrivalName: arrival.name
            )
        } catch {
            return nil
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}
