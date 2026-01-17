import SwiftUI
import MapKit

// MARK: - Merged Stop Marker (groupes d'arrêts fusionnés)

struct MergedStopMarker: View {
    let mergedStop: MergedStop
    let currentZoomLevel: Double
    
    private var shouldShowTooltip: Bool {
        currentZoomLevel < 0.005
    }
    
    private var allLines: [String] {
        mergedStop.allLines
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Tooltip avec lignes (même style que TransitStopMarker)
            if shouldShowTooltip && !allLines.isEmpty {
                HStack(spacing: 4) {
                    ForEach(allLines.prefix(3), id: \.self) { line in
                        let bgColor = LineColorHelper.backgroundColor(for: line)
                        let textColor = LineColorHelper.textColor(for: line)
                        let needsBorder = LineColorHelper.needsBorder(for: line)
                        
                        Text(line)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(bgColor)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(.systemGray3), lineWidth: needsBorder ? 0.5 : 0)
                            )
                    }
                    if allLines.count > 3 {
                        Text("+\(allLines.count - 3)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            // Point de l'arrêt (même style que TransitStopMarker)
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 5, height: 5)
                )
                .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 0.5)
        }
    }
}

// MARK: - Transit Stop Marker (legacy, kept for compatibility)

struct TransitStopMarker: View {
    let stop: TransitStop
    let currentZoomLevel: Double
    
    private var shouldShowTooltip: Bool {
        currentZoomLevel < 0.005
    }
    
    var body: some View {
        VStack(spacing: 2) {
            if shouldShowTooltip && !stop.lines.isEmpty {
                HStack(spacing: 4) {
                    ForEach(stop.lines.prefix(3), id: \.self) { line in
                        let bgColor = LineColorHelper.backgroundColor(for: line)
                        let textColor = LineColorHelper.textColor(for: line)
                        let needsBorder = LineColorHelper.needsBorder(for: line)
                        
                        Text(line)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(bgColor)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(.systemGray3), lineWidth: needsBorder ? 0.5 : 0)
                            )
                    }
                    if stop.lines.count > 3 {
                        Text("+\(stop.lines.count - 3)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 5, height: 5)
                )
                .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 0.5)
        }
    }
}

// MARK: - Transit Stop Detail Sheet

struct TransitStopDetailSheet: View {
    let stop: TransitStop
    let viewModel: LiveVehiclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var localStop: TransitStop
    @State private var isLoading = false
    
    init(stop: TransitStop, viewModel: LiveVehiclesViewModel) {
        self.stop = stop
        self.viewModel = viewModel
        self._localStop = State(initialValue: stop)
    }
    
    /// Clé unique pour grouper par ligne ET direction
    private struct LineDirectionKey: Hashable {
        let line: String
        let direction: String
    }
    
    private var passagesByLineDirection: [LineDirectionKey: [Passage]] {
        Dictionary(grouping: localStop.passages) { LineDirectionKey(line: $0.ligne, direction: $0.direction) }
    }
    
