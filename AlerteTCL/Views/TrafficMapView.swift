import SwiftUI
import MapKit

struct TrafficMapView: View {
    @StateObject private var viewModel = TrafficViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedEvent: TrafficEvent?
    @State private var showFilters = false
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    var body: some View {
        ZStack {
            mapContent
            
            // Indicateur de chargement progressif
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    // Barre de progression
                    VStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            // Fond de la barre
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            // Progression
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: max(0, viewModel.loadingProgress * 280), height: 8)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.loadingProgress)
                        }
                        .frame(width: 280)
                        
                        // Message de progression
                        if !viewModel.loadingMessage.isEmpty {
                            Text(viewModel.loadingMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Spinner
                    ProgressView()
                        .tint(.blue)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
            
            overlayControls
        }
        .sheet(item: $selectedEvent) { event in
            TrafficEventDetailSheet(event: event)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilters) {
            TrafficFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            locationService.requestPermission()
            locationService.startUpdatingLocation()
            
            // Centrer sur la localisation utilisateur avec un zoom plus serré
            if let userLocation = locationService.currentLocation {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
                viewModel.updateMapRegion(MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            
            await viewModel.loadData()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
    
    // MARK: - Map Content
    
    private var mapContent: some View {
        Map(position: $mapCameraPosition, interactionModes: .all) {
            UserAnnotation()
            
            // Afficher les segments de trafic (polylignes)
            if viewModel.showTrafficState {
                ForEach(viewModel.filteredSegments) { segment in
                    MapPolyline(coordinates: segment.clLocationCoordinates)
                        .stroke(segment.color, lineWidth: 3)
                }
            }
            
            // Afficher les événements routiers
            if viewModel.showEvents {
                ForEach(viewModel.filteredEvents) { event in
                    Annotation("", coordinate: event.coordinate) {
                        TrafficEventMarker(event: event)
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .top)
        .onMapCameraChange { context in
            viewModel.updateZoomLevel(context.region.span)
            viewModel.updateMapRegion(context.region)
        }
    }
    
    // MARK: - Overlay Controls
    
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .bottom) {
                Spacer()
                
                // Boutons en bas à droite
                VStack(spacing: 16) {
                    // Bouton filtres
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.hasActiveFilters ? .blue : .gray)
                    .controlSize(.large)
                    
                    // Bouton localisation
                    Button {
                        centerOnUserLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    
                    // Bouton refresh
                    Button {
                        Task {
                            await viewModel.loadData()
                        }
                    } label: {
                        Image(systemName: viewModel.isLoading ? "arrow.clockwise.circle" : "arrow.clockwise")
                            .font(.system(size: 22, weight: .semibold))
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                    .disabled(viewModel.isLoading)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func centerOnUserLocation() {
        if let location = locationService.currentLocation {
            withAnimation {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
}

// MARK: - Traffic Event Marker

struct TrafficEventMarker: View {
    let event: TrafficEvent
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            Circle()
                .fill(event.color)
                .frame(width: 32, height: 32)
            
            Image(systemName: event.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Traffic Event Detail Sheet

struct TrafficEventDetailSheet: View {
    let event: TrafficEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        ZStack {
                            Circle()
                                .fill(event.color)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: event.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(event.eventType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(event.title)
                                .font(.title3.bold())
                        }
                        
                        Spacer()
                        
                        Text(event.severity.displayName)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(event.severity.color.opacity(0.2))
                            .foregroundColor(event.severity.color)
                            .clipShape(Capsule())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Description
                    if !event.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.headline)
                            
                            Text(event.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Localisation
                    if let roadName = event.roadName {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Localisation", systemImage: "mappin.and.ellipse")
                                .font(.headline)
                            
                            Text(roadName)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Dates
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Période", systemImage: "calendar")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Début")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let startDate = event.startDate {
                                    Text(startDate, style: .date)
                                        .font(.subheadline)
                                    Text(startDate, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Non renseigné")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Fin")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let endDate = event.endDate {
                                    Text(endDate, style: .date)
                                        .font(.subheadline)
                                    Text(endDate, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("En cours")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Coordonnées
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Coordonnées", systemImage: "location")
                            .font(.headline)
                        
                        Text(String(format: "%.6f, %.6f", event.latitude, event.longitude))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Détail événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Traffic Filter Sheet

struct TrafficFilterSheet: View {
    @ObservedObject var viewModel: TrafficViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Toggle général
                Section {
                    Toggle("Afficher les événements", isOn: $viewModel.showEvents)
                    Toggle("Afficher l'état du trafic", isOn: $viewModel.showTrafficState)
                }
                
                // Types d'événements
                Section {
                    HStack {
                        Text("Types d'événements")
                            .font(.headline)
                        Spacer()
                        Button(viewModel.selectedEventTypes.count == TrafficEventType.allCases.count ? "Aucun" : "Tous") {
                            if viewModel.selectedEventTypes.count == TrafficEventType.allCases.count {
                                viewModel.deselectAllEventTypes()
                            } else {
                                viewModel.selectAllEventTypes()
                            }
                        }
                        .font(.caption)
                    }
                    
                    ForEach(TrafficEventType.allCases, id: \.self) { type in
                        Button {
                            viewModel.toggleEventType(type)
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                Text(type.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if viewModel.selectedEventTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                                
                                if let count = viewModel.eventsByType[type] {
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                
                // Fluidité du trafic
                Section {
                    HStack {
                        Text("État du trafic")
                            .font(.headline)
                        Spacer()
                        Button(viewModel.selectedFluidity.count == TrafficFluidity.allCases.count ? "Aucun" : "Tous") {
                            if viewModel.selectedFluidity.count == TrafficFluidity.allCases.count {
                                viewModel.deselectAllFluidity()
                            } else {
                                viewModel.selectAllFluidity()
                            }
                        }
                        .font(.caption)
                    }
                    
                    ForEach(TrafficFluidity.allCases, id: \.self) { fluidity in
                        Button {
                            viewModel.toggleFluidity(fluidity)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(fluidity.color)
                                    .frame(width: 16, height: 16)
                                
                                Text(fluidity.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if viewModel.selectedFluidity.contains(fluidity) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Réinitialiser
                Section {
                    Button("Réinitialiser les filtres") {
                        viewModel.resetFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TrafficMapView()
}
