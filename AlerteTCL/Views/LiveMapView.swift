import SwiftUI
import MapKit

struct LiveMapView: View {
    @StateObject private var viewModel = LiveVehiclesViewModel()
    @EnvironmentObject var alertViewModel: AlertViewModel
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedVehicle: Vehicle?
    @State private var selectedStop: TransitStop?
    @State private var selectedMergedStop: MergedStop?
    @State private var showFilters = false
    @State private var showAlerts = false
    @State private var showLoadingError = false
    @State private var showDataSourceErrors = false
    @State private var hasStartedLoading = false
    @State private var hasSetInitialLocation = false
    
    @State private var currentRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        ZStack {
            mapContent
            
            // Warning si trop de markers (centré, sans bloquer les touches)
            if viewModel.shouldShowTooManyMarkersWarning {
                VStack {
                    Spacer()
                    tooManyMarkersWarning
                        .allowsHitTesting(false)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            
            overlayControls
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailSheet(vehicle: vehicle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStop) { stop in
            TransitStopDetailSheet(stop: stop, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMergedStop) { mergedStop in
            MergedStopDetailSheet(mergedStop: mergedStop, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAlerts) {
            NavigationStack {
                NewAlertsView()
                    .environmentObject(alertViewModel)
                    .navigationTitle("Alertes trafic")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") {
                                showAlerts = false
                            }
                        }
                    }
            }
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showDataSourceErrors) {
            DataSourceErrorsSheet(
                viewModel: viewModel,
                alertViewModel: alertViewModel
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Localisation (non bloquant)
            locationService.requestPermission()
            locationService.startUpdatingLocation()
            
            if !hasSetInitialLocation, let userLocation = locationService.currentLocation, !isSimulator {
                withAnimation(.easeInOut(duration: 0.8)) {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: userLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
                hasSetInitialLocation = true
            }
            
            // Charger les données en arrière-plan APRÈS affichage de la Map
            guard !hasStartedLoading else { return }
            hasStartedLoading = true
            startBackgroundLoading()
        }
        .onDisappear {
            viewModel.stopLiveStream()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                viewModel.stopLiveStream()
            case .active:
                viewModel.startLiveStream()
            @unknown default:
                break
            }
        }
        .onChange(of: locationService.currentLocation) { oldValue, newValue in
            if !hasSetInitialLocation, oldValue == nil, let newLocation = newValue, !isSimulator {
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
    }
    
    // MARK: - Background Data Loading
    
    private func startBackgroundLoading() {
        // Charger les données de manière échelonnée pour éviter la contention réseau au cold start
        
        Task { @MainActor in
            // 1. Charger les véhicules en premier (priorité haute, inclut retry automatique)
            await loadSafely("Véhicules") { await self.viewModel.loadVehicles() }
            
            // 2. Charger les alertes juste après (priorité haute, inclut retry automatique)
            await loadSafely("Alertes") { await self.alertViewModel.loadAlerts() }
            
            // 3. Démarrer le live stream APRÈS les chargements critiques
            self.viewModel.startLiveStream()
            
            // 4. Charger les données secondaires avec décalage (réseau déjà "chaud")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Lancer en parallèle mais dans des Tasks séparées
            async let busTask: () = loadInBackground("Lignes bus") { 
                await self.viewModel.loadBusLines() 
            }
            async let transitTask: () = loadInBackground("Lignes transport") { 
                await self.viewModel.loadTransitLines() 
            }
            async let stopsTask: () = loadInBackground("Arrêts") { 
                await self.viewModel.loadTransitStops() 
            }
            
            // Attendre que tout soit terminé (mais chacun gère ses erreurs)
            _ = await (busTask, transitTask, stopsTask)
        }
    }
    
    /// Charge une donnée en background avec logging
    @MainActor
    private func loadInBackground(_ name: String, action: () async -> Void) async {
        let start = Date()
        print("📡 [\(name)] Début chargement...")
        await action()
        let duration = Date().timeIntervalSince(start)
        print("📡 [\(name)] Terminé en \(String(format: "%.1f", duration))s")
    }
    
    /// Charge des données de manière isolée - une erreur n'affecte JAMAIS les autres chargements
    @MainActor
    private func loadSafely(_ name: String, action: () async -> Void) async {
        do {
            try Task.checkCancellation()
            await action()
        } catch is CancellationError {
            print("⏹️ Chargement \(name) annulé")
        } catch {
            print("⚠️ Erreur \(name) (non-bloquante): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Map Content
    
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition, interactionModes: .all) {
                if locationService.currentLocation != nil {
                    UserAnnotation()
                }
                
                // Afficher les lignes de bus
                if viewModel.showBusLines {
                    ForEach(viewModel.busLines) { line in
                        MapPolyline(coordinates: line.clLocationCoordinates)
                            .stroke(line.lineColor, lineWidth: line.lineWidth)
                    }
                }
                
                // Afficher les lignes de métro/funiculaire/tramway
                if viewModel.showTransitLines {
                    ForEach(viewModel.transitLines) { line in
                        MapPolyline(coordinates: line.clLocationCoordinates)
                            .stroke(line.lineColor, lineWidth: line.lineWidth)
                    }
                }
                
                // Afficher les clusters
                ForEach(viewModel.displayClusters, id: \.id) { cluster in
                    Annotation("", coordinate: cluster.coordinate) {
                        TransportClusterMarker(cluster: cluster)
                    }
                }
                
                // Afficher les véhicules non clusterisés
                ForEach(viewModel.displayVehicles, id: \.id) { vehicle in
                    let animated = viewModel.animatedVehicles[vehicle.id]
                    let coordinate = animated?.coordinateAt(viewModel.animationTime) ?? vehicle.coordinate
                    let bearing = animated?.bearingAt(viewModel.animationTime) ?? vehicle.bearing
                    
                    Annotation(vehicle.lineName, coordinate: coordinate) {
                        VehicleMarker(vehicle: vehicle, bearing: bearing, currentZoomLevel: viewModel.currentZoomLevel)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(vehicle.accessibilityDescription)
                            .accessibilityHint("Double-cliquer pour voir les détails du véhicule")
                            .onTapGesture {
                                selectedVehicle = vehicle
                            }
                    }
                }
                
                // Afficher les arrêts fusionnés (au zoom fort uniquement)
                ForEach(viewModel.visibleMergedStops, id: \.id) { mergedStop in
                    Annotation(mergedStop.nom, coordinate: mergedStop.coordinate) {
                        MergedStopMarker(mergedStop: mergedStop, currentZoomLevel: viewModel.currentZoomLevel)
                            .onTapGesture {
                                selectedMergedStop = mergedStop
                            }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange { context in
                viewModel.updateZoomLevel(context.region.span)
                viewModel.updateVisibleRegion(context.region)
                currentRegion = context.region
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
            
            Text("Zoomez sur la carte pour afficher les véhicules")
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
    
    private var overlayControls: some View {
        VStack {
            // Bandeau trafic en haut
            trafficBanner
                .padding(.top, 8)
                .padding(.horizontal, 16)
            
            Spacer()
                .allowsHitTesting(false)
            
            HStack(alignment: .bottom) {
                // Live indicator en bas à gauche
                liveIndicator
                
                Spacer()
                    .allowsHitTesting(false)
                
                // Boutons en bas à droite (stack vertical)
                VStack(spacing: 12) {
                    // Bouton filtres
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(hasActiveFilters ? .blue : .gray)
                    .controlSize(.large)
                    
                    // Bouton localisation
                    Button {
                        if let userLocation = locationService.currentLocation, !isSimulator {
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
    
    // MARK: - Traffic Banner
    
    private var trafficBanner: some View {
        let hasSubscriptions = !alertViewModel.subscribedLines.isEmpty
        let subscribedDisrupted = subscribedLinesDisrupted
        let majorAlerts = alertViewModel.linesInError.filter { $0.highestSeverity == .major }
        
        let state: TrafficState = {
            if hasSubscriptions {
                if subscribedDisrupted.isEmpty {
                    return .subscribedAllClear
                } else {
                    let worst = subscribedDisrupted.map(\.highestSeverity).min { $0.sortOrder < $1.sortOrder } ?? .disruption
                    return .subscribedDisrupted(lines: subscribedDisrupted, severity: worst)
                }
            } else {
                if majorAlerts.isEmpty {
                    return .noMajorDisruption
                } else {
                    return .majorDisruptions(lines: majorAlerts)
                }
            }
        }()
        
        return Button { showAlerts = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Icône dans un cercle teinté
                    Image(systemName: state.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(state.color)
                        .frame(width: 32, height: 32)
                        .background(state.color.opacity(0.12))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        if let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                
                // Badges de lignes sur une deuxième ligne
                if let badges = state.lineBadges, !badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(badges, id: \.id) { summary in
                                lineBadge(name: summary.displayName, severity: summary.highestSeverity)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var subscribedLinesDisrupted: [AlertViewModel.LineAlertSummary] {
        alertViewModel.linesInError.filter { summary in
            alertViewModel.subscribedLines.contains { $0.ligneCom == summary.id || $0.ligneCli == summary.id }
        }
    }
    
    private func lineBadge(name: String, severity: AlertSeverity) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(severity == .major ? .red : .orange)
                .frame(width: 6, height: 6)
            
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LineColorHelper.textColor(for: name))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(LineColorHelper.backgroundColor(for: name))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(LineColorHelper.needsBorder(for: name) ? Color(.systemGray4) : .clear, lineWidth: 0.5)
        )
    }
    
    private var liveIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Warning indicator si erreurs de données
            if hasDataSourceErrors {
                Button {
                    showDataSourceErrors = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                        
                        Text("\(totalDataSourceErrors) source\(totalDataSourceErrors > 1 ? "s" : "") en erreur")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.2), radius: 4, x: 0, y: 2)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Live badge — tap to force refresh
            Button {
                Task { await viewModel.loadVehicles() }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.error != nil ? .orange : .green)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.isLive ? "LIVE" : "PAUSE")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(viewModel.isLive ? (viewModel.error != nil ? .orange : .green) : .secondary)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else if let update = viewModel.lastUpdate {
                        Text(update, style: .relative)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.leading, 24)
        .padding(.bottom, 24)
    }
    
    private var hasDataSourceErrors: Bool {
        viewModel.error != nil || alertViewModel.error != nil
    }
    
    private var totalDataSourceErrors: Int {
        var count = 0
        if viewModel.error != nil { count += 1 }
        if alertViewModel.error != nil { count += 1 }
        return count
    }
    
    private var hasActiveFilters: Bool {
        viewModel.selectedVehicleType != nil || viewModel.selectedLine != nil || !viewModel.selectedLines.isEmpty
    }
}

struct VehicleMarker: View {
    let vehicle: Vehicle
    var bearing: Double
    var currentZoomLevel: Double
    
    /// Seuil de zoom pour afficher la ponctualité (zoom fort = valeur basse)
    private let punctualityZoomThreshold: Double = 0.005
    
    private var shouldShowPunctuality: Bool {
        currentZoomLevel <= punctualityZoomThreshold
    }
    
    init(vehicle: Vehicle, bearing: Double? = nil, currentZoomLevel: Double = 0.01) {
        self.vehicle = vehicle
        self.bearing = bearing ?? vehicle.bearing
        self.currentZoomLevel = currentZoomLevel
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 32, height: 32)
                .shadow(color: markerColor.opacity(0.5), radius: 4, x: 0, y: 2)
            
            Group {
                if UIAccessibility.isVoiceOverRunning {
                    // Mode VoiceOver : afficher le texte du type de véhicule
                    Text(String(vehicle.vehicleType.rawValue.first ?? "?"))
                        .font(.system(size: 16, weight: .bold))
                } else {
                    // Mode normal : icône
                    Image(systemName: vehicle.vehicleType.icon)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(iconColor)
            
            if bearing != 0 {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(markerColor)
                    .offset(y: -18)
                    .rotationEffect(.degrees(bearing))
            }
            
            // Tooltip de ponctualité au zoom fort
            if shouldShowPunctuality {
                Text(vehicle.delayFormatted)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(punctualityColor)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                    .offset(y: -24)
            }
        }
    }
    
    private var punctualityColor: Color {
        if vehicle.isDelayed {
            return .red
        } else if vehicle.isEarly {
            return .orange
        } else {
            return .green
        }
    }
    
    private var markerColor: Color {
        // Utiliser les mêmes couleurs que LineColorHelper pour la cohérence
        return LineColorHelper.backgroundColor(for: vehicle.lineName)
    }
    
    private var iconColor: Color {
        // Utiliser les mêmes couleurs que LineColorHelper pour la cohérence
        return LineColorHelper.textColor(for: vehicle.lineName)
    }
}


struct VehicleTypeChip: View {
    let type: VehicleType
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? chipColor : Color(.systemGray4))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? chipColor.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? chipColor : .primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? chipColor.opacity(0.3) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var chipColor: Color {
        switch type {
        case .metro: return .orange
        case .tram: return .blue
        case .bus: return .purple
        case .trolley: return .green
        case .funicular: return .teal
        }
    }
}

struct VehicleDetailSheet: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(vehicleColor)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: vehicle.vehicleType.icon)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ligne \(vehicle.lineName)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(vehicle.vehicleType.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        // Masquer la destination si elle ressemble à un ID technique
                        if !vehicle.destination.isEmpty && !vehicle.destination.contains(":") && vehicle.destination.count < 50 {
                            DetailRow(icon: "arrow.right.circle.fill", title: "Destination", value: vehicle.destination)
                        }
                        
                        DetailRow(
                            icon: vehicle.isDelayed ? "clock.badge.exclamationmark.fill" : "clock.fill",
                            title: "Ponctualité",
                            value: vehicle.delayFormatted,
                            valueColor: vehicle.isDelayed ? .orange : (vehicle.isEarly ? .blue : .green)
                        )
                        
                        if let recordedAt = vehicle.recordedAt {
                            DetailRow(
                                icon: "antenna.radiowaves.left.and.right",
                                title: "Dernière mise à jour",
                                value: recordedAt.formatted(date: .omitted, time: .shortened)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Spacer()
            }
            .navigationTitle("Détails du véhicule")
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
    
    private var vehicleColor: Color {
        switch vehicle.vehicleType {
        case .metro: return .orange
        case .tram: return .blue
        case .bus: return .purple
        case .trolley: return .green
        case .funicular: return .teal
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 4)
    }
}

struct FilterSheet: View {
    @ObservedObject var viewModel: LiveVehiclesViewModel
    @ObservedObject private var favoritesService = FavoriteLinesService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showAllLines = false
    
    var body: some View {
        NavigationStack {
            List {
                if hasActiveFilters {
                    Section {
                        Button {
                            viewModel.clearFilters()
                            searchText = ""
                            showAllLines = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.red)
                                Text("Réinitialiser les filtres")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                
                Section("Type de véhicule") {
                    Button {
                        withAnimation {
                            viewModel.selectedVehicleType = nil
                            viewModel.selectedLine = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(.gray)
                                .frame(width: 24)
                            
                            Text("Tous les types")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if viewModel.selectedVehicleType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        let count = viewModel.vehicles.filter { $0.vehicleType == type }.count
                        Button {
                            withAnimation {
                                if viewModel.selectedVehicleType == type {
                                    viewModel.selectedVehicleType = nil
                                } else {
                                    viewModel.selectedVehicleType = type
                                    viewModel.selectedLine = nil
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(typeColor(type))
                                    .frame(width: 24)
                                
                                Text(type.rawValue)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                                
                                if viewModel.selectedVehicleType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                if !viewModel.availableLines.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Rechercher une ligne...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    let sortedLines = viewModel.getSortedLinesWithFavorites(searchText: searchText)
                    
                    if !sortedLines.favorites.isEmpty {
                        Section {
                            ForEach(sortedLines.favorites, id: \.self) { line in
                                lineRow(line: line)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text("Favoris")
                            }
                        }
                    }
                    
                    if !sortedLines.others.isEmpty {
                        Section {
                            if !showAllLines && sortedLines.others.count > 10 {
                                ForEach(sortedLines.others.prefix(10), id: \.self) { line in
                                    lineRow(line: line)
                                }
                                
                                Button {
                                    withAnimation {
                                        showAllLines = true
                                    }
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("Afficher toutes les lignes (\(sortedLines.others.count))")
                                            .foregroundStyle(.blue)
                                        Spacer()
                                    }
                                }
                            } else {
                                ForEach(sortedLines.others, id: \.self) { line in
                                    lineRow(line: line)
                                }
                            }
                        } header: {
                            if let type = viewModel.selectedVehicleType {
                                Text("Lignes \(type.rawValue)")
                            } else {
                                Text("Toutes les lignes")
                            }
                        }
                    }
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
    
    private var hasActiveFilters: Bool {
        viewModel.selectedVehicleType != nil || viewModel.selectedLine != nil || !viewModel.selectedLines.isEmpty
    }
    
    @ViewBuilder
    private func lineRow(line: String) -> some View {
        let lineType = viewModel.vehicleTypeForLine(line)
        let isSelected = viewModel.selectedLines.contains(line)
        
        Button {
            viewModel.toggleLineSelection(line)
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .frame(width: 24)
                
                if let type = lineType {
                    Image(systemName: type.icon)
                        .foregroundStyle(typeColor(type))
                        .frame(width: 24)
                }
                
                Text(line)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    favoritesService.toggleFavorite(line)
                } label: {
                    let isFavorite = favoritesService.isFavorite(line)
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func typeColor(_ type: VehicleType) -> Color {
        switch type {
        case .metro: return .orange
        case .tram: return .blue
        case .bus: return .purple
        case .trolley: return .green
        case .funicular: return .teal
        }
    }
}

// MARK: - Traffic State

private enum TrafficState {
    case noMajorDisruption
    case subscribedAllClear
    case subscribedDisrupted(lines: [AlertViewModel.LineAlertSummary], severity: AlertSeverity)
    case majorDisruptions(lines: [AlertViewModel.LineAlertSummary])
    
    var icon: String {
        switch self {
        case .noMajorDisruption, .subscribedAllClear:
            return "checkmark.circle.fill"
        case .subscribedDisrupted(_, let severity):
            return severity == .major ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
        case .majorDisruptions:
            return "xmark.octagon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .noMajorDisruption, .subscribedAllClear:
            return .green
        case .subscribedDisrupted(_, let severity):
            return severity == .major ? .red : .orange
        case .majorDisruptions:
            return .red
        }
    }
    
    var title: String {
        switch self {
        case .noMajorDisruption:
            return "Aucune perturbation majeure"
        case .subscribedAllClear:
            return "Vos lignes circulent normalement"
        case .subscribedDisrupted(let lines, _):
            let count = lines.count
            return "\(count) de vos ligne\(count > 1 ? "s" : "") perturbée\(count > 1 ? "s" : "")"
        case .majorDisruptions(let lines):
            let count = lines.count
            return "\(count) perturbation\(count > 1 ? "s" : "") majeure\(count > 1 ? "s" : "")"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .noMajorDisruption:
            return "Réseau TCL"
        case .subscribedAllClear:
            return nil
        case .subscribedDisrupted, .majorDisruptions:
            return nil
        }
    }
    
    var lineBadges: [AlertViewModel.LineAlertSummary]? {
        switch self {
        case .noMajorDisruption, .subscribedAllClear:
            return nil
        case .subscribedDisrupted(let lines, _):
            return lines
        case .majorDisruptions(let lines):
            return lines
        }
    }
}

#Preview {
    LiveMapView()
}
