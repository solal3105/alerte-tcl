import SwiftUI
import MapKit
import Shared

extension VelovStation: Identifiable {}
extension VelovFilter: Identifiable {
    public var id: String { name }
}

/// Pictogramme d'un filtre : un cycliste pour tous les vélos, un vélo pour les classiques, un éclair
/// pour les électriques, un P pour les places libres.
func velovFilterSymbol(_ filter: VelovFilter) -> String {
    if filter == .electric { return "bolt.fill" }
    if filter == .stands { return "parkingsign" }
    return filter == .mechanical ? "bicycle" : "figure.outdoor.cycle"
}

/// Barre posée en haut de la carte Vélo'v : elle choisit ce que chaque station affiche, tous ses vélos,
/// ses vélos classiques, ses vélos électriques ou ses places libres.
struct VelovFilterBar: View {
    let selected: VelovFilter
    let onSelect: (VelovFilter) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(VelovFilter.companion.ordered) { filter in
                let active = filter == selected
                Button {
                    onSelect(filter)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: velovFilterSymbol(filter))
                            .font(.system(size: 16, weight: .medium))
                        Text(filter.title)
                            .font(.caption2.weight(active ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(active ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(active ? Color.appAccent : Color.clear, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(filter.caption)
            }
        }
        .padding(4)
        .glassSurface(RoundedRectangle(cornerRadius: 24))
    }
}

/// Ce que le marqueur d'une station affiche sur la carte : son état réel à « Maintenant », ce qui y
/// est prévu quand le curseur d'heure a bougé.
struct VelovMapMarker: Identifiable {
    let station: VelovStation
    let count: Int
    let availability: AvailabilityColor
    /// Le filtre pour lequel le nombre a été compté : le pictogramme du marqueur le suit.
    let filter: VelovFilter

    var id: Int32 { station.id }

    /// L'état réel de la station.
    init(station: VelovStation, filter: VelovFilter) {
        self.station = station
        self.count = Int(station.shownCount(filter: filter))
        self.availability = station.availabilityFor(filter: filter)
        self.filter = filter
    }

    /// Une prévision calculée pour `filter`.
    init(forecast: VelovForecastMarker, filter: VelovFilter) {
        self.station = forecast.station
        self.count = Int(forecast.count)
        self.availability = forecast.availability
        self.filter = filter
    }
}

/// Marqueur d'une station sur la carte des parkings : un point à la couleur de disponibilité de loin,
/// le carré avec le nombre compté par le filtre au zoom des arrêts.
struct VelovMarker: View {
    let marker: VelovMapMarker
    let compact: Bool

    private var color: Color { Color(token: AppColors.shared.parkingAvailability(color: marker.availability)) }

    var body: some View {
        if compact {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 1)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        } else {
            Image(uiImage: MarkerImageCache.velovMarker(
                count: marker.count,
                availability: marker.availability,
                symbol: velovFilterSymbol(marker.filter == .all ? .mechanical : marker.filter)
            ))
        }
    }
}

/// Fiche d'une station Vélo'v : son état réel en une ligne, ce qui y est prévu dans les 24 heures,
/// l'itinéraire à pied. Une voisine « plus sûre » s'ouvre à la suite, avec le retour du système.
struct VelovStationSheet: View {
    let station: VelovStation
    @ObservedObject var viewModel: ParkingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VelovStationPage(station: station, viewModel: viewModel, step: viewModel.velovForecastStep) { dismiss() }
        }
    }
}

/// Une station dans la fiche. Le filtre est celui de la carte (le changer ici le change là-bas) ;
/// l'échéance part de celle de la carte, puis n'appartient qu'à cette page.
private struct VelovStationPage: View {
    @ObservedObject var viewModel: ParkingViewModel
    let close: () -> Void
    /// La station telle que le dernier relevé la donne : la page suit les rafraîchissements de la carte.
    @State private var station: VelovStation
    @State private var step: Int32
    @State private var forecast: VelovForecastSheet?
    /// Vrai tant que la prévision n'a pas répondu : sa place est réservée, la fiche ne saute pas.
    @State private var isForecastPending = true

    init(station: VelovStation, viewModel: ParkingViewModel, step: Int32, close: @escaping () -> Void) {
        self.viewModel = viewModel
        self.close = close
        _station = State(initialValue: station)
        _step = State(initialValue: step)
    }

    var body: some View {
        let readout = forecast?.readout(filter: viewModel.velovFilter, step: step)
        ScrollView {
            VStack(spacing: 14) {
                header
                if forecast != nil || (isForecastPending && viewModel.velovForecastAvailable) {
                    VelovForecastCard(
                        panel: forecast?.panel(filter: viewModel.velovFilter),
                        readout: readout,
                        filter: viewModel.velovFilter,
                        onSelectFilter: { viewModel.selectVelovFilter($0) },
                        onSelectStep: { step = $0 }
                    )
                }
                if let neighbours = readout?.saferNearby, !neighbours.isEmpty {
                    saferNearby(neighbours)
                }
                Button(action: openWalkingDirections) {
                    Label("Itinéraire à pied", systemImage: "figure.walk")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        .navigationTitle("Station Vélo'v")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer", action: close).fontWeight(.semibold)
            }
        }
        // À chaque relevé des stations : même échéance, nouvelle heure de départ, comme sur la carte.
        // La prévision affichée reste en place jusqu'à ce que la nouvelle arrive.
        .task(id: viewModel.velovOriginEpochMs) {
            let current = viewModel.velovStation(id: station.id) ?? station
            station = current
            let sheet = await viewModel.velovForecastSheet(for: current)
            guard !Task.isCancelled else { return }
            forecast = sheet
            isForecastPending = false
        }
    }

    /// Le nom de la station et son état réel en une ligne.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(station.displayName)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(station.stateText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// « Plus sûr à côté » : les voisines où la chance est meilleure à la même échéance.
    private func saferNearby(_ neighbours: [VelovForecastNeighbour]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(VelovForecastSheet.companion.SAFER_NEARBY_TITLE)
                .font(.headline)
            ForEach(Array(neighbours.enumerated()), id: \.element.station.id) { rank, neighbour in
                if rank > 0 { Divider() }
                NavigationLink {
                    VelovStationPage(station: neighbour.station, viewModel: viewModel, step: step, close: close)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(neighbour.station.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(neighbour.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(neighbour.chance.text)
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(neighbour.chance.level.color)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .velovForecastCard()
    }

    private func openWalkingDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: station.lat, longitude: station.lng)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = "Vélo'v \(station.displayName)"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
