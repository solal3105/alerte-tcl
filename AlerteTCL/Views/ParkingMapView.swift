import SwiftUI
import MapKit
import CoreLocation

struct ParkingMapView: View {
    @StateObject private var viewModel = ParkingViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedParking: Parking?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var currentSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    @State private var hasSetInitialLocation = false
    @Binding var selectedParkingId: String?
    
    var body: some View {
        ZStack {
            mapContent
            
            VStack {
                parkingTypeSelector
                Spacer()
            }
            
            overlayControls
        }
        .sheet(item: $selectedParking) { parking in
            ParkingDetailSheet(parking: parking, viewModel: viewModel)
                .presentationDetents([.medium, .large])
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
            
            // Charger les parkings en arrière-plan
            Task { @MainActor in
                await self.viewModel.loadParkings()
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
        .onChange(of: selectedParkingId) { _, newParkingId in
            if let parkingId = newParkingId {
                openParkingById(parkingId)
                selectedParkingId = nil
            }
        }
    }
    
    private var parkingTypeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ParkingType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedParkingType = type
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(type == .motorized2Wheel ? "2-Roues" : type.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.selectedParkingType == type ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background {
                        if viewModel.selectedParkingType == type {
                            Capsule()
                                .fill(parkingTypeColor(type))
                                .shadow(color: parkingTypeColor(type).opacity(0.4), radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
    
    private func parkingTypeColor(_ type: ParkingType) -> Color {
        switch type {
        case .car: return .blue
        case .bike: return .green
        case .motorized2Wheel: return .orange
        }
    }
    
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition) {
                // Afficher les clusters de parkings
                ForEach(viewModel.displayClusters, id: \.id) { cluster in
                    Annotation("", coordinate: cluster.coordinate) {
                        ParkingClusterMarker(cluster: cluster)
                            .onTapGesture {
                                // Zoom sur le cluster au tap
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    mapCameraPosition = .region(
                                        MKCoordinateRegion(
                                            center: cluster.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                        )
                                    )
                                }
                            }
                    }
                }
                
                // Afficher les parkings non clusterisés
                ForEach(viewModel.displayParkings) { parking in
                    Annotation(parking.nom, coordinate: parking.coordinate) {
                        ParkingMarker(parking: parking, currentZoomLevel: viewModel.currentZoomLevel)
                            .onTapGesture {
                                selectedParking = parking
                            }
                    }
                    .annotationTitles(.hidden)
                    .tag(parking.id)
                }
                
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange { context in
                currentSpan = context.region.span
                viewModel.updateZoomLevel(context.region.span)
                viewModel.updateVisibleRegion(context.region)
            }
            .overlay {
                // Warning pour trop de markers
                if viewModel.shouldShowTooManyMarkersWarning {
                    tooManyMarkersWarning
                }
                
                // Overlay pour les erreurs uniquement
                if let error = viewModel.error {
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
                            Task { await viewModel.loadParkings() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .padding(20)
                }
            }
        }
    }
    
    private var tooManyMarkersWarning: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Trop de résultats")
                .font(.headline)
            
            Text("Zoomez sur la carte pour afficher les parkings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Bouton pour zoomer automatiquement
            Button {
                zoomToCurrentLocation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Zoomer ici")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
        .padding(20)
    }
    
    private func zoomToCurrentLocation() {
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
            // Si pas de localisation, zoomer sur Lyon centre
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                mapCameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
    
    private func openParkingById(_ parkingId: String) {
        // Attendre que les parkings soient chargés si nécessaire
        Task {
            // Si les parkings ne sont pas encore chargés, attendre un peu
            if viewModel.parkings.isEmpty {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondes
            }
            
            // Chercher le parking dans tous les parkings chargés
            if let parking = viewModel.parkings.first(where: { $0.id == parkingId }) {
                // Changer le type de parking si nécessaire
                if parking.parkingType != viewModel.selectedParkingType {
                    viewModel.selectedParkingType = parking.parkingType
                }
                
                // Zoomer sur le parking
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: parking.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )
                    )
                }
                
                // Ouvrir la fiche du parking après un court délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedParking = parking
                }
            }
        }
    }
    
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            // Indicateur de chargement progressif (non-bloquant) en bas
            if viewModel.isLoadingInBackground && !viewModel.loadingMessage.isEmpty {
                progressiveLoadingCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(alignment: .bottom) {
                // Card refresh en bas à gauche (uniquement pour voitures - données temps réel)
                if viewModel.selectedParkingType == .car {
                    refreshCard
                }
                
                Spacer()
                
                // Bouton localisation en bas à droite
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
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isLoadingInBackground)
    }
    
    /// Card de chargement progressif non-bloquant
    private var progressiveLoadingCard: some View {
        HStack(spacing: 12) {
            // Icône animée
            ZStack {
                Circle()
                    .stroke(parkingTypeColor(viewModel.selectedParkingType).opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: viewModel.loadingProgress)
                    .stroke(
                        parkingTypeColor(viewModel.selectedParkingType),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: viewModel.loadingProgress)
                
                Image(systemName: viewModel.selectedParkingType.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(parkingTypeColor(viewModel.selectedParkingType))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.loadingMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                
                if viewModel.loadedCount > 0 && viewModel.totalToLoad > 0 {
                    Text("\(viewModel.parkings.count) affichés sur la carte")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.parkingsAvecPlaces)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text("parkings disponibles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.totalPlacesDisponibles)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                Text("places libres")
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
            Task { await viewModel.loadParkings() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.refreshProgress)
                        .stroke(
                            Color.blue,
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
                            .foregroundStyle(.blue)
                    }
                }
                
                if !viewModel.isLoading {
                    Text("dans \(viewModel.secondsUntilNextRefresh)s")
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
}

// MARK: - Parking Marker
struct ParkingMarker: View {
    let parking: Parking
    var currentZoomLevel: Double = 0.01
    
    /// Seuil de zoom pour afficher le tooltip (zoom fort = valeur basse)
    private let tooltipZoomThreshold: Double = 0.005
    
    /// Markers compacts pour vélos et 2-roues
    private var isCompactMarker: Bool {
        parking.parkingType == .bike || parking.parkingType == .motorized2Wheel
    }
    
    /// Afficher le tooltip uniquement au zoom fort
    private var shouldShowTooltip: Bool {
        isCompactMarker && currentZoomLevel <= tooltipZoomThreshold
    }
    
    var body: some View {
        if isCompactMarker {
            compactMarkerView
        } else {
            fullMarkerView
        }
    }
    
    // MARK: - Compact Marker (Vélos & 2-Roues)
    
    private var compactMarkerView: some View {
        ZStack {
            // Simple dot marker
            Circle()
                .fill(markerColor)
                .frame(width: 16, height: 16)
                .shadow(color: markerColor.opacity(0.5), radius: 3, x: 0, y: 1)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
            
            // Tooltip avec nombre de places (uniquement au zoom fort)
            if shouldShowTooltip {
                VStack(spacing: 0) {
                    Text("\(parking.capaciteTotale) places")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(markerColor)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                }
                .offset(y: -20)
            }
        }
    }
    
    // MARK: - Full Marker (Voitures)
    
    private var fullMarkerView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(markerColor)
                .frame(width: 44, height: 44)
                .shadow(color: markerColor.opacity(0.4), radius: 6, x: 0, y: 3)
            
            // Inner content
            VStack(spacing: 0) {
                Image(systemName: parking.parkingType.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(parking.placesDisponibles)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            // État indicator (only for car parkings with real-time data)
            Circle()
                .fill(parking.etat == .ouvert ? .green : .red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
                .offset(x: 16, y: -16)
        )
    }
    
    private var markerColor: Color {
        switch parking.parkingType {
        case .car:
            if parking.etat != .ouvert {
                return .gray
            }
            switch parking.tauxOccupation {
            case 0..<0.5:
                return .green
            case 0.5..<0.8:
                return .orange
            default:
                return .red
            }
        case .bike:
            return .green
        case .motorized2Wheel:
            return .orange
        }
    }
}

// MARK: - Parking Detail Sheet
struct ParkingDetailSheet: View {
    let parking: Parking
    @ObservedObject var viewModel: ParkingViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(parking: Parking, viewModel: ParkingViewModel) {
        self.parking = parking
        self.viewModel = viewModel
        // Sauvegarder le parking dans les récents pour la configuration du widget
        RecentItemsService.shared.saveRecentParking(id: parking.id, name: parking.nom)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header avec places disponibles
                    availabilityHeader
                    
                    // Bouton itinéraire en premier
                    navigationButton
                    
                    // Infos principales
                    mainInfoCard
                    
                    // Tarifs
                    if hasTarifs {
                        tarifCard
                    }
                    
                    // Services
                    if hasServices {
                        servicesCard
                    }
                    
                    // Informations supplémentaires
                    additionalInfoCard
                    
                    // Bouton site web
                    if let urlString = parking.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Site web du parking", systemImage: "safari")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(parking.nom)
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
    
    private var availabilityHeader: some View {
        VStack(spacing: 12) {
            // Cercle avec places disponibles
            ZStack {
                Circle()
                    .stroke(availabilityColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 1 - parking.tauxOccupation)
                    .stroke(
                        availabilityColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(parking.placesDisponibles)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(availabilityColor)
                    
                    Text("/ \(parking.capaciteTotale)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // État
            HStack(spacing: 6) {
                Image(systemName: parking.etat.icon)
                    .foregroundStyle(parking.etat == .ouvert ? .green : .red)
                
                Text(parking.etat.displayName)
                    .font(.headline)
                    .foregroundStyle(parking.etat == .ouvert ? .green : .red)
            }
            
            // Dernière mise à jour
            if let lastUpdate = parking.lastUpdate {
                Text("Mis à jour \(lastUpdate.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var mainInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Informations", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            VStack(spacing: 12) {
                InfoRow(icon: "building.2", title: "Gestionnaire", value: parking.gestionnaire)
                
                if let hauteur = parking.hauteurMax {
                    InfoRow(icon: "arrow.up.and.down", title: "Hauteur max", value: "\(hauteur) cm")
                }
                
                InfoRow(icon: "car", title: "Capacité totale", value: "\(parking.capaciteTotale) places")
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var hasTarifs: Bool {
        parking.tarif1h != nil || parking.tarif24h != nil || parking.gratuit
    }
    
    private var tarifCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Tarifs", systemImage: "eurosign.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            
            if parking.gratuit {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Parking gratuit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    if let tarif = parking.tarif1h {
                        TarifCell(duration: "1h", price: tarif)
                    }
                    if let tarif = parking.tarif2h {
                        TarifCell(duration: "2h", price: tarif)
                    }
                    if let tarif = parking.tarif3h {
                        TarifCell(duration: "3h", price: tarif)
                    }
                    if let tarif = parking.tarif4h {
                        TarifCell(duration: "4h", price: tarif)
                    }
                    if let tarif = parking.tarif24h {
                        TarifCell(duration: "24h", price: tarif)
                    }
                }
                
                if parking.aboResident != nil || parking.aboNonResident != nil {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Abonnements")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if let abo = parking.aboResident {
                            HStack {
                                Text("Résident")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(abo, specifier: "%.0f")€/mois")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        
                        if let abo = parking.aboNonResident {
                            HStack {
                                Text("Non-résident")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(abo, specifier: "%.0f")€/mois")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var hasServices: Bool {
        (parking.nbPmr ?? 0) > 0 ||
        (parking.nbVoituresElectriques ?? 0) > 0 ||
        (parking.nbVelo ?? 0) > 0 ||
        (parking.nb2Rm ?? 0) > 0
    }
    
    private var servicesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Services", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.purple)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let pmr = parking.nbPmr, pmr > 0 {
                    ServiceCell(icon: "figure.roll", title: "PMR", count: pmr, color: .blue)
                }
                if let elec = parking.nbVoituresElectriques, elec > 0 {
                    ServiceCell(icon: "bolt.car", title: "Électrique", count: elec, color: .green)
                }
                if let velo = parking.nbVelo, velo > 0 {
                    ServiceCell(icon: "bicycle", title: "Vélos", count: velo, color: .orange)
                }
                if let moto = parking.nb2Rm, moto > 0 {
                    ServiceCell(icon: "motorcycle", title: "2 roues", count: moto, color: .red)
                }
                if let auto = parking.nbAutopartage, auto > 0 {
                    ServiceCell(icon: "car.2", title: "Autopartage", count: auto, color: .purple)
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
                Text("Itinéraire")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .controlSize(.large)
        .padding(.horizontal, 20)
    }
    
    private var additionalInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Informations complémentaires", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            VStack(spacing: 12) {
                // Type d'usagers
                InfoRow(icon: "person.3", title: "Type d'usagers", value: "Tous publics")
                
                // Type d'ouvrage
                InfoRow(icon: "building", title: "Type", value: "Ouvrage")
                
                // Gratuit ou payant
                HStack(spacing: 12) {
                    Image(systemName: parking.gratuit ? "checkmark.circle.fill" : "eurosign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(parking.gratuit ? .green : .orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Statut")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(parking.gratuit ? "Gratuit" : "Payant")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(parking.gratuit ? .green : .orange)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var availabilityColor: Color {
        if parking.etat != .ouvert {
            return .gray
        }
        
        switch parking.tauxOccupation {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private func openInMaps() {
        // Ouvrir directement dans Apple Plans
        let placemark = MKPlacemark(coordinate: parking.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = parking.nom
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Helper Views
private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
    }
}

private struct TarifCell: View {
    let duration: String
    let price: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(duration)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(price, specifier: "%.2f")€")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ServiceCell: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview
#Preview {
    ParkingMapView(selectedParkingId: .constant(nil))
}
