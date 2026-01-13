import SwiftUI
import MapKit
import CoreLocation

struct TravauxMapView: View {
    @StateObject private var viewModel = TravauxViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedTravaux: Travaux?
    @State private var showFilters = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var currentSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    @State private var currentCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    @State private var hasSetInitialLocation = false
    
    // Afficher les polygones à partir d'un zoom moyen
    private var shouldShowPolygons: Bool {
        currentSpan.latitudeDelta < 0.03 // Zoom moyen (< 3km)
    }
    
    // Filtrer les travaux visibles dans le viewport
    private var visibleTravaux: [Travaux] {
        let buffer = 1.5 // Buffer pour charger un peu au-delà du viewport
        let latDelta = currentSpan.latitudeDelta * buffer
        let lonDelta = currentSpan.longitudeDelta * buffer
        
        let minLat = currentCenter.latitude - latDelta / 2
        let maxLat = currentCenter.latitude + latDelta / 2
        let minLon = currentCenter.longitude - lonDelta / 2
        let maxLon = currentCenter.longitude + lonDelta / 2
        
        return viewModel.filteredTravaux.filter { travaux in
            travaux.centroid.latitude >= minLat &&
            travaux.centroid.latitude <= maxLat &&
            travaux.centroid.longitude >= minLon &&
            travaux.centroid.longitude <= maxLon
        }
    }
    
