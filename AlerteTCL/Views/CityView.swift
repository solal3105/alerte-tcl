import SwiftUI
import MapKit
import Shared

extension CityTile: Identifiable {
    public var id: String { name }
}

/// Onglet « Autour de moi » : un accueil à tuiles de verre posées sur une carte immobile (stationnement,
/// Vélo'v, chantiers, avec leurs chiffres en direct), puis la carte de la tuile choisie, poussée dans la
/// navigation : bouton de retour système et geste de balayage. En démo « velov… », la carte des
/// stations s'ouvre directement.
struct CityView: View {
    /// Lien vers un parking, une station Vélo'v ou un chantier : la carte concernée s'ouvre sans passer par l'accueil.
    @Binding var link: WidgetLink?
    @State private var selectedTile: CityTile?

    var body: some View {
        NavigationStack {
            CityChooserView { tile in selectedTile = tile }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $selectedTile) { tile in
                    content(for: tile)
                        .navigationTitle(tile.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .onAppear {
            #if DEBUG
            if DemoShowcase.current?.hasPrefix("velov") == true { selectedTile = .velov }
            #endif
            open(link)
        }
        .onChange(of: link) { _, link in open(link) }
    }

    /// La tuile qui correspond au lien ; la carte ouverte consomme ensuite le lien avec ses données.
    private func open(_ link: WidgetLink?) {
        let wanted: CityTile?
        switch link {
        case .parking: wanted = .parkingCar
        case .velov: wanted = .velov
        case .works: wanted = .travaux
        default: wanted = nil
        }
        if let wanted, selectedTile != wanted { selectedTile = wanted }
    }

    @ViewBuilder
    private func content(for tile: CityTile) -> some View {
        if let type = tile.parkingType.flatMap(ParkingType.init(shared:)) {
            ParkingMapView(parkingType: type, link: $link)
        } else {
            TravauxMapView(link: $link)
        }
    }
}

// MARK: - Accueil

/// La carte de la ville, immobile, sous un voile ; les tuiles de verre par-dessus.
private struct CityChooserView: View {
    let onChoose: (CityTile) -> Void

    @ObservedObject private var locationService = LocationService.shared

    private let tiles: [CityTile] = CityTile.companion.all
    private var parkingTiles: [CityTile] { tiles.filter { $0.parkingType != nil } }
    private var otherTiles: [CityTile] { tiles.filter { $0.parkingType == nil } }

    var body: some View {
        ZStack {
            MapBackdrop(center: locationService.currentLocation?.coordinate)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Autour de moi")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 6)
                    ForEach(Array(stride(from: 0, to: parkingTiles.count, by: 2)), id: \.self) { index in
                        HStack(alignment: .top, spacing: 14) {
                            tileCard(parkingTiles[index], wide: false)
                            if index + 1 < parkingTiles.count {
                                tileCard(parkingTiles[index + 1], wide: false)
                            }
                        }
                    }
                    ForEach(otherTiles) { tile in
                        tileCard(tile, wide: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
    }

    private func tileCard(_ tile: CityTile, wide: Bool) -> some View {
        CityTileCard(tile: tile, wide: wide) { onChoose(tile) }
    }
}

/// Carte sans interaction, centrée sur la position si elle est connue, sinon sur la place Bellecour.
private struct MapBackdrop: View {
    let center: CLLocationCoordinate2D?

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center ?? CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    var body: some View {
        ZStack {
            Map(initialPosition: .region(region), interactionModes: [])
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .mapControlVisibility(.hidden)
            // Voile qui s'épaissit vers le bas pour garder les textes lisibles.
            Rectangle()
                .fill(.background)
                .mask(LinearGradient(stops: [
                    .init(color: .black.opacity(0.45), location: 0),
                    .init(color: .black.opacity(0.90), location: 1),
                ], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
    }
}

private struct CityTileCard: View {
    let tile: CityTile
    let wide: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if wide {
                    HStack(spacing: 14) {
                        TileIcon(tile: tile)
                        texts
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        TileIcon(tile: tile)
                        texts
                    }
                    .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .glassSurface(RoundedRectangle(cornerRadius: 28))
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tile.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(tile.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
}

/// Pictogramme à l'accent sur un disque bleuté : une seule couleur pour tout l'accueil.
private struct TileIcon: View {
    let tile: CityTile

    var body: some View {
        Image(systemName: tile.icon)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(Color.appAccent)
            .frame(width: 52, height: 52)
            .background(Color.appAccent.opacity(0.12), in: Circle())
    }
}
