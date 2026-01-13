import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
final class TravauxViewModel: ObservableObject {
    @Published var travaux: [Travaux] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    
    @Published var selectedImportance: Set<TravauxImportance> = Set(TravauxImportance.allCases)
    @Published var selectedPerturbation: Set<TravauxPerturbation> = Set(TravauxPerturbation.allCases)
    @Published var searchText: String = ""
    
    @Published var refreshProgress: Double = 0.0
    @Published var secondsUntilNextRefresh: Int = 300
    
    private var refreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Computed Properties
    
    var filteredTravaux: [Travaux] {
        var result = travaux
        
        // Filter by importance
        result = result.filter { selectedImportance.contains($0.importance) }
        
        // Filter by perturbation type
        result = result.filter { selectedPerturbation.contains($0.typeperturbation) }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.nom.localizedCaseInsensitiveContains(searchText) ||
                $0.nomChantier.localizedCaseInsensitiveContains(searchText) ||
                $0.commune.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by importance (most disruptive first)
        return result.sorted { $0.importance < $1.importance }
    }
    
    var travauxEnCours: Int {
        travaux.filter { $0.avancement == .enCours }.count
    }
    
    var travauxTresPerturbants: Int {
        travaux.filter { $0.importance == .tresPerturbant }.count
    }
    
    var travauxParCommune: [String: Int] {
        Dictionary(grouping: travaux) { $0.commune }
            .mapValues { $0.count }
    }
    
    var hasActiveFilters: Bool {
        selectedImportance.count < TravauxImportance.allCases.count ||
        selectedPerturbation.count < TravauxPerturbation.allCases.count ||
        !searchText.isEmpty
    }
    
    // MARK: - Lifecycle
    
    func onAppear() {
        // Charger les données en arrière-plan sans bloquer l'affichage
        Task(priority: .userInitiated) {
            await loadTravaux()
            startAutoRefresh()
        }
    }
    
    func onDisappear() {
        stopAutoRefresh()
    }
    
    // MARK: - Data Loading
    
    func loadTravaux() async {
        isLoading = true
        error = nil
        
        do {
            let fetchedTravaux = try await TravauxService.shared.fetchTravaux()
            travaux = fetchedTravaux
            lastUpdate = Date()
            resetCountdown()
        } catch {
            self.error = error.localizedDescription
            print("❌ TravauxViewModel: Erreur de chargement: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await loadTravaux()
            }
        }
        
        // Countdown timer
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                
                if secondsUntilNextRefresh > 0 {
                    secondsUntilNextRefresh -= 1
                    refreshProgress = 1.0 - (Double(secondsUntilNextRefresh) / refreshInterval)
                }
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }
    
    private func resetCountdown() {
        secondsUntilNextRefresh = Int(refreshInterval)
        refreshProgress = 0.0
    }
    
    // MARK: - Filters
    
    func toggleImportance(_ importance: TravauxImportance) {
        if selectedImportance.contains(importance) {
            selectedImportance.remove(importance)
        } else {
            selectedImportance.insert(importance)
        }
    }
    
    func togglePerturbation(_ perturbation: TravauxPerturbation) {
        if selectedPerturbation.contains(perturbation) {
            selectedPerturbation.remove(perturbation)
        } else {
            selectedPerturbation.insert(perturbation)
        }
    }
    
    func resetFilters() {
        selectedImportance = Set(TravauxImportance.allCases)
        selectedPerturbation = Set(TravauxPerturbation.allCases)
        searchText = ""
    }
    
    deinit {
        refreshTask?.cancel()
        countdownTask?.cancel()
    }
}
