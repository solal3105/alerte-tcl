import SwiftUI
import MapKit

struct ParkingMapView: View {
    @StateObject private var viewModel = ParkingViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedParking: Parking?
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    
    var body: some View {
        ZStack {
            mapContent
            overlayControls
        }
        .sheet(item: $selectedParking) { parking in
            ParkingDetailSheet(parking: parking, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    private var mapContent: some View {
        Map(position: $mapCameraPosition) {
            ForEach(viewModel.parkings) { parking in
                Annotation(parking.nom, coordinate: parking.coordinate) {
                    ParkingMarker(parking: parking)
                        .onTapGesture {
                            selectedParking = parking
                        }
                }
            }
            
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .top)
    }
    
    private var overlayControls: some View {
        VStack {
            // Stats card en haut
            statsCard
            
            Spacer()
            
            HStack(alignment: .bottom) {
                // Card refresh en bas à gauche
                refreshCard
                
                Spacer()
                
                // Bouton localisation en bas à droite
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
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
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
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(markerColor)
                .frame(width: 44, height: 44)
                .shadow(color: markerColor.opacity(0.4), radius: 6, x: 0, y: 3)
            
            // Inner content
            VStack(spacing: 0) {
                Image(systemName: "car.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(parking.placesDisponibles)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            // État indicator
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
}

// MARK: - Parking Detail Sheet
struct ParkingDetailSheet: View {
    let parking: Parking
    @ObservedObject var viewModel: ParkingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header avec places disponibles
                    availabilityHeader
                    
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
                    
                    // Actions
                    actionsCard
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
                InfoRow(icon: "mappin.circle", title: "Adresse", value: parking.adresse)
                
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
    
    private var actionsCard: some View {
        VStack(spacing: 12) {
            // Bouton itinéraire
            Button {
                openInMaps()
            } label: {
                Label("Itinéraire", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            // Bouton site web
            if let urlString = parking.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("Site web", systemImage: "safari")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
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
    ParkingMapView()
}
