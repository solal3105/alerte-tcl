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
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
                hasSetInitialLocation = true
            }
            
            // Charger les travaux en arrière-plan
            Task { @MainActor in
                await self.viewModel.loadTravaux()
            }
            
            viewModel.onAppear()
        }
        .onChange(of: locationService.currentLocation) { oldValue, newValue in
            if !hasSetInitialLocation, let newLocation = newValue {
                withAnimation(.easeInOut(duration: 0.8)) {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: newLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
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
                // Afficher les polygones pour les travaux qui ne sont PAS dans des clusters
                if shouldShowPolygons {
                    let nonClusteredTravaux = viewModel.nonClusteredTravaux
                    
                    ForEach(nonClusteredTravaux.indices, id: \.self) { travauxIndex in
                        let travaux = nonClusteredTravaux[travauxIndex]
                        ForEach(travaux.coordinates.indices, id: \.self) { polygonIndex in
                            MapPolygon(coordinates: travaux.coordinates[polygonIndex])
                                .foregroundStyle(travaux.progressColor.opacity(0.3))
                                .stroke(travaux.progressColor, lineWidth: 2)
                        }
                    }
                }
                
                // Afficher les clusters de travaux
                ForEach(viewModel.displayClusters, id: \.id) { cluster in
                    Annotation("", coordinate: cluster.coordinate) {
                        TravauxClusterMarker(cluster: cluster)
                            .onTapGesture {
                                // Zoom sur le cluster au tap
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    mapCameraPosition = .region(
                                        MKCoordinateRegion(
                                            center: cluster.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                                        )
                                    )
                                }
                            }
                    }
                }
                
                // Afficher les travaux non clusterisés
                ForEach(viewModel.displayTravaux) { travaux in
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
                viewModel.updateZoomLevel(context.region.span)
                viewModel.updateVisibleRegion(context.region)
            }
            .overlay {
                if viewModel.shouldShowTooManyMarkersWarning {
                    tooManyMarkersWarning
                }
                
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
    
    
    private var tooManyMarkersWarning: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Trop de résultats")
                .font(.headline)
            
            Text("Zoomez sur la carte pour afficher les travaux")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        .padding(20)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        .padding(20)
    }
    
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .bottom) {
                Spacer()
                
                // Boutons à droite
                VStack(spacing: 12) {
                    // Bouton filtres (harmonisé avec Transport)
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.hasActiveFilters ? .orange : .gray)
                    .controlSize(.large)
                    
                    // Bouton localisation
                    Button {
                        if let userLocation = locationService.currentLocation {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                mapCameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: userLocation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
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
                .fill(travaux.progressColor)
                .frame(width: 32, height: 32)
                .shadow(color: travaux.progressColor.opacity(0.4), radius: 4, x: 0, y: 2)
            
            Image(systemName: travaux.type.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .overlay(
            importanceBadge
                .offset(x: 12, y: -12)
        )
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
                    // Graphe de progression circulaire
                    progressCircle
                    
                    // Type de travaux
                    typeCard
                    
                    // Adresse et localisation
                    locationCard
                    
                    // Responsable
                    responsableCard
                    
                    // Période et dates
                    periodCard
                    
                    // Description si disponible
                    if let description = travaux.description, !description.isEmpty {
                        descriptionCard
                    }
                    
                    // Bouton de navigation
                    navigationButton
                }
                .padding(20)
            }
            .background(.ultraThinMaterial)
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
    }
    
    // MARK: - Progress Circle
    
    private var progressCircle: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(travaux.progressColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: travaux.completionPercentage / 100)
                    .stroke(
                        travaux.progressColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: travaux.completionPercentage)
                
                // Percentage text
                VStack(spacing: 4) {
                    Text("\(Int(travaux.completionPercentage))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(travaux.progressColor)
                    
                    Text("Réalisé")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Status badge
            HStack(spacing: 8) {
                Image(systemName: travaux.avancement.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(travaux.avancement.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(travaux.progressColor)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Type Card
    
    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Type de travaux", systemImage: "hammer.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 12) {
                Image(systemName: travaux.type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(travaux.progressColor)
                    .frame(width: 44, height: 44)
                    .background(travaux.progressColor.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(travaux.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(travaux.natureChantier.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Location Card
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Localisation", systemImage: "mappin.circle.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(travaux.nomChantier)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(travaux.nom)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(travaux.commune)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Responsable Card
    
    private var responsableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Responsable", systemImage: "person.circle.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Circle())
                
                Text(travaux.intervenant)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Period Card
    
    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Période des travaux", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 16) {
                // Début
                VStack(alignment: .leading, spacing: 6) {
                    Text("Début")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
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
                    .font(.caption)
                
                // Fin
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fin prévue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
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
                Divider()
                
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                    Text("\(remaining) jours restants")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Description Card
    
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Description", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(travaux.description ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Badge type de chantier
            HStack(spacing: 8) {
                Image(systemName: travaux.natureChantier.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(travaux.natureChantier.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(travaux.natureChantier.color)
            .clipShape(Capsule())
            
            // Nom du chantier (simplifié)
            Text(travaux.nomChantier)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Adresse
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                    Text(travaux.nom)
                        .lineLimit(2)
                }
                .font(.subheadline)
                
                Text(travaux.commune)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Intervenant (si pertinent)
            if travaux.intervenant != "Non spécifié" && !travaux.intervenant.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.blue)
                    Text(travaux.intervenant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
            HStack(spacing: 12) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                Text("S'y rendre")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
                Section {
                    TextField("Rechercher...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                
                Section("Type de chantier") {
                    ForEach(TravauxNatureChantier.allCases, id: \.self) { nature in
                        Button {
                            viewModel.toggleNatureChantier(nature)
                        } label: {
                            HStack {
                                Image(systemName: nature.icon)
                                    .foregroundStyle(nature.color)
                                    .frame(width: 28)
                                
                                Text(nature.rawValue)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if viewModel.selectedNatureChantier.contains(nature) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Chantiers affichés")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(viewModel.filteredTravaux.count)")
                            .fontWeight(.semibold)
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
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TravauxMapView()
}
