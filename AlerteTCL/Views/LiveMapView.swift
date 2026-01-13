import SwiftUI
import MapKit

struct LiveMapView: View {
    @StateObject private var viewModel = LiveVehiclesViewModel()
    @EnvironmentObject var alertViewModel: AlertViewModel
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedVehicle: Vehicle?
    @State private var selectedStop: TransitStop?
    @State private var showFilters = false
    @State private var showAlerts = false
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
    
    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        ZStack {
            mapContent
            
            overlayControls
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailSheet(vehicle: vehicle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStop) { stop in
            TransitStopDetailSheet(stop: stop)
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
        .onAppear {
            // Démarrer immédiatement la localisation (non bloquant)
            locationService.requestPermission()
            locationService.startUpdatingLocation()
            
            if let userLocation = locationService.currentLocation, !isSimulator() {
                withAnimation(.easeInOut(duration: 0.8)) {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: userLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
            
            // Charger les données progressivement en arrière-plan
            Task(priority: .userInitiated) {
                // D'abord les véhicules (plus important)
                await viewModel.loadVehicles()
                viewModel.startAutoRefresh()
                
                // Charger les alertes pour la carte de résumé
                await alertViewModel.loadAlerts()
                
                // Puis les lignes (moins prioritaire)
                await viewModel.loadBusLines()
                await viewModel.loadTransitLines()
                
                // Charger les arrêts avec passages
                await viewModel.loadTransitStops()
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await viewModel.loadVehicles()
                viewModel.startAutoRefresh()
            }
        }
        .onChange(of: locationService.currentLocation) { oldValue, newValue in
            if oldValue == nil, let newLocation = newValue, !isSimulator() {
                withAnimation(.easeInOut(duration: 0.8)) {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: newLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        }
    }
    
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition, interactionModes: .all) {
                UserAnnotation()
                
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
                    let coordinate = animated?.animatedCoordinate ?? vehicle.coordinate
                    let bearing = animated?.animatedBearing ?? vehicle.bearing
                    
                    Annotation(vehicle.lineName, coordinate: coordinate) {
                        VehicleMarker(vehicle: vehicle, bearing: bearing)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(vehicle.accessibilityDescription)
                            .accessibilityHint("Double-cliquer pour voir les détails du véhicule")
                            .onTapGesture {
                                selectedVehicle = vehicle
                            }
                    }
                }
                
                // Afficher les arrêts avec prochains passages (au zoom fort uniquement)
                ForEach(viewModel.visibleStops, id: \.id) { stop in
                    Annotation(stop.nom, coordinate: stop.coordinate) {
                        TransitStopMarker(stop: stop)
                            .onTapGesture {
                                selectedStop = stop
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
            .overlay {
                if viewModel.shouldShowTooManyMarkersWarning {
                    tooManyMarkersWarning
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
            
            Text("Zoomez sur la carte pour afficher les véhicules")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
        .padding(20)
    }
    
    private var overlayControls: some View {
        VStack {
            // Carte d'alertes en haut (visible s'il y a des alertes)
            if !alertViewModel.linesInError.isEmpty {
                alertsSummaryCard
                    .padding(.top, 60)
                    .padding(.horizontal, 16)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                // Card refresh en bas à gauche
                refreshCard
                
                Spacer()
                
                // Boutons en bas à droite (stack vertical)
                VStack(spacing: 12) {
                    // Bouton toggle arrêts
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showTransitStops.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.showTransitStops ? "mappin.circle.fill" : "mappin.circle")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.showTransitStops ? .purple : .gray)
                    .controlSize(.large)
                    
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
                        if let userLocation = locationService.currentLocation, !isSimulator() {
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
    
    // MARK: - Alerts Summary Card
    
    private var alertsSummaryCard: some View {
        Button {
            showAlerts = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                    
                    Text("\(alertViewModel.linesInError.count) ligne\(alertViewModel.linesInError.count > 1 ? "s" : "") perturbée\(alertViewModel.linesInError.count > 1 ? "s" : "")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                // Lignes affectées (priorité aux abonnées)
                alertLinesPreview
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var alertLinesPreview: some View {
        let subscribedLinesInError = alertViewModel.linesInError.filter { summary in
            alertViewModel.subscribedLines.contains { $0.ligneCom == summary.id || $0.ligneCli == summary.id }
        }
        let otherLinesInError = alertViewModel.linesInError.filter { summary in
            !subscribedLinesInError.contains { $0.id == summary.id }
        }
        
        // Prioriser les lignes abonnées, puis les autres
        let sortedLines = subscribedLinesInError + otherLinesInError
        let displayLines = Array(sortedLines.prefix(6))
        
        return HStack(spacing: 8) {
            ForEach(displayLines, id: \.id) { summary in
                alertLineBadge(summary: summary, isSubscribed: subscribedLinesInError.contains { $0.id == summary.id })
            }
            
            if sortedLines.count > 6 {
                Text("+\(sortedLines.count - 6)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func alertLineBadge(summary: AlertViewModel.LineAlertSummary, isSubscribed: Bool) -> some View {
        let bgColor = LineColorHelper.backgroundColor(for: summary.displayName)
        let textColor = LineColorHelper.textColor(for: summary.displayName)
        let needsBorder = LineColorHelper.needsBorder(for: summary.displayName)
        
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor)
                .frame(width: 32, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
                )
            
            Text(summary.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .overlay(alignment: .topTrailing) {
            if isSubscribed {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: -4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(severityColor(summary.highestSeverity))
                .frame(width: 8, height: 8)
                .offset(x: 2, y: 2)
        }
    }
    
    private func severityColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
    
    private func lineColor(for line: TransportLine) -> Color {
        switch line.mode {
        case .metro:
            switch line.ligneCli {
            case "A": return Color(red: 0.95, green: 0.26, blue: 0.21)
            case "B": return Color(red: 0.0, green: 0.45, blue: 0.81)
            case "C": return Color(red: 1.0, green: 0.6, blue: 0.0)
            case "D": return Color(red: 0.0, green: 0.59, blue: 0.53)
            default: return .gray
            }
        case .tramway:
            switch line.ligneCli {
            case "T1": return Color(red: 0.95, green: 0.26, blue: 0.21)
            case "T2": return Color(red: 0.95, green: 0.26, blue: 0.21)
            case "T3": return Color(red: 1.0, green: 0.6, blue: 0.0)
            case "T4": return Color(red: 0.61, green: 0.15, blue: 0.69)
            case "T5": return Color(red: 0.0, green: 0.59, blue: 0.53)
            case "T6": return Color(red: 0.95, green: 0.26, blue: 0.21)
            case "T7": return Color(red: 0.0, green: 0.45, blue: 0.81)
            default: return .red
            }
        case .busC:
            return Color(red: 1.0, green: 0.6, blue: 0.0)
        case .bus:
            return Color(red: 0.0, green: 0.45, blue: 0.81)
        case .funiculaire:
            return Color(red: 0.0, green: 0.59, blue: 0.53)
        case .navette:
            return .purple
        }
    }
    
    private var refreshCard: some View {
        Button {
            Task { await viewModel.loadVehicles() }
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
    
    private var hasActiveFilters: Bool {
        viewModel.selectedVehicleType != nil || viewModel.selectedLine != nil || !viewModel.selectedLines.isEmpty
    }
}

struct VehicleMarker: View {
    let vehicle: Vehicle
    var bearing: Double
    
    init(vehicle: Vehicle, bearing: Double? = nil) {
        self.vehicle = vehicle
        self.bearing = bearing ?? vehicle.bearing
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
        }
    }
    
    private var markerColor: Color {
        switch vehicle.vehicleType {
        case .metro:
            // Métro : couleurs selon la ligne
            switch vehicle.lineName.uppercased() {
            case let line where line.contains("A"):
                return Color(hex: "EE3898") // Rose/Fuchsia
            case let line where line.contains("B"):
                return Color(hex: "007DC5") // Bleu
            case let line where line.contains("C"):
                return Color(hex: "F99D1D") // Orange
            case let line where line.contains("D"):
                return Color(hex: "00AC4D") // Vert
            default:
                return .orange
            }
        case .tram:
            return Color(hex: "8C368C") // Violet/Mauve pour tous les trams
        case .bus:
            // Bus : différencier C, TB et autres
            let lineName = vehicle.lineName.uppercased()
            if lineName.hasPrefix("C") && lineName.count >= 2 && lineName[lineName.index(after: lineName.startIndex)].isNumber {
                return Color.gray // Gris pour les lignes C
            } else if lineName.hasPrefix("TB") {
                return Color(hex: "DAA520") // Jaune foncé (goldenrod) pour trambus
            } else {
                return .white // Fond blanc pour les autres bus
            }
        case .trolley:
            return Color(hex: "DAA520") // Jaune foncé pour trolleybus
        case .funicular:
            return Color(hex: "8BC752") // Vert clair pour funiculaires
        }
    }
    
    private var iconColor: Color {
        switch vehicle.vehicleType {
        case .bus:
            let lineName = vehicle.lineName.uppercased()
            if lineName.hasPrefix("C") && lineName.count >= 2 && lineName[lineName.index(after: lineName.startIndex)].isNumber {
                return .white // Icône blanche pour les lignes C
            } else if !lineName.hasPrefix("TB") {
                return .gray // Icône grise pour les autres bus (non-C, non-TB)
            }
        default:
            break
        }
        return .white // Icône blanche par défaut
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

#Preview {
    LiveMapView()
}
