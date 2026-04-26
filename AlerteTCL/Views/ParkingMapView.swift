import SwiftUI
import MapKit
import CoreLocation

struct ParkingMapView: View {
    @StateObject private var viewModel = ParkingViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedParking: Parking?
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var currentSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    @State private var hasSetInitialLocation = false
    @State private var showRefreshInfo = false
    @State private var isSatellite = false
    @State private var showFilters = false
    @State private var transitLines: [TransitLine] = []
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
        .sheet(isPresented: $showFilters) {
            ParkingFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.onAppear()
            Task {
                transitLines = (try? await TransitLineService.shared.fetchTransitLines()) ?? []
            }
        }
        .withInitialLocation(
            mapCameraPosition: $mapCameraPosition,
            hasSetInitialLocation: $hasSetInitialLocation
        )
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
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
                // Lignes de transport en commun
                ForEach(transitLines) { line in
                    MapPolyline(coordinates: line.clLocationCoordinates)
                        .stroke(line.lineColor.opacity(0.85), lineWidth: line.lineWidth)
                }

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
                
                // P+R TCL (toujours affichés dans l'onglet voiture)
                if viewModel.selectedParkingType == .car && viewModel.showParcRelais {
                    ForEach(viewModel.parcRelais) { pr in
                        Annotation("", coordinate: pr.coordinate) {
                            ParkingMarker(parking: pr, currentZoomLevel: viewModel.currentZoomLevel)
                                .onTapGesture { selectedParking = pr }
                        }
                    }
                }

                if locationService.currentLocation != nil {
                    UserAnnotation()
                }
            }
            .mapStyle(isSatellite ? .imagery(elevation: .realistic) : .standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange { context in
                currentSpan = context.region.span
                viewModel.updateZoomLevel(context.region.span)
                viewModel.updateVisibleRegion(context.region)
            }
            .overlay {
                if let error = viewModel.error {
                    parkingErrorOverlay(error)
                }
            }
        }
    }
    
    private func parkingErrorOverlay(_ error: String) -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 22 || hour < 6
        let icon = isNight ? "moon.zzz.fill" : "cloud.slash.fill"
        let iconColor: Color = isNight ? .indigo : .orange
        let title = isNight ? "Les serveurs se reposent" : "Données temporairement indisponibles"
        let subtitle = isNight
            ? "Grand Lyon coupe ses serveurs la nuit. Revenez après 6h !"
            : friendlyServerMessage(for: error)
        return VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                Task { await viewModel.loadParkings() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        .padding(20)
    }
    
    private func friendlyServerMessage(for error: String) -> String {
        if error.contains("504") || error.contains("Timeout") || error.contains("timeout") || error.contains("timed out") {
            return "Le serveur Grand Lyon prend son temps... Réessayez dans quelques instants."
        } else if error.contains("500") || error.contains("502") || error.contains("503") {
            return "Le serveur Grand Lyon est en maintenance. Revenez bientôt !"
        } else if error.contains("connection") || error.contains("network") || error.contains("Network") {
            return "Vérifiez votre connexion internet."
        }
        return "Une erreur inattendue s'est produite. Réessayez dans quelques instants."
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
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run { selectedParking = parking }
                }
            }
        }
    }
    
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .bottom) {
                // Card refresh en bas à gauche (uniquement pour voitures - données temps réel)
                if viewModel.selectedParkingType == .car {
                    refreshCard
                }
                
                Spacer()
                
                // Boutons à droite
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

                    // Bouton filtres (onglet voiture uniquement)
                    if viewModel.selectedParkingType == .car {
                        let hasActiveFilters = !viewModel.showRealtimeParkings || !viewModel.showParcRelais
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
                    }

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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isLoadingInBackground)
    }
    
    private var refreshCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showRefreshInfo.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.error != nil ? Color.orange : Color.blue)
                    .frame(width: 8, height: 8)

                Text("LIVE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(viewModel.error != nil ? .orange : .blue)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(viewModel.secondsUntilNextRefresh)s")
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
        .padding(.leading, 24)
        .padding(.bottom, 24)
        .popover(isPresented: $showRefreshInfo, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "parkingsign.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temps réel")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Disponibilités en direct")
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
                        Text("60s")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
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
                        .foregroundStyle(.blue)
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
}

// MARK: - Parking Marker
struct ParkingMarker: View {
    let parking: Parking
    var currentZoomLevel: Double = 0.01

    private let tooltipZoomThreshold: Double = 0.005