    var body: some View {
        ZStack {
            mapContent
            overlayControls
        }
        .sheet(item: $selectedTravaux) { travaux in
            TravauxDetailSheet(travaux: travaux)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilters) {
            TravauxFiltersSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            locationService.requestPermission()
            locationService.startUpdatingLocation()
            
            if let userLocation = locationService.currentLocation {
                mapCameraPosition = .region(
                    MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
                hasSetInitialLocation = true
            }
            
            viewModel.onAppear()
        }
        .onChange(of: locationService.currentLocation) { oldValue, newValue in
            if !hasSetInitialLocation, let newLocation = newValue {
                withAnimation(.easeInOut(duration: 0.8)) {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: newLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
                hasSetInitialLocation = true
            }
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition) {
                // Afficher les polygones seulement en zoom moyen
                if shouldShowPolygons {
                    ForEach(visibleTravaux) { travaux in
                        ForEach(travaux.coordinates.indices, id: \.self) { index in
                            MapPolygon(coordinates: travaux.coordinates[index])
                                .foregroundStyle(polygonColor(for: travaux).opacity(0.3))
                                .stroke(polygonColor(for: travaux), lineWidth: 2)
                        }
                    }
                }
                
                // Markers avec clustering natif MapKit
                ForEach(visibleTravaux) { travaux in
                    Annotation(travaux.nomChantier, coordinate: travaux.centroid, anchor: .bottom) {
                        TravauxMarker(travaux: travaux)
                            .onTapGesture {
                                selectedTravaux = travaux
                            }
                    }
                    .annotationTitles(.hidden)
                    .tag(travaux.id)
                }
                
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.visible)
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange { context in
                currentSpan = context.region.span
                currentCenter = context.region.center
            }
            .overlay {
                if viewModel.isLoading && viewModel.travaux.isEmpty {
                    loadingOverlay
                }
                
                if let error = viewModel.error, viewModel.travaux.isEmpty {
                    errorOverlay(error)
                }
            }
        }
    }
    
    private func polygonColor(for travaux: Travaux) -> Color {
        switch travaux.importance {
        case .tresPerturbant: return .red
        case .perturbant: return .orange
        case .peuPerturbant: return .yellow
        case .inconnu: return .gray
        }
    }
    
    
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Chargement des travaux...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
    }
    
    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Erreur de chargement")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                Task { await viewModel.loadTravaux() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
        .padding(20)
    }
    
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .bottom) {
                // Refresh card en bas à gauche
                refreshCard
                
                Spacer()
                
                // Boutons à droite
                VStack(spacing: 12) {
                    // Bouton filtres
                    Button {
                        showFilters = true
                    } label: {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                            
                            if viewModel.hasActiveFilters {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    
                    // Bouton localisation
                    Button {
                        if let userLocation = locationService.currentLocation {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                mapCameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: userLocation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    )
                                )
                            }
                        } else {
                            locationService.requestPermission()
                            locationService.startUpdatingLocation()
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.travaux.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("chantiers actifs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.travauxTresPerturbants)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Text("très perturbants")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
    
    private var refreshCard: some View {
        Button {
            Task { await viewModel.loadTravaux() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.refreshProgress)
                        .stroke(
                            Color.orange,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: viewModel.refreshProgress)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                
                if !viewModel.isLoading {
                    Text("dans \(formatRefreshTime(viewModel.secondsUntilNextRefresh))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .padding(.leading, 24)
        .padding(.bottom, 24)
    }
    
    private func formatRefreshTime(_ seconds: Int) -> String {
        if seconds >= 60 {
            return "\(seconds / 60)m"
        }
        return "\(seconds)s"
    }
}

// MARK: - Travaux Marker

struct TravauxMarker: View {
    let travaux: Travaux
    
    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 44, height: 44)
                .shadow(color: markerColor.opacity(0.4), radius: 6, x: 0, y: 3)
            
            Image(systemName: travaux.type.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            importanceBadge
                .offset(x: 16, y: -16)
        )
    }
    
    private var markerColor: Color {
        switch travaux.importance {
        case .tresPerturbant: return .red
        case .perturbant: return .orange
        case .peuPerturbant: return .yellow
        case .inconnu: return .gray
        }
    }
    
    private var importanceBadge: some View {
        Group {
            switch travaux.importance {
            case .tresPerturbant:
                Circle()
                    .fill(.red)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text("!")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    )
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            case .perturbant:
                Circle()
                    .fill(.orange)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Travaux Detail Sheet

struct TravauxDetailSheet: View {
    let travaux: Travaux
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Dates
                    datesCard
                    
                    // Perturbation info
                    perturbationCard
                    
                    // Localisation
                    localisationCard
                    
                    // Navigation button
                    navigationButton
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Détails du chantier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Type de travaux avec icône
            HStack(spacing: 8) {
                Image(systemName: travaux.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(travaux.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(typeColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(typeColor.opacity(0.15))
            .clipShape(Capsule())
            
            // Importance badge
            HStack {
                Image(systemName: travaux.importance.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(travaux.importance.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(importanceColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(importanceColor.opacity(0.15))
            .clipShape(Capsule())
            
            // Nom du chantier
            Text(travaux.nomChantier)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Rue
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .foregroundStyle(.secondary)
                Text(travaux.nom)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            
            // Commune
            Text(travaux.commune)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Période", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.blue)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Début")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let debut = travaux.debutChantier {
                        Text(debut.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("Non spécifié")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fin prévue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let fin = travaux.finChantier {
                        Text(fin.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("Non spécifié")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Jours restants
            if let remaining = travaux.remainingDays, remaining > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.orange)
                    Text("\(remaining) jours restants")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
            
            // Avancement
            HStack {
                Image(systemName: travaux.avancement.icon)
                    .foregroundStyle(avancementColor)
                Text(travaux.avancement.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(avancementColor)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var perturbationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Impact sur la circulation", systemImage: "car.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            HStack {
                Image(systemName: travaux.typeperturbation.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(perturbationColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(travaux.typeperturbation.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            .padding(16)
            .background(perturbationColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if let description = travaux.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var localisationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Localisation", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(.green)
            
            if let precision = travaux.precisionLocalisation, !precision.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(precision)
                        .font(.subheadline)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Intervenant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(travaux.intervenant)
                        .font(.subheadline)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var navigationButton: some View {
        Button {
            openInMaps()
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Voir sur la carte")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .controlSize(.large)
    }
    
    private var typeColor: Color {
        switch travaux.type {
        case .tramway: return .blue
        case .metro: return .purple
        case .voirie: return .gray
        case .eau: return .cyan
        case .gaz: return .orange
        case .electricite: return .yellow
        case .assainissement: return .brown
        case .telecom: return .green
        case .chauffage: return .red
        case .pisteCyclable: return .mint
        case .autre: return .gray
        }
    }
    
    private var importanceColor: Color {
        switch travaux.importance {
        case .tresPerturbant: return .red
        case .perturbant: return .orange
        case .peuPerturbant: return .yellow
        case .inconnu: return .gray
        }
    }
    
    private var avancementColor: Color {
        switch travaux.avancement {
        case .enCours: return .orange
        case .prevu: return .blue
        case .termine: return .green
        case .inconnu: return .gray
        }
    }
    
    private var perturbationColor: Color {
        switch travaux.typeperturbation {
        case .circulationInterdite: return .red
        case .circulationReduite: return .orange
        case .circulationAlternee: return .yellow
        case .genePonctuelle: return .blue
        case .autre: return .gray
        }
    }
    
    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: travaux.centroid)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = travaux.nomChantier
        mapItem.openInMaps()
    }
}

// MARK: - Filters Sheet

struct TravauxFiltersSheet: View {
    @ObservedObject var viewModel: TravauxViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Importance") {
                    ForEach(TravauxImportance.allCases, id: \.self) { importance in
                        Button {
                            viewModel.toggleImportance(importance)
                        } label: {
                            HStack {
                                Image(systemName: importance.icon)
                                    .foregroundStyle(colorFor(importance))
                                    .frame(width: 24)
                                
                                Text(importance.displayName)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if viewModel.selectedImportance.contains(importance) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Type de perturbation") {
                    ForEach(TravauxPerturbation.allCases, id: \.self) { perturbation in
                        Button {
                            viewModel.togglePerturbation(perturbation)
                        } label: {
                            HStack {
                                Image(systemName: perturbation.icon)
                                    .foregroundStyle(colorForPerturbation(perturbation))
                                    .frame(width: 24)
                                
                                Text(perturbation.displayName)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if viewModel.selectedPerturbation.contains(perturbation) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button("Réinitialiser les filtres") {
                        viewModel.resetFilters()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func colorFor(_ importance: TravauxImportance) -> Color {
        switch importance {
        case .tresPerturbant: return .red
        case .perturbant: return .orange
        case .peuPerturbant: return .yellow
        case .inconnu: return .gray
        }
    }
    
    private func colorForPerturbation(_ perturbation: TravauxPerturbation) -> Color {
        switch perturbation {
        case .circulationInterdite: return .red
        case .circulationReduite: return .orange
        case .circulationAlternee: return .yellow
        case .genePonctuelle: return .blue
        case .autre: return .gray
        }
    }
}

// MARK: - Travaux Cluster

struct TravauxCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let travaux: [Travaux]
}

struct TravauxClusterMarker: View {
    let cluster: TravauxCluster
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.orange)
                .frame(width: 50, height: 50)
                .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 3)
            
            VStack(spacing: 2) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(cluster.travaux.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TravauxMapView()
}
