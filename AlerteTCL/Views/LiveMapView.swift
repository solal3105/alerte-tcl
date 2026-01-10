import SwiftUI
import MapKit

struct LiveMapView: View {
    @StateObject private var viewModel = LiveVehiclesViewModel()
    @State private var selectedVehicle: Vehicle?
    @State private var showFilters = false
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
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailSheet(vehicle: vehicle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.loadVehicles()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
    
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition, interactionModes: .all) {
                if viewModel.shouldShowClusters {
                    ForEach(viewModel.clusters) { cluster in
                        Annotation("", coordinate: cluster.coordinate) {
                            ClusterMarker(cluster: cluster)
                        }
                    }
                    
                    let clusteredIds = Set(viewModel.clusters.flatMap { $0.vehicles.map { $0.id } })
                    ForEach(viewModel.filteredVehicles.filter { !clusteredIds.contains($0.id) }) { vehicle in
                        let animated = viewModel.animatedVehicles[vehicle.id]
                        let coordinate = animated?.animatedCoordinate ?? vehicle.coordinate
                        let bearing = animated?.animatedBearing ?? vehicle.bearing
                        
                        Annotation(vehicle.lineName, coordinate: coordinate) {
                            VehicleMarker(vehicle: vehicle, bearing: bearing)
                                .onTapGesture {
                                    selectedVehicle = vehicle
                                }
                        }
                    }
                } else {
                    ForEach(viewModel.filteredVehicles) { vehicle in
                        let animated = viewModel.animatedVehicles[vehicle.id]
                        let coordinate = animated?.animatedCoordinate ?? vehicle.coordinate
                        let bearing = animated?.animatedBearing ?? vehicle.bearing
                        
                        Annotation(vehicle.lineName, coordinate: coordinate) {
                            VehicleMarker(vehicle: vehicle, bearing: bearing)
                                .onTapGesture {
                                    selectedVehicle = vehicle
                                }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange { context in
                viewModel.updateZoomLevel(context.region.span)
            }
        }
    }
    
    private var overlayControls: some View {
        VStack {
            headerBar
            
            Spacer()
            
            bottomControls
        }
    }
    
    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transport Live")
                        .font(.system(size: 20, weight: .bold))
                    
                    if let lastUpdate = viewModel.lastUpdate {
                        Text("Mis à jour \(lastUpdate.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(hasActiveFilters ? .blue : .primary)
                    }
                    
                    Button {
                        Task { await viewModel.loadVehicles() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .semibold))
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            } else if !viewModel.isLoading && viewModel.vehicles.isEmpty && viewModel.lastUpdate != nil {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Aucun véhicule en circulation pour le moment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        viewModel.selectedVehicleType != nil || viewModel.selectedLine != nil
    }
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            if !viewModel.vehicleTypeStats.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.vehicleTypeStats, id: \.type) { stat in
                            VehicleTypeChip(
                                type: stat.type,
                                count: stat.count,
                                isSelected: viewModel.selectedVehicleType == stat.type
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    if viewModel.selectedVehicleType == stat.type {
                                        viewModel.selectedVehicleType = nil
                                    } else {
                                        viewModel.selectedVehicleType = stat.type
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else {
                        Text("\(viewModel.filteredVehicles.count)")
                            .font(.system(size: 28, weight: .black))
                        Text(viewModel.vehicles.isEmpty ? "Aucun véhicule détecté" : "véhicules en circulation")
                            .font(.caption)
                            .foregroundStyle(viewModel.vehicles.isEmpty ? .orange : .secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        mapCameraPosition = .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
                                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                            )
                        )
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.blue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
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
            
            Image(systemName: vehicle.vehicleType.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            
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
            return .orange
        case .tram:
            return .blue
        case .bus:
            return .purple
        case .trolley:
            return .green
        case .funicular:
            return .teal
        }
    }
}

struct ClusterMarker: View {
    let cluster: VehicleCluster
    
    var body: some View {
        ZStack {
            Circle()
                .fill(clusterColor)
                .frame(width: 44, height: 44)
                .shadow(color: clusterColor.opacity(0.5), radius: 6, x: 0, y: 3)
            
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 36)
            
            Text("\(cluster.count)")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
        }
    }
    
    private var clusterColor: Color {
        switch cluster.dominantType {
        case .metro: return .orange
        case .tram: return .blue
        case .bus: return .purple
        case .trolley: return .green
        case .funicular: return .teal
        }
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
                        if !vehicle.destination.isEmpty {
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
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
                        Button {
                            viewModel.selectedLine = nil
                        } label: {
                            HStack {
                                Text("Toutes les lignes")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedLine == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        
                        ForEach(viewModel.availableLines, id: \.self) { line in
                            let lineType = viewModel.vehicleTypeForLine(line)
                            Button {
                                viewModel.selectedLine = line
                            } label: {
                                HStack {
                                    if let type = lineType {
                                        Image(systemName: type.icon)
                                            .foregroundStyle(typeColor(type))
                                            .frame(width: 24)
                                    }
                                    
                                    Text(line)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if viewModel.selectedLine == line {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        if let type = viewModel.selectedVehicleType {
                            Text("Lignes \(type.rawValue)")
                        } else {
                            Text("Lignes (triées par mode)")
                        }
                    }
                }
                
                Section {
                    Button("Réinitialiser les filtres", role: .destructive) {
                        viewModel.clearFilters()
                    }
                    .disabled(viewModel.selectedVehicleType == nil && viewModel.selectedLine == nil)
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
