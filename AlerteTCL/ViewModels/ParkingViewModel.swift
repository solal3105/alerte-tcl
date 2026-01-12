import Foundation
import MapKit
import Combine

@MainActor
final class ParkingViewModel: ObservableObject {
    @Published var parkings: [Parking] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var secondsUntilNextRefresh: Int = 60
    @Published var refreshProgress: Double = 0.0
    @Published var isViewActive = false
    
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    
    private var refreshTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60
    
    var totalPlacesDisponibles: Int {
        parkings.reduce(0) { $0 + $1.placesDisponibles }
    }
    
    var totalCapacite: Int {
        parkings.reduce(0) { $0 + $1.capaciteTotale }
    }
    
    var parkingsOuverts: Int {
        parkings.filter { $0.etat == .ouvert }.count
    }
    
    var parkingsAvecPlaces: Int {
        parkings.filter { $0.placesDisponibles > 0 && $0.etat == .ouvert }.count
    }
    
    func loadParkings() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedParkings = try await ParkingService.shared.fetchParkings()
            parkings = fetchedParkings.sorted { $0.nom < $1.nom }
            lastUpdate = Date()
            secondsUntilNextRefresh = Int(refreshInterval)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTask = Task {
            while !Task.isCancelled && isViewActive {
                await loadParkings()
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
            }
        }
        
        progressTask = Task {
            while !Task.isCancelled && isViewActive {
                let startTime = Date()
                while !Task.isCancelled && isViewActive {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / refreshInterval, 1.0)
                    let remaining = max(0, refreshInterval - elapsed)
                    
                    self.refreshProgress = progress
                    self.secondsUntilNextRefresh = Int(ceil(remaining))
                    
                    if elapsed >= refreshInterval {
                        break
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        progressTask?.cancel()
        progressTask = nil
    }
    
    func onAppear() {
        isViewActive = true
        startAutoRefresh()
    }
    
    func onDisappear() {
        isViewActive = false
        stopAutoRefresh()
    }
}
