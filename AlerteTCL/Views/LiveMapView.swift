import SwiftUI
import MapKit

struct LiveMapView: View {
    @StateObject private var viewModel = LiveVehiclesViewModel()
    @EnvironmentObject var alertViewModel: AlertViewModel
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedVehicle: Vehicle?
    @State private var selectedMergedStop: MergedStop?
    @State private var showFilters = false
    @State private var showAlerts = false
    @State private var showDataSourceErrors = false
    @State private var hasStartedLoading = false
    @State private var hasSetInitialLocation = false
    @State private var showRefreshInfo = false
    
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @State private var isSatellite = false
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        ZStack {
            LiveMapRepresentable(
                viewModel: viewModel,
                locationService: locationService,
                region: $mapRegion,
                selectedVehicle: $selectedVehicle,
                selectedMergedStop: $selectedMergedStop,
                isSatellite: $isSatellite
            )
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            overlayControls
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailSheet(vehicle: vehicle)
                .presentationDetents([.medium])
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
                    mapRegion = MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
                hasSetInitialLocation = true
            }
            
            // Charger les données en arrière-plan APRÈS affichage de la Map
            guard !hasStartedLoading else {
                if !viewModel.isLive {
                    viewModel.startLiveStream()
                }
                return
            }
            hasStartedLoading = true
            startBackgroundLoading()
        }
        // Le stream est arrêté uniquement sur scenePhase.background (ci-dessous).
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.stopLiveStream()
            case .inactive:
                break
            case .active:
                if !viewModel.isLive {
                    viewModel.startLiveStream()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: locationService.currentLocation) { oldValue, newValue in
            if !hasSetInitialLocation, oldValue == nil, let newLocation = newValue, !isSimulator {
                withAnimation(.easeInOut(duration: 0.8)) {
                    mapRegion = MKCoordinateRegion(
                        center: newLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
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
        AppLogger.debug("📡 [\(name)] Début chargement...")
        await action()
        let duration = Date().timeIntervalSince(start)
        AppLogger.debug("📡 [\(name)] Terminé en \(String(format: "%.1f", duration))s")
    }
    
    /// Charge des données de manière isolée - une erreur n'affecte JAMAIS les autres chargements
    @MainActor
    private func loadSafely(_ name: String, action: () async -> Void) async {
        do {
            try Task.checkCancellation()
            await action()
        } catch is CancellationError {
            AppLogger.debug("⏹️ Chargement \(name) annulé")
        } catch {
            AppLogger.debug("⚠️ Erreur \(name) (non-bloquante): \(error.localizedDescription)")
        }
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
                VStack(spacing: 10) {
                    // Bouton satellite
                    Button {
                        withAnimation { isSatellite.toggle() }
                    } label: {
                        Image(systemName: isSatellite ? "globe.europe.africa.fill" : "globe.europe.africa")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSatellite ? .orange : .primary)
                            .frame(width: 50, height: 50)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)

                    // Bouton filtres
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(hasActiveFilters ? .blue : .primary)
                            .frame(width: 50, height: 50)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    // Bouton localisation
                    Button {
                        if let userLocation = locationService.currentLocation, !isSimulator {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                mapRegion = MKCoordinateRegion(
                                    center: userLocation.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                            }
                        } else {
                            locationService.requestPermission()
                            locationService.startUpdatingLocation()
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.blue)
                            .frame(width: 50, height: 50)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Traffic Banner

    private var trafficBanner: some View {
        let networkMajorCount = alertViewModel.alerts.filter { $0.isOngoing && $0.severity == .major }.count
        return TrafficBannerView(
            subscribedLines: alertViewModel.subscribedLines,
            linesInError: alertViewModel.linesInError,
            networkAlertCount: networkMajorCount,
            networkHasMajor: networkMajorCount > 0,
            lastUpdate: alertViewModel.lastUpdate,
            onTap: { showAlerts = true }
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
            
            // Live badge — tap pour info
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showRefreshInfo.toggle()
                }
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
                    } else if let lastUpdate = viewModel.lastUpdate {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let secs = max(0, 30 - Int(Date().timeIntervalSince(lastUpdate)))
                            Text("\(secs)s")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText(countsDown: true))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showRefreshInfo, arrowEdge: .bottom) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Temps réel")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Positions TCL en direct")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // Stats
                    HStack(spacing: 0) {
                        VStack(spacing: 3) {
                            Text("30s")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("intervalle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Divider().frame(height: 36)

                        VStack(spacing: 3) {
                            if let lastUpdate = viewModel.lastUpdate {
                                Text(lastUpdate, style: .relative)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .minimumScaleFactor(0.7)
                            } else {
                                Text("—")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Text("dernière maj")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider()
                        .padding(.horizontal, 16)

                    // No-refresh notice
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 15))
                        Text("Inutile de rafraîchir manuellement")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(width: 260)
                .presentationCompactAdaptation(.popover)
            }
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

// Legacy SwiftUI `VehicleMarker` supprimé — rendu désormais via
// `MarkerImageCache` + `MKAnnotationView` (cf. LiveMapRepresentable).



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

// MARK: - Traffic Banner View

private struct TrafficBannerView: View {
    let subscribedLines: [TransportLine]
    let linesInError: [AlertViewModel.LineAlertSummary]
    let networkAlertCount: Int
    let networkHasMajor: Bool
    let lastUpdate: Date?
    let onTap: () -> Void

    // MARK: Derived

    private var hasSubscriptions: Bool { !subscribedLines.isEmpty }

    private var subscribedDisrupted: [AlertViewModel.LineAlertSummary] {
        linesInError.filter { summary in
            subscribedLines.contains { $0.ligneCom == summary.id || $0.ligneCli == summary.id }
        }
    }

    private var networkIsNormal: Bool { networkAlertCount == 0 }

    // MARK: State machine

    private enum BannerState {
        case noSubsNetworkNormal
        case noSubsNetworkDisrupted
        case myLinesOKNetworkOK
        case myLinesOKNetworkDisrupted
        case myLinesDisrupted(severity: AlertSeverity)
    }

    private var state: BannerState {
        guard hasSubscriptions else {
            return networkIsNormal ? .noSubsNetworkNormal : .noSubsNetworkDisrupted
        }
        if subscribedDisrupted.isEmpty {
            return networkIsNormal ? .myLinesOKNetworkOK : .myLinesOKNetworkDisrupted
        }
        let worst = subscribedDisrupted
            .map(\.highestSeverity)
            .min { $0.sortOrder < $1.sortOrder } ?? .disruption
        return .myLinesDisrupted(severity: worst)
    }

    private var accentColor: Color {
        switch state {
        case .noSubsNetworkNormal, .myLinesOKNetworkOK:   return .green
        case .noSubsNetworkDisrupted:                     return networkHasMajor ? .red : .orange
        case .myLinesOKNetworkDisrupted:                  return .green
        case .myLinesDisrupted(let s):                    return s == .major ? .red : .orange
        }
    }

    private var icon: String {
        switch state {
        case .noSubsNetworkNormal, .myLinesOKNetworkOK:
            return "checkmark.circle.fill"
        case .noSubsNetworkDisrupted:
            return networkHasMajor ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
        case .myLinesOKNetworkDisrupted:
            return "checkmark.circle.fill"
        case .myLinesDisrupted(let s):
            return s == .major ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        switch state {
        case .noSubsNetworkNormal:
            return "Réseau TCL normal"
        case .noSubsNetworkDisrupted:
            return "\(networkAlertCount) perturbation\(networkAlertCount > 1 ? "s" : "") réseau"
        case .myLinesOKNetworkOK:
            return "Vos lignes circulent normalement"
        case .myLinesOKNetworkDisrupted:
            return "Vos lignes sont normales"
        case .myLinesDisrupted(let s):
            let n = subscribedDisrupted.count
            return s == .major
                ? "\(n) ligne\(n > 1 ? "s" : "") en alerte majeure"
                : "\(n) de vos ligne\(n > 1 ? "s" : "") perturbée\(n > 1 ? "s" : "")"
        }
    }

    private var subtitle: String? {
        switch state {
        case .noSubsNetworkNormal:
            return "Appuyez pour suivre vos lignes"
        case .noSubsNetworkDisrupted:
            return "Appuyez pour voir les détails"
        case .myLinesOKNetworkOK:
            return nil
        case .myLinesOKNetworkDisrupted:
            return "\(networkAlertCount) perturbation\(networkAlertCount > 1 ? "s" : "") sur d'autres lignes"
        case .myLinesDisrupted:
            return nil
        }
    }

    private var isPulsing: Bool {
        if case .myLinesDisrupted(let s) = state { return s == .major }
        return false
    }

    // MARK: Body

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // — Ligne principale
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.pulse, isActive: isPulsing)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let sub = subtitle {
                            Text(sub)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    // Timestamp
                    if let last = lastUpdate {
                        Text(last, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                // — Badges de lignes abonnées (toujours si on a des abonnements)
                if hasSubscriptions {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.35))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(subscribedLines) { line in
                                let disruption = subscribedDisrupted.first {
                                    $0.id == line.ligneCom || $0.id == line.ligneCli
                                }
                                SubscribedLinePill(line: line, disruption: disruption)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                    }
                    .allowsHitTesting(false)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.09), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: accentColor.opacity(0.18), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasSubscriptions)
    }
}

// MARK: - Subscribed Line Pill

private struct SubscribedLinePill: View {
    let line: TransportLine
    let disruption: AlertViewModel.LineAlertSummary?

    @State private var isPulsing = false

    private var dotColor: Color? {
        guard let d = disruption else { return nil }
        return d.highestSeverity == .major ? .red : .orange
    }

    private var lineName: String {
        line.ligneCli.isEmpty ? line.ligneCom : line.ligneCli
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(lineName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(LineColorHelper.textColor(for: lineName))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(LineColorHelper.backgroundColor(for: lineName))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        LineColorHelper.needsBorder(for: lineName) ? Color(.systemGray4) : .clear,
                        lineWidth: 0.5
                    )
                )

            if let color = dotColor {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    .scaleEffect(isPulsing && color == .red ? 1.3 : 1.0)
                    .animation(
                        color == .red
                            ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )
                    .offset(x: 3, y: -3)
            }
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Traffic State (kept for reference, no longer used)

// La carte live est désormais rendue par `LiveMapRepresentable`
// (UIKit MKMapView + MKAnnotationView / UIImage).
// Les anciens types `LiveMapContent`, `AnimatedVehiclesLayer`, `VehicleMarker`
// ont été supprimés : voir `LiveMapRepresentable.swift` + `MapAnnotations.swift`
// + `MarkerImageCache.swift`.

#Preview {
    LiveMapView()
}