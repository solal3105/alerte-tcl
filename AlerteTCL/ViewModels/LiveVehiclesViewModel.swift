import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

@MainActor
final class LiveVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var animatedVehicles: [String: AnimatedVehicle] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var selectedVehicleType: VehicleType?
    @Published var selectedLine: String?
    @Published var mapRegion: MKCoordinateRegion
    @Published var isAutoRefreshEnabled = true
    @Published var currentZoomLevel: Double = 0.15
    
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 30
    private var cancellables = Set<AnyCancellable>()
    
    private static let lyonCenter = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    
    static let clusteringZoomThreshold: Double = 0.08
    
    init() {
        if LocationService.shared.isLocationAvailable,
           let userLocation = LocationService.shared.currentLocation {
            self.mapRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: Self.defaultSpan
            )
        } else {
            self.mapRegion = MKCoordinateRegion(
                center: Self.lyonCenter,
                span: Self.defaultSpan
            )
        }
        
        LocationService.shared.$currentLocation
            .compactMap { $0 }
            .first()
            .sink { [weak self] location in
                guard let self = self else { return }
                withAnimation {
                    self.mapRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: Self.defaultSpan
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    var filteredVehicles: [Vehicle] {
        var result = vehicles
        
        if let type = selectedVehicleType {
            result = result.filter { $0.vehicleType == type }
        }
        
        if let line = selectedLine, !line.isEmpty {
            result = result.filter { $0.lineName == line }
        }
        
        return result
    }
    
    var shouldShowClusters: Bool {
        currentZoomLevel > Self.clusteringZoomThreshold
    }
    
    var clusters: [VehicleCluster] {
        guard shouldShowClusters else { return [] }
        return createClusters(from: filteredVehicles)
    }
    
    var vehiclesByType: [VehicleType: [Vehicle]] {
        Dictionary(grouping: filteredVehicles) { $0.vehicleType }
    }
    
    var availableLines: [String] {
        let linesToFilter: [Vehicle]
        if let type = selectedVehicleType {
            linesToFilter = vehicles.filter { $0.vehicleType == type }
        } else {
            linesToFilter = vehicles
        }
        
        return Array(Set(linesToFilter.map { $0.lineName })).sorted { line1, line2 in
            let vehicle1 = vehicles.first { $0.lineName == line1 }
            let vehicle2 = vehicles.first { $0.lineName == line2 }
            
            let type1 = vehicle1?.vehicleType.sortOrder ?? Int.max
            let type2 = vehicle2?.vehicleType.sortOrder ?? Int.max
            
            if type1 != type2 {
                return type1 < type2
            }
            
            let num1 = Int(line1.filter { $0.isNumber }) ?? Int.max
            let num2 = Int(line2.filter { $0.isNumber }) ?? Int.max
            if num1 != num2 {
                return num1 < num2
            }
            return line1 < line2
        }
    }
    
    func vehicleTypeForLine(_ line: String) -> VehicleType? {
        vehicles.first { $0.lineName == line }?.vehicleType
    }
    
    var vehicleTypeStats: [(type: VehicleType, count: Int)] {
        VehicleType.allCases
            .map { type in (type: type, count: vehicles.filter { $0.vehicleType == type }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
    }
    
    func loadVehicles() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedVehicles = try await SIRILiteService.shared.fetchVehiclePositions()
            
            updateAnimatedVehicles(with: fetchedVehicles)
            
            vehicles = fetchedVehicles
            lastUpdate = Date()
            error = nil
        } catch let siriError as SIRIError {
            self.error = siriError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func updateAnimatedVehicles(with newVehicles: [Vehicle]) {
        var newAnimatedVehicles: [String: AnimatedVehicle] = [:]
        
        for vehicle in newVehicles {
            let previousVehicle = vehicles.first { $0.id == vehicle.id }
            let animated = AnimatedVehicle(vehicle: vehicle, previousVehicle: previousVehicle)
            animated.startAnimation()
            newAnimatedVehicles[vehicle.id] = animated
        }
        
        for (_, animated) in animatedVehicles {
            animated.stopAnimation()
        }
        
        animatedVehicles = newAnimatedVehicles
    }
    
    private func createClusters(from vehicles: [Vehicle]) -> [VehicleCluster] {
        guard !vehicles.isEmpty else { return [] }
        
        let clusterRadius = currentZoomLevel * 0.15
        var clustered: Set<String> = []
        var clusters: [VehicleCluster] = []
        
        for vehicle in vehicles {
            guard !clustered.contains(vehicle.id) else { continue }
            
            var clusterVehicles = [vehicle]
            clustered.insert(vehicle.id)
            
            for other in vehicles {
                guard !clustered.contains(other.id) else { continue }
                
                let distance = sqrt(
                    pow(vehicle.latitude - other.latitude, 2) +
                    pow(vehicle.longitude - other.longitude, 2)
                )
                
                if distance < clusterRadius {
                    clusterVehicles.append(other)
                    clustered.insert(other.id)
                }
            }
            
            if clusterVehicles.count > 1 {
                clusters.append(VehicleCluster(vehicles: clusterVehicles))
            }
        }
        
        return clusters
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTask = Task {
            while !Task.isCancelled && isAutoRefreshEnabled {
                await loadVehicles()
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        
        for (_, animated) in animatedVehicles {
            animated.stopAnimation()
        }
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
    }
    
    func centerOnLyon() {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: Self.lyonCenter,
                span: Self.defaultSpan
            )
        }
    }
    
    func centerOnVehicle(_ vehicle: Vehicle) {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: vehicle.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    func clearFilters() {
        selectedVehicleType = nil
        selectedLine = nil
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
