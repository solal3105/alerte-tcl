import SwiftUI
import MapKit
import Shared

struct LiveMapView: View {
    @StateObject private var viewModel = LiveVehiclesViewModel()
    @StateObject private var stopsViewModel = TransitStopViewModel()
    @EnvironmentObject var alertViewModel: AlertViewModel
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedVehicle: Vehicle?
    @State private var selectedMergedStop: MergedStop?
    @State private var showFilters = false
    @State private var showTimetableSearch = false
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
    
    /// En mode démo la fiche arrêt s'ouvre en pleine hauteur pour montrer les passages.
    private var stopSheetDetents: Set<PresentationDetent> {
        #if DEBUG
        if DemoShowcase.isActive { return [.large] }
        #endif
        return [.medium, .large]
    }

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
                stopsViewModel: stopsViewModel,
                locationService: locationService,
                region: $mapRegion,
                onVehicleTap: { vehicle in withAnimation { focusOnVehicle(vehicle) } },
                selectedMergedStop: $selectedMergedStop,
                isSatellite: $isSatellite
            )
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            overlayControls
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailSheet(vehicle: vehicle, liveViewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMergedStop) { mergedStop in
            MergedStopDetailSheet(
                mergedStop: mergedStop, stopsVM: stopsViewModel, liveVM: viewModel, onFocus: focusOnStop,
                onLocateVehicle: { vehicle in focusOnApproach(vehicle: vehicle, stop: mergedStop) }
            )
            .presentationDetents(stopSheetDetents)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimetableSearch) {
            TimetableSearchSheet()
                .presentationDetents([.large])
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
            #if DEBUG
            // Mode démo : cadrer la scène simulée et ouvrir la fiche du cas demandé.
            if DemoShowcase.isActive {
                // En portrait MapKit élargit le latitudeDelta pour respecter le ratio :
                // viser 0.0035 de large pour rester sous le seuil des étiquettes (0.005).
                mapRegion = MKCoordinateRegion(
                    center: DemoShowcase.center,
                    span: MKCoordinateSpan(latitudeDelta: 0.0035, longitudeDelta: 0.0016)
                )
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    switch DemoShowcase.current {
                    case "fiche", "fiche-vieille":
                        if let vehicle = DemoShowcase.vehicleForSheet() {
                            focusOnVehicle(vehicle)
                            selectedVehicle = vehicle
                        }
                    case "arret", "horaires-arret", "horaires-course": selectedMergedStop = DemoShowcase.mergedStop()
                    case "bus-arret":              focusOnStop(DemoShowcase.stopLineFocus())
                    case "alertes", "alertes-ligne", "alertes-options": showAlerts = true
                    case "horaires", "horaires-ligne", "horaires-arrets": showTimetableSearch = true
                    case "erreur401":              showDataSourceErrors = true
                    case "filtres":                showFilters = true
                    default: break
                    }
                }
            }
            // Mode démo : pas de demande de position, la scène est fixée place Bellecour.
            if DemoShowcase.isActive { startBackgroundLoadingIfNeeded(); return }
            #endif
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
            
            startBackgroundLoadingIfNeeded()
        }
        #if DEBUG
        .onReceive(stopsViewModel.$mergedStops) { stops in
            guard let id = DemoShowcase.stopToOpen, selectedMergedStop == nil,
                  let stop = stops.first(where: { $0.stops.contains { $0.id == id } }) else { return }
            mapRegion = MKCoordinateRegion(center: stop.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006))
            selectedMergedStop = stop
        }
        #endif
        // Le stream est arrêté uniquement sur scenePhase.background (ci-dessous).
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.stopLiveStream()
            case .inactive:
                break
            case .active:
                viewModel.resumeFromForeground()
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
    
    // MARK: - Filtre « bus de cet arrêt »

    /// Applique le filtre choisi dans la fiche d'un arrêt, referme la fiche et cadre la carte
    /// sur l'arrêt et les véhicules concernés.
    /// Toucher un véhicule : la carte ne montre plus que sa ligne, et le bandeau décrit le véhicule.
    private func focusOnVehicle(_ vehicle: Vehicle) {
        viewModel.focusOnStop(StopLineFocus(
            line: vehicle.lineName, direction: nil, destination: vehicle.destination, stopName: "",
            latitude: vehicle.coordinate.latitude, longitude: vehicle.coordinate.longitude, vehicleId: vehicle.id
        ))
    }

    private func focusOnStop(_ focus: StopLineFocus) {
        selectedMergedStop = nil
        viewModel.focusOnStop(focus)
        if let region = viewModel.stopFocusRegion() {
            withAnimation(.easeInOut(duration: 0.8)) { mapRegion = region }
        }
    }

    /// « Où est mon bus » : referme la fiche de l'arrêt, isole le véhicule et cadre la carte sur lui et l'arrêt.
    private func focusOnApproach(vehicle: Vehicle, stop: MergedStop) {
        selectedMergedStop = nil
        focusOnVehicle(vehicle)
        let points = [vehicle.coordinate, stop.coordinate]
        let minLat = points.map(\.latitude).min() ?? 0, maxLat = points.map(\.latitude).max() ?? 0
        let minLon = points.map(\.longitude).min() ?? 0, maxLon = points.map(\.longitude).max() ?? 0
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.6, 0.008), longitudeDelta: max((maxLon - minLon) * 1.6, 0.008))
        )
        withAnimation(.easeInOut(duration: 0.8)) { mapRegion = region }
    }

    // MARK: - Background Data Loading

    /// Charge les données en arrière-plan après l'affichage de la carte (une seule fois),
    /// ou relance simplement le flux temps réel s'il était arrêté.
    private func startBackgroundLoadingIfNeeded() {
        guard !hasStartedLoading else {
            if !viewModel.isLive {
                viewModel.startLiveStream()
            }
            return
        }
        hasStartedLoading = true
        startBackgroundLoading()
    }
    
    private func startBackgroundLoading() {
        // Charger les données de manière échelonnée pour éviter la contention réseau au cold start
        
        Task { @MainActor in
            // 1. Charger les véhicules en premier (priorité haute, inclut retry automatique)
            await loadSafely("Véhicules") { await self.viewModel.loadVehicles() }
            
            // 2. Charger les alertes juste après (priorité haute, inclut retry automatique)
            await loadSafely("Alertes") { await self.alertViewModel.loadAlerts() }
            
            // 3. Démarrer le live stream APRÈS les chargements critiques
            self.viewModel.startLiveStream()
            
            // 4. Charger les données secondaires en parallèle (réseau déjà "chaud")
            // Lancer en parallèle mais dans des Tasks séparées
            async let busTask: () = loadInBackground("Lignes bus") { 
                await self.viewModel.loadBusLines() 
            }
            async let transitTask: () = loadInBackground("Lignes transport") { 
                await self.viewModel.loadTransitLines() 
            }
            async let stopsTask: () = loadInBackground("Arrêts") { 
                await stopsViewModel.loadTransitStops() 
            }
            async let paletteTask: () = loadInBackground("Couleurs des lignes") {
                await self.viewModel.loadLinePalette()
            }
            
            // Attendre que tout soit terminé (mais chacun gère ses erreurs)
            _ = await (busTask, transitTask, stopsTask, paletteTask)
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
            // Filtres enregistrés qui ne laissent plus rien (ligne renumérotée, type sans véhicule) : le dire.
            if viewModel.filtersHideAllVehicles {
                FiltersHideAllBanner(onClear: { withAnimation { viewModel.clearFilters() } })
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let focus = viewModel.stopFocus, let vehicleId = focus.vehicleId {
                VehicleFocusCard(
                    focus: focus,
                    vehicle: viewModel.vehicles.first { $0.id == vehicleId },
                    onMore: { vehicle in selectedVehicle = vehicle },
                    onClose: { withAnimation { viewModel.clearStopFocus() } }
                )
                .padding(.top, 8)
                .padding(.horizontal, 16)
            } else if let focus = viewModel.stopFocus {
                StopFocusBanner(
                    focus: focus,
                    vehicleCount: viewModel.stopFocusVehicleCount,
                    onClear: { withAnimation { viewModel.clearStopFocus() } }
                )
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
                .allowsHitTesting(false)
            
            HStack(alignment: .bottom) {
                // Live indicator en bas à gauche
                liveIndicator
                
                Spacer()
                    .allowsHitTesting(false)
                
                // Boutons en bas à droite (stack vertical)
                VStack(spacing: 10) {
                    // Pastille trafic : verte, orange ou rouge, avec le nombre de lignes touchées
                    trafficPill

                    // Bouton fiches horaires
                    Button {
                        showTimetableSearch = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 50)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fiches horaires")

                    // Bouton satellite
                    Button {
                        withAnimation { isSatellite.toggle() }
                    } label: {
                        Image(systemName: isSatellite ? "globe.europe.africa.fill" : "globe.europe.africa")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSatellite ? Color.appWarning : Color.primary)
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
                            .foregroundStyle(hasActiveFilters ? Color.appAccent : Color.primary)
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
                            .foregroundStyle(Color.appAccent)
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

    private var trafficPill: some View {
        let state = TrafficBanner.shared.compute(
            subscriptions: alertViewModel.subscriptionService.subscriptions,
            alerts: alertViewModel.alerts.map(\.shared),
            nowEpoch: Int64(Date().timeIntervalSince1970)
        )
        return Button {
            showAlerts = true
        } label: {
            Image(systemName: trafficIcon(state.tone))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(trafficColor(state.tone))
                .frame(width: 50, height: 50)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                .overlay(alignment: .topTrailing) {
                    if state.count > 0 {
                        Text("\(state.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(trafficColor(state.tone), in: Capsule())
                            .offset(x: 3, y: -3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.title)
    }

    private func trafficIcon(_ tone: TrafficBanner.Tone) -> String {
        switch tone {
        case .normal: "checkmark.circle"
        case .warning: "exclamationmark.triangle.fill"
        case .major: "exclamationmark.octagon.fill"
        default: "checkmark.circle"
        }
    }

    private func trafficColor(_ tone: TrafficBanner.Tone) -> Color {
        switch tone {
        case .normal: .appSuccess
        case .warning: .appWarning
        case .major: .appError
        default: .appSuccess
        }
    }
    
    private var liveIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Flux vide alors que tout fonctionne : TCL ne transmet rien.
            if viewModel.isInitialLoadComplete, !viewModel.isLoading,
               viewModel.error == nil, viewModel.vehicles.isEmpty {
                statusCapsule(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    text: "TCL ne transmet aucune position en ce moment"
                )
            }

            // Données figées : le stream tourne mais plus aucune mise à jour n'aboutit.
            if viewModel.isLive, let lastUpdate = viewModel.lastUpdate {
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    let frozen = Date().timeIntervalSince(lastUpdate)
                    if frozen > 60 {
                        statusCapsule(
                            icon: "clock.arrow.circlepath",
                            text: "Dernières données reçues il y a \(Vehicle.formattedAge(frozen))"
                        )
                    }
                }
            }

            // Warning indicator si erreurs de données
            if hasDataSourceErrors {
                Button {
                    showDataSourceErrors = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appWarning)
                        
                        Text("\(totalDataSourceErrors) source\(totalDataSourceErrors > 1 ? "s" : "") en erreur")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .appWarning.opacity(0.2), radius: 4, x: 0, y: 2)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.appWarning.opacity(0.4), lineWidth: 1)
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
                        .fill(viewModel.error != nil ? Color.appWarning : Color.appSuccess)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.isLive ? "LIVE" : "PAUSE")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(viewModel.isLive ? (viewModel.error != nil ? Color.appWarning : Color.appSuccess) : .secondary)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else if let lastUpdate = viewModel.lastUpdate {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let secs = max(0, Int(viewModel.adaptiveInterval) - Int(Date().timeIntervalSince(lastUpdate)))
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
                                .fill(Color.appSuccess.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.appSuccess)
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
                            Text("15s")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appSuccess)
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
                            .foregroundStyle(Color.appSuccess)
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
    
    /// Capsule d'information sobre, même style que le badge LIVE.
    private func statusCapsule(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appWarning)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
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
        viewModel.stopFocus != nil ||
        viewModel.selectedVehicleType != nil ||
        viewModel.selectedLine != nil ||
        !viewModel.selectedLines.isEmpty ||
        viewModel.showBusTraces ||
        !viewModel.showTramTraces ||
        !viewModel.showMetroTraces
    }
}

// Legacy SwiftUI `VehicleMarker` supprimé — rendu désormais via
// `MarkerImageCache` + `MKAnnotationView` (cf. LiveMapRepresentable).



// URL est Identifiable via absoluteString pour .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Visionneuse photo plein écran

private struct PhotoFullscreenSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .failure:
                        ContentUnavailableView("Photo indisponible", systemImage: "photo.slash")
                    default:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

struct VehicleDetailSheet: View {
    let vehicle: Vehicle
    /// Optionnel : quand fourni, la fiche suit les nouvelles positions du véhicule
    /// pendant qu'elle est ouverte (fraîcheur, retard) au lieu de figer l'instantané du tap.
    var liveViewModel: LiveVehiclesViewModel? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var vehicleModel: String?
    @State private var vehiclePhotos: [URL] = []
    @State private var selectedPhoto: URL?

    /// Version la plus récente du véhicule connue de l'app.
    private var current: Vehicle {
        liveViewModel?.vehicles.first { $0.id == vehicle.id } ?? vehicle
    }

    /// Couleur officielle de la ligne du véhicule : toute la fiche s'y accorde.
    private var accentColor: Color { LineColorHelper.backgroundColor(for: vehicle.lineName) }
    private var accentTextColor: Color { LineColorHelper.textColor(for: vehicle.lineName) }

    // Destination propre (masquer les IDs techniques)
    private var cleanDestination: String? {
        let d = vehicle.destination
        guard !d.isEmpty, !d.contains(":"), d.count < 60 else { return nil }
        return d
    }

    // Dernier arrêt surveillé (MonitoredCall SIRI) — Grand Lyon ne renvoie qu'un seul arrêt par véhicule.
    private var stopsToShow: [(stop: StopInfo, isNext: Bool)] {
        guard let next = vehicle.nextStop else { return [] }
        return [(next, true)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    if !stopsToShow.isEmpty {
                        timelineSection
                    }
                    fleetInfoSection
                    footerSection
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .task {
                guard let fleet = vehicle.fleetNumber else { return }
                vehicleModel = await BusTrackerService.shared.fetchVehicleModel(fleetNumber: fleet)
                if let model = vehicleModel {
                    vehiclePhotos = await WikimediaService.shared.fetchPhotos(for: model)
                }
            }
            .sheet(item: $selectedPhoto) { url in
                PhotoFullscreenSheet(url: url)
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Badge ligne
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 64, height: 64)
                    VStack(spacing: 2) {
                        Image(systemName: vehicle.vehicleType.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentTextColor)
                        Text(vehicle.lineName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accentTextColor)
                            .lineLimit(1)
                    }
                }
                .shadow(color: accentColor.opacity(0.35), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text(vehicle.vehicleType.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    if let dest = cleanDestination {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(dest)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("Ligne \(vehicle.lineName)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    delayPill
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            freshnessRow
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var fleetInfoSection: some View {
        if let fleet = vehicle.fleetNumber {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Véhicule")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(accentColor.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: vehicle.vehicleType.icon)
                                .font(.body.weight(.medium))
                                .foregroundStyle(accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Numéro de parc")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(fleet)
                                .font(.headline)
                            if let model = vehicleModel {
                                Text(model)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Source : bus-tracker.fr")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    if vehicleModel != nil {
                        if !vehiclePhotos.isEmpty {
                            Divider().padding(.leading, 70)
                            VStack(alignment: .leading, spacing: 6) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 8) {
                                        ForEach(vehiclePhotos, id: \.self) { url in
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure:
                                                    Color(.systemFill)
                                                        .overlay {
                                                            Image(systemName: "photo")
                                                                .foregroundStyle(.tertiary)
                                                        }
                                                default:
                                                    Color(.systemFill)
                                                        .overlay { ProgressView() }
                                                }
                                            }
                                            .frame(width: 180, height: 112)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .onTapGesture { selectedPhoto = url }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                Text("Source : Wikimedia Commons (CC-BY-SA)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 12)
                        }
                        if vehiclePhotos.isEmpty,
                           let model = vehicleModel,
                           let encodedQuery = "\(model) TCL SYTRAL".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let photosURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)&tbm=isch") {
                            Divider().padding(.leading, 70)
                            Link(destination: photosURL) {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.caption.weight(.medium))
                                    Text("Photos de ce véhicule")
                                        .font(.caption.weight(.medium))
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                            }
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    /// Ligne "fraîcheur de la position" : âge de la dernière transmission TCL,
    /// mis à jour chaque seconde tant que la fiche est ouverte.
    @ViewBuilder
    private var freshnessRow: some View {
        if vehicle.recordedAt != nil {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let age = current.positionAge ?? 0
                let freshness = current.positionFreshness
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(freshness.color)
                            .frame(width: 7, height: 7)
                        Text("Position transmise par TCL il y a \(Vehicle.formattedAge(age))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    if freshness == .stale {
                        Text("TCL n'a rien envoyé de plus récent pour ce véhicule, sa position réelle a probablement changé.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var delayPill: some View {
        let color: Color = vehicle.isDelayed ? .appWarning : (vehicle.isEarly ? Color.appAccent : Color.appSuccess)
        let icon = vehicle.isDelayed ? "clock.badge.exclamationmark.fill" : "clock.fill"
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(vehicle.delayFormatted)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dernier arrêt")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(stopsToShow.enumerated()), id: \.offset) { index, item in
                    timelineRow(
                        stop: item.stop,
                        isNext: item.isNext,
                        isLast: index == stopsToShow.count - 1
                    )
                }
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private func timelineRow(stop: StopInfo, isNext: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Colonne gauche : trait + dot
            VStack(spacing: 0) {
                // Trait supérieur (sauf premier)
                if !isNext {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 2)
                        .frame(height: 10)
                }

                // Dot
                ZStack {
                    if isNext {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 24, height: 24)
                        Circle()
                            .fill(accentColor)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .strokeBorder(Color(.separator), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                    }
                }

                // Trait inférieur
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 2)
                        .frame(minHeight: 28)
                }
            }
            .frame(width: 28)
            .padding(.top, isNext ? 14 : 10)

            // Contenu
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.stopName ?? stop.stopRef)
                        .font(isNext ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundStyle(isNext ? .primary : .secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let arrival = stop.aimedArrivalTime ?? stop.aimedDepartureTime {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(arrival, format: .dateTime.hour().minute())
                            .font(isNext ? .subheadline.weight(.semibold) : .caption.weight(.medium))
                            .foregroundStyle(isNext ? .primary : .secondary)
                            .monospacedDigit()

                        if isNext, let timeUntil = stop.timeUntilArrival, timeUntil > 0 {
                            Text("dans \(Int(timeUntil / 60)) min")
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, isNext ? 16 : 12)
            .padding(.trailing, 4)
        }
    }

    // MARK: Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            if let recordedAt = vehicle.recordedAt {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("Mis à jour à \(recordedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
            }
        }
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
                                    .foregroundStyle(Color.appError)
                                Text("Réinitialiser les filtres")
                                    .foregroundStyle(Color.appError)
                            }
                        }
                    }
                }
                
                if let focus = viewModel.stopFocus {
                    Section("Bus d'un arrêt") {
                        Button {
                            viewModel.clearStopFocus()
                        } label: {
                            HStack(spacing: 10) {
                                LineBadge(line: focus.line)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vers \(focus.destination)")
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("Seuls ces véhicules sont affichés. Touchez pour tout réafficher.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Tracés des lignes") {
                    Toggle(isOn: $viewModel.showBusTraces) {
                        Label("Bus", systemImage: "bus")
                    }
                    Toggle(isOn: $viewModel.showTramTraces) {
                        Label("Tram", systemImage: "tram.fill")
                    }
                    Toggle(isOn: $viewModel.showMetroTraces) {
                        Label("Métro / Funiculaire", systemImage: "tram.fill.tunnel")
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
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            
                            Text("Tous les types")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if viewModel.selectedVehicleType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                    
                    ForEach(VehicleType.allCases.filter { type in
                        viewModel.vehicles.contains { $0.vehicleType == type }
                    }, id: \.self) { type in
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
                                    .foregroundStyle(type.clusterColor)
                                    .frame(width: 24)
                                
                                Text(type.rawValue)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                                
                                if viewModel.selectedVehicleType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
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
                                    .foregroundStyle(Color.appFavorite)
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
                                            .foregroundStyle(Color.appAccent)
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
        viewModel.stopFocus != nil ||
        viewModel.selectedVehicleType != nil ||
        viewModel.selectedLine != nil ||
        !viewModel.selectedLines.isEmpty ||
        viewModel.showBusTraces ||
        !viewModel.showTramTraces ||
        !viewModel.showMetroTraces
    }
    
    @ViewBuilder
    private func lineRow(line: String) -> some View {
        let isSelected = viewModel.selectedLines.contains(line)
        
        Button {
            viewModel.toggleLineSelection(line)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appNeutral)
                    .frame(width: 24)
                
                // La couleur officielle de la ligne, la même que sur la carte.
                LineBadge(line: line, size: 12)
                
                Text(line)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    favoritesService.toggleFavorite(line)
                } label: {
                    let isFavorite = favoritesService.isFavorite(line)
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? Color.appFavorite : Color.appNeutral)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
}

// MARK: - Bandeau du véhicule touché

/// Remplace le bandeau trafic quand un véhicule a été touché : trois chiffres, le délai depuis la
/// dernière position en premier, « Voir plus » pour la fiche, une croix pour retirer le filtre.
private struct VehicleFocusCard: View {
    let focus: StopLineFocus
    let vehicle: Vehicle?
    let onMore: (Vehicle) -> Void
    let onClose: () -> Void

    private var lineColor: Color { LineColorHelper.backgroundColor(for: focus.line) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                LineBadge(line: focus.line, size: 13)
                VStack(alignment: .leading, spacing: 1) {
                    Text(focus.bannerTitle)
                        .font(.system(size: 15, weight: .bold))
                    Text("→ \(vehicle?.destination ?? focus.destination)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let vehicle {
                    Button("Voir plus") { onMore(vehicle) }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(lineColor)
                        .foregroundStyle(LineColorHelper.textColor(for: focus.line))
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer")
            }

            if let vehicle {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(alignment: .top, spacing: 10) {
                        stat(
                            value: vehicle.positionAge.map(Vehicle.formattedAge) ?? "—",
                            caption: "dernière position",
                            color: vehicle.positionFreshness.color,
                            emphasized: true
                        )
                        stat(
                            value: vehicle.delayFormatted,
                            caption: vehicle.isDelayed ? "retard" : (vehicle.isEarly ? "avance" : "horaire"),
                            color: vehicle.isDelayed ? .appWarning : (vehicle.isEarly ? Color.appAccent : Color.appSuccess),
                            emphasized: false
                        )
                        if let next = vehicle.nextStop, let name = next.stopName {
                            stat(
                                value: (next.aimedArrivalTime ?? next.aimedDepartureTime).map { $0.formatted(date: .omitted, time: .shortened) } ?? "—",
                                caption: name,
                                color: .primary,
                                emphasized: false
                            )
                        }
                    }
                }
            } else {
                Text("Véhicule plus suivi pour l'instant")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(lineColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    /// Un chiffre et sa légende ; le premier, mis en avant, est plus grand.
    private func stat(value: String, caption: String, color: Color, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: emphasized ? 22 : 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bandeau « bus de cet arrêt »

/// Les filtres masquent tous les véhicules : une phrase et « Tout afficher ».
private struct FiltersHideAllBanner: View {
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.appWarning)
            Text(MapFilterTexts.shared.HIDING_EVERYTHING)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("Tout afficher", action: onClear)
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.appWarning.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

private struct StopFocusBanner: View {
    let focus: StopLineFocus
    let vehicleCount: Int
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            LineBadge(line: focus.line, size: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(focus.bannerTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(focus.bannerSubtitle(vehicleCount: Int32(vehicleCount)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button("Tout afficher", action: onClear)
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Traffic Banner View


// MARK: - Subscribed Line Pill

private struct SubscribedLinePill: View {
    @ObservedObject private var palette = LinePaletteObserver.shared
    let line: TransportLine
    let disruption: AlertViewModel.LineAlertSummary?

    @State private var isPulsing = false

    private var dotColor: Color? {
        guard let d = disruption else { return nil }
        return d.highestSeverity == .major ? Color.appError : Color.appWarning
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
                        LineColorHelper.needsBorder(for: lineName) ? Color.appNeutralBorder : .clear,
                        lineWidth: 0.5
                    )
                )

            if let color = dotColor {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    .scaleEffect(isPulsing && color == .appError ? 1.3 : 1.0)
                    .animation(
                        color == .appError
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