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
/// est prévu (une fourchette, « 3–8 ») quand le curseur d'heure a bougé.
struct VelovMapMarker: Identifiable {
    let station: VelovStation
    /// Le texte du carré, tel quel : un nombre, ou la fourchette prévue mise en forme par le module partagé.
    let label: String
    let availability: AvailabilityColor
    /// Le filtre pour lequel le texte a été établi : le pictogramme du marqueur le suit.
    let filter: VelovFilter

    var id: Int32 { station.id }

    /// L'état réel de la station.
    init(station: VelovStation, filter: VelovFilter) {
        self.station = station
        self.label = "\(station.shownCount(filter: filter))"
        self.availability = station.availabilityFor(filter: filter)
        self.filter = filter
    }

    /// Une prévision calculée pour `filter`.
    init(forecast: VelovForecastMarker, filter: VelovFilter) {
        self.station = forecast.station
        self.label = forecast.label
        self.availability = forecast.availability
        self.filter = filter
    }
}

/// Marqueur d'une station sur la carte des parkings : un point à la couleur de disponibilité de loin,
/// le carré avec le texte du marqueur au zoom des arrêts. Comparable : quand le curseur d'heure
/// glisse, seuls les marqueurs dont le texte ou la couleur change sont redessinés.
struct VelovMarker: View, Equatable {
    let marker: VelovMapMarker
    let compact: Bool
    /// Agrandissement du carré, net à toute taille : 1 sur la carte, davantage dans l'intro.
    var scale: CGFloat = 1

    static func == (lhs: VelovMarker, rhs: VelovMarker) -> Bool {
        lhs.compact == rhs.compact && lhs.scale == rhs.scale && lhs.marker.id == rhs.marker.id && lhs.marker.label == rhs.marker.label
            && lhs.marker.availability == rhs.marker.availability && lhs.marker.filter == rhs.marker.filter
    }

    /// Deux images pré-rendues et gardées (`MarkerImageCache`) : ni ombre ni forme recalculée par marqueur.
    var body: some View {
        Image(uiImage: compact
            ? MarkerImageCache.velovDot(availability: marker.availability)
            : MarkerImageCache.velovMarker(
                label: marker.label,
                availability: marker.availability,
                symbol: velovFilterSymbol(marker.filter == .all ? .mechanical : marker.filter),
                scale: scale
            )
        )
    }
}

/// Fiche d'une station Vélo'v : son état réel, ce qui y est prévu dans les 24 heures, l'itinéraire à
/// pied. Une voisine « plus sûre » s'ouvre à la suite, avec le retour du système.
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
/// l'échéance part de celle de la carte, puis n'appartient qu'au bloc de prévision de cette page.
private struct VelovStationPage: View {
    @ObservedObject var viewModel: ParkingViewModel
    let close: () -> Void
    /// L'échéance à l'ouverture de la page.
    let step: Int32
    /// La station telle que le dernier relevé la donne : la page suit les rafraîchissements de la carte.
    @State private var station: VelovStation
    @State private var forecast: VelovForecastSheet?
    /// Vrai tant que la prévision n'a pas répondu : sa place est réservée, la fiche ne saute pas.
    @State private var isForecastPending = true

