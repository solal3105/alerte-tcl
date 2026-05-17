import SwiftUI
import MapKit
import CoreLocation

/// Onglet "Mobilités douces" — carte des stations Vélo'v (et plus tard Dott, …).
struct SoftMobilityMapView: View {
    @StateObject private var viewModel = SoftMobilityViewModel()
    @ObservedObject private var locationService = LocationService.shared

    @State private var selectedStation: VelovStation?
    @State private var showSearch = false
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var hasSetInitialLocation = false
    @State private var isSatellite = false
    @State private var showRefreshInfo = false

    var body: some View {
        ZStack {
            mapContent

            VStack {
                filterBar
                Spacer()
            }

            overlayControls
        }
        .sheet(item: $selectedStation) { station in
            VelovStationDetailSheet(station: station)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSearch) {
            VelovStationSearchSheet(
                viewModel: viewModel,
                userLocation: locationService.currentLocation
            ) { station in
                showSearch = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        mapCameraPosition = .region(
                            MKCoordinateRegion(
                                center: station.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )
                        )
                    }
                    try? await Task.sleep(for: .milliseconds(400))
                    selectedStation = station
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .withInitialLocation(
            mapCameraPosition: $mapCameraPosition,
            hasSetInitialLocation: $hasSetInitialLocation
        )
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $mapCameraPosition) {
            ForEach(viewModel.velovStations) { station in
                Annotation(station.displayName, coordinate: station.coordinate) {
                    VelovStationMarker(
                        station: station,
                        count: viewModel.count(for: station, filter: viewModel.filter),
                        colorKind: viewModel.color(for: station, filter: viewModel.filter)
                    )
                    .onTapGesture { selectedStation = station }
                }
                .annotationTitles(.hidden)
            }

            if locationService.currentLocation != nil {
                UserAnnotation()
            }
        }
        .mapStyle(isSatellite ? .imagery(elevation: .realistic) : .standard(pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SoftMobilityViewModel.StationFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.filter = filter
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(viewModel.filter == filter ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                if viewModel.filter == filter {
                                    Capsule().fill(Color.green)
                                        .shadow(color: .green.opacity(0.35), radius: 4, x: 0, y: 2)
                                } else {
                                    Capsule().fill(.ultraThinMaterial)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
            }

            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Overlay controls

    private var overlayControls: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                liveIndicator
                Spacer()
                VStack(spacing: 10) {
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
                .padding(.trailing, 16)
            }
            .padding(.bottom, 16)
            .padding(.leading, 16)
        }
    }

    private var liveIndicator: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showRefreshInfo.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.error != nil ? .orange : .green)
                    .frame(width: 8, height: 8)

                Text(viewModel.error != nil ? "PAUSE" : "LIVE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(viewModel.error != nil ? .orange : .green)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else if let last = viewModel.lastUpdate {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let remaining = max(0, Int(viewModel.refreshInterval) - Int(ctx.date.timeIntervalSince(last)))
                        Text("\(remaining)s")
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
            refreshInfoPopover
                .frame(width: 280)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var refreshInfoPopover: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bicycle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vélo'v en direct")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(viewModel.openStationsCount) stations actives")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // Totaux réseau
            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text("\(viewModel.totalAvailableBikes)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                    Text("vélos dispo")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 3) {
                    Text("\(viewModel.totalAvailableStands)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                    Text("places libres")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            // Intervalle + dernière maj
            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text("\(Int(viewModel.refreshInterval))s")
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

            Divider().padding(.horizontal, 16)

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
    }
}

// MARK: - Marker

private struct VelovStationMarker: View {
    let station: VelovStation
    let count: Int
    let colorKind: SoftMobilityViewModel.MarkerColor

    var body: some View {
        ZStack {
            Circle()
                .fill(colorKind.color)
                .frame(width: 28, height: 28)
                .shadow(color: colorKind.color.opacity(0.4), radius: 4, x: 0, y: 2)

            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 28, height: 28)

            if colorKind == .closed {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Search sheet

struct VelovStationSearchSheet: View {
    @ObservedObject var viewModel: SoftMobilityViewModel
    let userLocation: CLLocation?
    let onSelect: (VelovStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var results: [VelovStation] {
        viewModel.searchStations(query: searchText, near: userLocation)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { station in
                    Button {
                        onSelect(station)
                    } label: {
                        VelovStationRow(station: station, userLocation: userLocation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Rechercher une station")
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Stations Vélo'v")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.fontWeight(.medium)
                }
            }
        }
    }
}

private struct VelovStationRow: View {
    let station: VelovStation
    let userLocation: CLLocation?

    private var distanceText: String? {
        guard let userLocation else { return nil }
        let stationLocation = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
        let meters = userLocation.distance(from: stationLocation)
        if meters < 1000 {
            return "\(Int(meters)) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }

    var body: some View {
        HStack(spacing: 12) {
            statusDot
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(station.availableBikes)", systemImage: "bicycle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Label("\(station.availableStands)", systemImage: "parkingsign")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    if station.availableElectricalBikes > 0 {
                        Label("\(station.availableElectricalBikes)", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer()

            if let d = distanceText {
                Text(d)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
    }

    private var dotColor: Color {
        guard station.status.isOperational else { return .gray }
        if station.availableBikes == 0 { return .red }
        if station.availableStands == 0 { return .blue }
        if station.availableBikes <= 2 { return .orange }
        return .green
    }
}

// MARK: - Detail sheet

struct VelovStationDetailSheet: View {
    let station: VelovStation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    capacityBar
                    bikeBreakdownCard
                    secondaryStats
                    if station.banking || station.bonus {
                        featuresCard
                    }
                    if let address = station.address, !address.isEmpty {
                        addressCard(address: address)
                    }
                    actionButtons
                    if let last = station.lastUpdate {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption2)
                            Text("Mis à jour ") + Text(last, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.fontWeight(.medium)
                }
            }
        }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(headerColor)
                    .frame(width: 64, height: 64)
                Image(systemName: "bicycle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: headerColor.opacity(0.35), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text("STATION #\(station.id)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(station.displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                statusPill
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 12)
    }

    private var headerColor: Color {
        guard station.status.isOperational else { return .gray }
        if station.availableBikes == 0 { return .red }
        if station.availableStands == 0 { return .blue }
        if station.availableBikes <= 2 || station.availableStands <= 2 { return .orange }
        return .green
    }

    private var statusPill: some View {
        let (color, label, icon): (Color, String, String) = {
            guard station.status.isOperational else { return (.gray, "Fermée", "xmark.circle.fill") }
            if station.availableBikes == 0 { return (.red, "Aucun vélo", "bicycle.slash") }
            if station.availableStands == 0 { return (.blue, "Station pleine", "parkingsign") }
            if station.availableBikes <= 2 || station.availableStands <= 2 { return (.orange, "Faible", "exclamationmark.triangle.fill") }
            return (.green, "Disponible", "checkmark.circle.fill")
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
    }

    // MARK: capacity bar (visual fill)

    private var capacityBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Occupation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Text("\(station.availableBikes) / \(station.totalCapacity)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let capacity = max(station.totalCapacity, 1)
                let mech = CGFloat(station.availableMechanicalBikes) / CGFloat(capacity) * totalWidth
                let elec = CGFloat(station.availableElectricalBikes) / CGFloat(capacity) * totalWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))

                    HStack(spacing: 0) {
                        Capsule()
                            .fill(Color.green)
                            .frame(width: max(0, mech))
                        Capsule()
                            .fill(Color.yellow)
                            .frame(width: max(0, elec))
                    }
                }
            }
            .frame(height: 10)

            HStack(spacing: 14) {
                legend(color: .green, label: "Mécaniques")
                legend(color: .yellow, label: "Électriques")
                legend(color: Color(.systemGray5), label: "Bornettes libres")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    // MARK: bike breakdown — big numbers

    private var bikeBreakdownCard: some View {
        HStack(spacing: 0) {
            bigStat(
                value: station.availableMechanicalBikes,
                label: "Mécaniques",
                icon: "bicycle",
                tint: .green
            )
            Divider().frame(height: 56)
            bigStat(
                value: station.availableElectricalBikes,
                label: "Électriques",
                icon: "bolt.fill",
                tint: .yellow
            )
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bigStat(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: secondary stats

    private var secondaryStats: some View {
        HStack(spacing: 0) {
            secondaryStat(value: station.availableStands, label: "Bornettes libres", icon: "parkingsign", tint: .blue)
            Divider().frame(height: 44)
            secondaryStat(value: station.totalCapacity, label: "Capacité totale", icon: "circle.grid.2x2", tint: .secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func secondaryStat(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: features

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if station.banking {
                Label("Paiement par carte bancaire", systemImage: "creditcard.fill")
                    .font(.subheadline)
            }
            if station.bonus {
                Label("Station bonus — +15 min à la restitution", systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func addressCard(address: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(address)
                    .font(.subheadline)
                if let commune = station.commune {
                    Text(commune)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: action buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                openInMaps(mode: .walking)
            } label: {
                Label("À pied", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                openInMaps(mode: .transit)
            } label: {
                Label("Itinéraire", systemImage: "tram.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private enum DirectionMode { case walking, transit }

    private func openInMaps(mode: DirectionMode) {
        let placemark = MKPlacemark(coordinate: station.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = station.displayName
        let key: String = (mode == .walking) ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeTransit
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: key])
    }
}

#Preview {
    SoftMobilityMapView()
}
