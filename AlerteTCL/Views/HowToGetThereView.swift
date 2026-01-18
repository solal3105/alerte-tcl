import SwiftUI
import MapKit

struct HowToGetThereView: View {
    @StateObject private var viewModel = JourneyViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeparturePicker = false
    @State private var showArrivalPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                destinationHeader
                
                if viewModel.isCalculating {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.hasResults {
                    resultsView
                } else {
                    emptyStateView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Comment y aller ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDeparturePicker) {
                LocationPickerSheet(
                    viewModel: viewModel,
                    selectionType: .departure,
                    currentLocation: locationService.currentLocation?.coordinate
                )
            }
            .sheet(isPresented: $showArrivalPicker) {
                LocationPickerSheet(
                    viewModel: viewModel,
                    selectionType: .arrival,
                    currentLocation: locationService.currentLocation?.coordinate
                )
            }
            .onAppear {
                if viewModel.departureLocation == nil,
                   let coord = locationService.currentLocation?.coordinate {
                    viewModel.setDepartureToCurrentLocation(coord)
                }
            }
        }
    }
    
    // MARK: - Destination Header
    
    private var destinationHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2, height: 24)
                    
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                }
                
                VStack(spacing: 8) {
                    Button {
                        showDeparturePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.green)
                                .frame(width: 20)
                            
                            Text(viewModel.departureText.isEmpty ? "Ma position" : viewModel.departureText)
                                .foregroundStyle(viewModel.departureText.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showArrivalPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                                .frame(width: 20)
                            
                            Text(viewModel.arrivalText.isEmpty ? "Où allez-vous ?" : viewModel.arrivalText)
                                .foregroundStyle(viewModel.arrivalText.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    viewModel.swapLocations()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            
            if viewModel.arrivalLocation != nil {
                Button {
                    Task {
                        await viewModel.calculateJourneys()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Voir les options")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.background)
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(JourneyViewModel.JourneyMode.allCases, id: \.self) { mode in
                    if let journey = journeyForMode(mode) {
                        TransportOptionCard(
                            mode: mode,
                            journey: journey,
                            isSelected: viewModel.selectedMode == mode
                        ) {
                            viewModel.selectMode(mode)
                        }
                    }
                }
                
                if let journey = viewModel.currentJourney {
                    Divider()
                        .padding(.vertical, 8)
                    
                    JourneyStepsCard(journey: journey)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Recherche des itinéraires...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                Task {
                    await viewModel.calculateJourneys()
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Sélectionnez une destination")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Entrez votre destination pour voir les différentes options de transport")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private func journeyForMode(_ mode: JourneyViewModel.JourneyMode) -> Journey? {
        switch mode {
        case .transit: return viewModel.transitJourney
        case .biking: return viewModel.bikingJourney
        case .driving: return viewModel.drivingJourney
        }
    }
}

// MARK: - Transport Option Card

struct TransportOptionCard: View {
    let mode: JourneyViewModel.JourneyMode
    let journey: Journey
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(mode.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(journey.formattedDistance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(journey.formattedDuration)
                        .font(.title3.bold())
                        .foregroundStyle(mode.color)
                    
                    if mode == .transit {
                        HStack(spacing: 2) {
                            ForEach(Array(journey.transportModes.prefix(3)), id: \.self) { transportMode in
                                Image(systemName: transportMode.icon)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? mode.color : Color(.systemGray4))
            }
            .padding()
            .background(isSelected ? mode.color.opacity(0.08) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? mode.color : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Journey Steps Card

struct JourneyStepsCard: View {
    let journey: Journey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Détail du trajet")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    openInMaps()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "map")
                        Text("Plans")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(journey.steps.enumerated()), id: \.element.id) { index, step in
                    StepRow(step: step, isLast: index == journey.steps.count - 1)
                }
            }
            
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.red)
                    .frame(width: 24)
                
                Text(journey.arrival.name)
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                Text(journey.arrivalTime, style: .time)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func openInMaps() {
        let source = MKMapItem(placemark: MKPlacemark(coordinate: journey.departure.clCoordinate))
        source.name = journey.departure.name
        
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: journey.arrival.clCoordinate))
        destination.name = journey.arrival.name
        
        MKMapItem.openMaps(
            with: [source, destination],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
            ]
        )
    }
}

// MARK: - Step Row

struct StepRow: View {
    let step: JourneyStep
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(stepColor.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: step.type.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(stepColor)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2, height: 32)
                }
            }
            .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let lineName = step.lineName {
                        Text(lineName)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stepColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Text(stepDescription)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                
                HStack(spacing: 8) {
                    Text(step.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if step.distance > 100 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(step.formattedDistance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var stepDescription: String {
        switch step.type {
        case .walk:
            return "Marcher"
        case .bike:
            return "Vélo"
        case .transit:
            if let direction = step.direction {
                return "→ \(direction)"
            }
            return step.instructions
        case .drive:
            return "Conduire"
        }
    }
    
    private var stepColor: Color {
        switch step.type {
        case .walk: return .green
        case .bike: return .green
        case .transit:
            if let mode = step.transportMode {
                switch mode {
                case .metro: return .orange
                case .tram: return .blue
                case .bus: return .purple
                case .train: return .red
                default: return .blue
                }
            }
            return .blue
        case .drive: return .blue
        }
    }
}

#Preview {
    HowToGetThereView()
}