    private var isCompactMarker: Bool {
        parking.parkingType == .bike || parking.parkingType == .motorized2Wheel
    }

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
            Circle()
                .fill(parking.availabilityColor)
                .frame(width: 16, height: 16)
                .shadow(color: parking.availabilityColor.opacity(0.5), radius: 3, x: 0, y: 1)
                .overlay(Circle().stroke(.white, lineWidth: 2))

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
                                .fill(parking.availabilityColor)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                }
                .offset(y: -20)
            }
        }
    }

    // MARK: - Full Marker (Voitures + P+R)

    private var fullMarkerView: some View {
        ZStack {
            Circle()
                .fill(parking.availabilityColor)
                .frame(width: 44, height: 44)
                .shadow(color: parking.availabilityColor.opacity(0.4), radius: 6, x: 0, y: 3)

            VStack(spacing: 0) {
                if parking.isParcRelais {
                    Text("P+R")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.9))
                    if parking.hasRealtimeData {
                        Text("\(parking.placesDisponibles)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "car.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                } else {
                    Image(systemName: parking.parkingType.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(parking.placesDisponibles)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .overlay(
            // État open/closed uniquement pour les parkings standards (P+R n'ont pas ce concept)
            Group {
                if !parking.isParcRelais {
                    Circle()
                        .fill(parking.etat == .ouvert ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 16, y: -16)
                }
            }
        )
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

                    // Bannière statique P+R (pas de données temps réel)
                    if parking.isParcRelais && !parking.hasRealtimeData {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Données statiques uniquement")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                                Text("La disponibilité en temps réel n'est pas disponible pour ce P+R.")
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 0)
                    }

                    // Bouton itinéraire en premier
                    navigationButton

                    // Infos principales
                    mainInfoCard

                    // Tarifs (uniquement parkings standard)
                    if !parking.isParcRelais && hasTarifs {
                        tarifCard
                    }

                    // Services (uniquement parkings standard)
                    if !parking.isParcRelais && hasServices {
                        servicesCard
                    }

                    // Informations supplémentaires (uniquement parkings standard)
                    if !parking.isParcRelais {
                        additionalInfoCard
                    }

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
            .background(.ultraThinMaterial)
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
                    .stroke(parking.availabilityColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: parking.hasRealtimeData ? max(0, 1 - parking.tauxOccupation) : 0)
                    .stroke(
                        parking.availabilityColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    if parking.hasRealtimeData {
                        Text("\(parking.placesDisponibles)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(parking.availabilityColor)
                    } else {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.gray)
                    }

                    Text("/ \(parking.capaciteTotale)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // État / statut temps réel
            HStack(spacing: 6) {
                if parking.isParcRelais {
                    Image(systemName: parking.hasRealtimeData
                          ? "antenna.radiowaves.left.and.right"
                          : "clock.badge.exclamationmark")
                        .foregroundStyle(parking.hasRealtimeData ? .green : .orange)
                    Text(parking.hasRealtimeData ? "Données en direct" : "Données statiques")
                        .font(.headline)
                        .foregroundStyle(parking.hasRealtimeData ? .green : .orange)
                } else {
                    Image(systemName: parking.etat.icon)
                        .foregroundStyle(parking.etat == .ouvert ? .green : .red)
                    Text(parking.etat.displayName)
                        .font(.headline)
                        .foregroundStyle(parking.etat == .ouvert ? .green : .red)
                }
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    private var mainInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Informations", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                if !parking.isParcRelais {
                    InfoRow(icon: "building.2", title: "Gestionnaire", value: parking.gestionnaire)

                    if let hauteur = parking.hauteurMax {
                        InfoRow(icon: "arrow.up.and.down", title: "Hauteur max", value: "\(hauteur) cm")
                    }
                }

                InfoRow(icon: "car", title: "Capacité totale", value: "\(parking.capaciteTotale) places")

                if let pmr = parking.nbPmr, pmr > 0 {
                    InfoRow(icon: "figure.roll", title: "Places PMR", value: "\(pmr) places")
                }

                // Champs spécifiques P+R
                if parking.isParcRelais {
                    if let horaires = parking.horaires {
                        InfoRow(icon: "clock", title: "Horaires", value: horaires)
                    }
                    if let surveille = parking.surveille {
                        InfoRow(
                            icon: surveille ? "eye.fill" : "eye.slash",
                            title: "Surveillance",
                            value: surveille ? "Parc surveillé" : "Non surveillé"
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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

// MARK: - Parking Filter Sheet

struct ParkingFilterSheet: View {
    @ObservedObject var viewModel: ParkingViewModel
    @Environment(\.dismiss) private var dismiss

    private var hasActiveFilters: Bool {
        !viewModel.showRealtimeParkings || !viewModel.showParcRelais
    }

    var body: some View {
        NavigationStack {
            List {
                if hasActiveFilters {
                    Section {
                        Button {
                            withAnimation {
                                viewModel.showRealtimeParkings = true
                                viewModel.showParcRelais        = true
                            }
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

                Section {
                    // Parkings temps réel
                    Button {
                        withAnimation { viewModel.showRealtimeParkings.toggle() }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 16))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Parkings temps réel")
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                                Text("\(viewModel.parkings.count) parkings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.showRealtimeParkings {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Parcs relais
                    Button {
                        withAnimation { viewModel.showParcRelais.toggle() }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.34, green: 0.22, blue: 0.47).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text("P+R")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(Color(red: 0.34, green: 0.22, blue: 0.47))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Parcs Relais TCL")
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                                Text("\(viewModel.parcRelais.count) P+R • données statiques")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.showParcRelais {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Afficher sur la carte")
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminé") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ParkingMapView(selectedParkingId: .constant(nil))
}


