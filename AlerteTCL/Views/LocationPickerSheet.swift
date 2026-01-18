import SwiftUI
import MapKit

enum LocationSelectionType {
    case departure
    case arrival
}

struct LocationPickerSheet: View {
    @ObservedObject var viewModel: JourneyViewModel
    let selectionType: LocationSelectionType
    let currentLocation: CLLocationCoordinate2D?
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    defaultContent
                } else {
                    searchResultsContent
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Rechercher un lieu, un arrêt..."
            )
            .onChange(of: searchText) { _, newValue in
                viewModel.searchLocations(query: newValue, near: currentLocation)
            }
            .navigationTitle(selectionType == .departure ? "Point de départ" : "Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        viewModel.cancelSearch()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            viewModel.cancelSearch()
        }
    }
    
    // MARK: - Default Content (no search)
    
    @ViewBuilder
    private var defaultContent: some View {
        if selectionType == .departure {
            currentLocationSection
        }
        
        if !viewModel.favoritePlaces.isEmpty {
            favoritePlacesSection
        }
        
        if !viewModel.recentJourneys.isEmpty {
            recentLocationsSection
        }
    }
    
    private var currentLocationSection: some View {
        Section {
            Button {
                if let coord = currentLocation {
                    let location = JourneyLocation(name: "Ma position", coordinate: coord)
                    selectLocation(location)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ma position")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text("Utiliser la position GPS actuelle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .disabled(currentLocation == nil)
        }
    }
    
    private var favoritePlacesSection: some View {
        Section("Favoris") {
            ForEach(viewModel.favoritePlaces) { place in
                Button {
                    selectLocation(place.location)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: place.icon)
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            if let address = place.location.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var recentLocationsSection: some View {
        Section("Lieux récents") {
            let recentLocations = extractRecentLocations()
            ForEach(recentLocations.prefix(8), id: \.name) { location in
                Button {
                    selectLocation(location)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            if let address = location.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results Content
    
    @ViewBuilder
    private var searchResultsContent: some View {
        if viewModel.isSearching {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        } else if viewModel.searchResults.isEmpty {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("Aucun résultat")
                        .font(.headline)
                    
                    Text("Essayez avec d'autres termes de recherche")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        } else {
            Section("Résultats") {
                ForEach(viewModel.searchResults, id: \.self) { mapItem in
                    Button {
                        let location = viewModel.selectSearchResult(mapItem)
                        selectLocation(location)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconForMapItem(mapItem))
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mapItem.name ?? "Lieu inconnu")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                
                                if let address = formatAddress(mapItem.placemark) {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if let distance = distanceToMapItem(mapItem) {
                                Text(distance)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func selectLocation(_ location: JourneyLocation) {
        switch selectionType {
        case .departure:
            viewModel.setDeparture(location: location)
        case .arrival:
            viewModel.setArrival(location: location)
        }
        viewModel.cancelSearch()
        dismiss()
    }
    
    private func extractRecentLocations() -> [JourneyLocation] {
        var locations: [JourneyLocation] = []
        var seenNames = Set<String>()
        
        for recent in viewModel.recentJourneys {
            if !seenNames.contains(recent.departure.name) && recent.departure.name != "Ma position" {
                locations.append(recent.departure)
                seenNames.insert(recent.departure.name)
            }
            if !seenNames.contains(recent.arrival.name) {
                locations.append(recent.arrival)
                seenNames.insert(recent.arrival.name)
            }
        }
        
        return locations
    }
    
    private func iconForMapItem(_ mapItem: MKMapItem) -> String {
        if mapItem.pointOfInterestCategory == .publicTransport {
            return "tram.fill"
        }
        
        switch mapItem.pointOfInterestCategory {
        case .restaurant, .cafe, .bakery, .foodMarket:
            return "fork.knife"
        case .store, .pharmacy:
            return "cart.fill"
        case .hospital:
            return "cross.fill"
        case .school, .university, .library:
            return "graduationcap.fill"
        case .hotel:
            return "bed.double.fill"
        case .museum, .theater, .movieTheater:
            return "ticket.fill"
        case .park:
            return "leaf.fill"
        case .airport:
            return "airplane"
        case .parking:
            return "parkingsign"
        default:
            return "mappin.circle.fill"
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
    
    private func distanceToMapItem(_ mapItem: MKMapItem) -> String? {
        guard let currentLocation = currentLocation else { return nil }
        
        let itemCoord = mapItem.placemark.coordinate
        let from = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let to = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)
        
        let distance = from.distance(from: to)
        
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return "\(Int(distance)) m"
        }
    }
}

#Preview {
    LocationPickerSheet(
        viewModel: JourneyViewModel(),
        selectionType: .arrival,
        currentLocation: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    )
}