    init(station: VelovStation, viewModel: ParkingViewModel, step: Int32, close: @escaping () -> Void) {
        self.viewModel = viewModel
        self.close = close
        self.step = step
        _station = State(initialValue: station)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(station.displayName)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                VelovNowTile(station: station)
                if forecast != nil || (isForecastPending && viewModel.velovForecastAvailable) {
                    VelovForecastSection(forecast: forecast, viewModel: viewModel, step: step, close: close)
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

    private func openWalkingDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: station.lat, longitude: station.lng)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = "Vélo'v \(station.displayName)"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// L'état réel de la station, en tête de fiche : vélos classiques, vélos électriques et places libres
/// côte à côte, chacun en nombre et en mot sous le pictogramme de son filtre, ou « Station fermée ».
struct VelovNowTile: View {
    let station: VelovStation
    /// Le compte mis en avant (l'intro, page des types) : sa case s'allume à l'accent, et l'éclairage
    /// glisse d'une case à l'autre. Aucun sur la fiche.
    var highlighted: VelovFilter? = nil
    @Namespace private var highlight

    var body: some View {
        Group {
            if station.open {
                HStack(spacing: 8) {
                    ForEach(VelovFilter.companion.detailed) { filter in
                        let count = station.shownCount(filter: filter)
                        let lit = filter == highlighted
                        VStack(spacing: 2) {
                            Image(systemName: velovFilterSymbol(filter))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(lit ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                            Text(verbatim: "\(count)")
                                .font(.title2.bold())
                                .monospacedDigit()
                            Text(VelovTexts.shared.unit(filter: filter, count: count))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .background {
                            if lit {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.appAccent.opacity(0.14))
                                    .padding(-6)
                                    .matchedGeometryEffect(id: 0, in: highlight)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                Text(station.stateText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .velovForecastCard()
    }
}

/// Le bloc de prévision d'une page et ses voisines « plus sûres ». Il garde seul l'échéance du curseur :
/// en glissant, lui seul se redessine, pas l'en-tête ni l'état du moment.
private struct VelovForecastSection: View {
    let forecast: VelovForecastSheet?
    @ObservedObject var viewModel: ParkingViewModel
    let close: () -> Void
    @State private var step: Int32

    init(forecast: VelovForecastSheet?, viewModel: ParkingViewModel, step: Int32, close: @escaping () -> Void) {
        self.forecast = forecast
        self.viewModel = viewModel
        self.close = close
        _step = State(initialValue: step)
    }

    var body: some View {
        let filter = viewModel.velovFilter
        let readout = forecast?.readout(filter: filter, step: step)
        VStack(spacing: 14) {
            VelovForecastCard(
                panel: forecast?.panel(filter: filter),
                readout: readout,
                filter: filter,
                onSelectFilter: { viewModel.selectVelovFilter($0) },
                onSelectStep: { step = $0 }
            )
            if let neighbours = readout?.saferNearby, !neighbours.isEmpty {
                saferNearby(neighbours)
            }
        }
    }

    /// « Plus sûr à côté » : les voisines où la chance est meilleure à la même échéance.
    private func saferNearby(_ neighbours: [VelovForecastNeighbour]) -> some View {
        VelovSaferNearbyCard(neighbours: neighbours) { neighbour, row in
            NavigationLink {
                VelovStationPage(station: neighbour.station, viewModel: viewModel, step: step, close: close)
            } label: {
                row
            }
            .buttonStyle(.plain)
        }
    }
}

/// La carte « Plus sûr à côté » : son titre, puis une rangée par voisine, que l'appelant enveloppe
/// (un lien vers la voisine sur la fiche, rien dans l'intro).
struct VelovSaferNearbyCard<Entry: View>: View {
    let neighbours: [VelovForecastNeighbour]
    private let entry: (VelovForecastNeighbour, VelovNeighbourRow) -> Entry

    init(neighbours: [VelovForecastNeighbour], @ViewBuilder entry: @escaping (VelovForecastNeighbour, VelovNeighbourRow) -> Entry) {
        self.neighbours = neighbours
        self.entry = entry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(VelovForecastSheet.companion.SAFER_NEARBY_TITLE)
                .font(.headline)
            ForEach(Array(neighbours.enumerated()), id: \.element.station.id) { rank, neighbour in
                if rank > 0 { Divider() }
                entry(neighbour, VelovNeighbourRow(neighbour: neighbour))
            }
        }
        .velovForecastCard()
    }
}

/// Une voisine plus sûre : son nom, le temps à pied et ce qui y est prévu, sa chance à droite.
struct VelovNeighbourRow: View {
    let neighbour: VelovForecastNeighbour

    var body: some View {
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
}