    private var sortedLineDirections: [LineDirectionKey] {
        passagesByLineDirection.keys.sorted { key1, key2 in
            let mode1 = TransportMode.detectFromLine(key1.line)
            let mode2 = TransportMode.detectFromLine(key2.line)
            if mode1.sortOrder != mode2.sortOrder {
                return mode1.sortOrder < mode2.sortOrder
            }
            if key1.line != key2.line {
                return key1.line < key2.line
            }
            return key1.direction < key2.direction
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerSection
                    
                    // Passages par ligne
                    if isLoading || localStop.isLoadingPassages {
                        loadingState
                    } else if localStop.passages.isEmpty {
                        emptyState
                    } else {
                        passagesSection
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Charger tous les passages au clic
            if localStop.passages.isEmpty && !localStop.isLoadingPassages {
                isLoading = true
                Task { @MainActor in
                    await viewModel.loadAllPassagesForStop(stopId: stop.id)
                    // Récupérer l'arrêt mis à jour
                    if let updatedStop = viewModel.transitStops.first(where: { $0.id == stop.id }) {
                        localStop = updatedStop
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icône
            Image(systemName: "tram.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Nom de l'arrêt
            Text(localStop.nom)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Commune
            Text(localStop.commune)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Lignes desservies
            if !localStop.lines.isEmpty {
                HStack(spacing: 6) {
                    ForEach(localStop.lines.prefix(6), id: \.self) { line in
                        LineBadge(line: line)
                    }
                    if localStop.lines.count > 6 {
                        Text("+\(localStop.lines.count - 6)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Accessibilité PMR
            if localStop.pmr {
                HStack(spacing: 4) {
                    Image(systemName: "figure.roll")
                        .foregroundStyle(.blue)
                    Text("Accessible PMR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var passagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Prochains passages", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            ForEach(sortedLineDirections, id: \.self) { key in
                if let linePassages = passagesByLineDirection[key] {
                    LinePassagesCard(line: key.line, direction: key.direction, passages: linePassages)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Chargement des passages...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Aucun passage prévu")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Les horaires seront affichés quand des véhicules seront en approche")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Line Badge (réutilisable)

struct LineBadge: View {
    let line: String
    var size: CGFloat = 11
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: line)
    }
    
    private var textColor: Color {
        LineColorHelper.textColor(for: line)
    }
    
    private var needsBorder: Bool {
        LineColorHelper.needsBorder(for: line)
    }
    
    var body: some View {
        Text(line)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
            )
    }
}

// MARK: - Line Passages Card

struct LinePassagesCard: View {
    let line: String
    let direction: String
    let passages: [Passage]
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: line)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ligne header
            HStack {
                LineBadge(line: line, size: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Direction")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(direction)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Liste des passages
            HStack(spacing: 8) {
                ForEach(passages.prefix(4)) { passage in
                    PassageChip(passage: passage, color: bgColor)
                }
            }
        }
        .padding(16)
        .background(bgColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Passage Chip

struct PassageChip: View {
    let passage: Passage
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            // Délai en minutes
            Text(passage.delaipassage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(.systemGray))
            
            // Heure de passage
            Text(passage.formattedTime)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Merged Stop Detail Sheet (affiche les passages de TOUS les arrêts fusionnés)

struct MergedStopDetailSheet: View {
    let mergedStop: MergedStop
    let viewModel: LiveVehiclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var allPassages: [Passage] = []
    @State private var isLoading = false
    
    /// Clé unique pour grouper par ligne ET direction
    private struct LineDirectionKey: Hashable {
        let line: String
        let direction: String
    }
    
    private var passagesByLineDirection: [LineDirectionKey: [Passage]] {
        Dictionary(grouping: allPassages) { LineDirectionKey(line: $0.ligne, direction: $0.direction) }
    }
    
    private var sortedLineDirections: [LineDirectionKey] {
        passagesByLineDirection.keys.sorted { key1, key2 in
            let mode1 = TransportMode.detectFromLine(key1.line)
            let mode2 = TransportMode.detectFromLine(key2.line)
            if mode1.sortOrder != mode2.sortOrder {
                return mode1.sortOrder < mode2.sortOrder
            }
            if key1.line != key2.line {
                return key1.line < key2.line
            }
            return key1.direction < key2.direction
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    
                    if isLoading {
                        loadingState
                    } else if allPassages.isEmpty {
                        emptyState
                    } else {
                        passagesSection
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadAllPassages()
        }
    }
    
    private func loadAllPassages() {
        isLoading = true
        Task { @MainActor in
            // Charger les passages de TOUS les arrêts du groupe
            for stop in mergedStop.stops {
                await viewModel.loadAllPassagesForStop(stopId: stop.id)
            }
            
            // Collecter tous les passages
            var passages: [Passage] = []
            for stop in mergedStop.stops {
                if let updatedStop = viewModel.transitStops.first(where: { $0.id == stop.id }) {
                    passages.append(contentsOf: updatedStop.passages)
                }
            }
            
            // Trier par heure et dédupliquer
            allPassages = passages.sorted { p1, p2 in
                p1.heurepassage < p2.heurepassage
            }
            
            isLoading = false
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icône (même style que TransitStopDetailSheet)
            Image(systemName: "tram.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Nom de l'arrêt
            Text(mergedStop.nom)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Lignes desservies
            if !mergedStop.allLines.isEmpty {
                HStack(spacing: 6) {
                    ForEach(mergedStop.allLines.prefix(6), id: \.self) { line in
                        LineBadge(line: line)
                    }
                    if mergedStop.allLines.count > 6 {
                        Text("+\(mergedStop.allLines.count - 6)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Accessibilité PMR
            if mergedStop.pmr {
                HStack(spacing: 4) {
                    Image(systemName: "figure.roll")
                        .foregroundStyle(.blue)
                    Text("Accessible PMR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var passagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Prochains passages", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            ForEach(sortedLineDirections, id: \.self) { key in
                if let linePassages = passagesByLineDirection[key] {
                    LinePassagesCard(line: key.line, direction: key.direction, passages: linePassages)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Chargement des passages...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Aucun passage prévu")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Les horaires seront affichés quand des véhicules seront en approche")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    let vm = LiveVehiclesViewModel()
    return TransitStopDetailSheet(
        stop: TransitStop(
            id: 1,
            nom: "Bellecour",
            commune: "Lyon 2e",
            adresse: "Place Bellecour",
            coordinate: CLLocationCoordinate2D(latitude: 45.757, longitude: 4.832),
            desserte: "MA:A,MA:R,MD:A,MD:R,T1:A,T1:R",
            pmr: true,
            passages: [
                Passage(stopId: 1, ligne: "MA", direction: "Vaulx-en-Velin", delaipassage: "2 min", heurepassage: "2026-01-14 10:30:00", type: "R"),
                Passage(stopId: 1, ligne: "MA", direction: "Vaulx-en-Velin", delaipassage: "7 min", heurepassage: "2026-01-14 10:35:00", type: "T"),
                Passage(stopId: 1, ligne: "T1", direction: "IUT Feyssine", delaipassage: "3 min", heurepassage: "2026-01-14 10:31:00", type: "R")
            ]
        ),
        viewModel: vm
    )
}
