import SwiftUI
import Shared

extension CityTile: Identifiable {
    public var id: String { name }
}

/// Onglet Ville : un accueil à tuiles (stationnement, Vélo'v, chantiers), puis la carte de la tuile
/// choisie sous une capsule de retour. En démo « velov… », la carte des stations s'ouvre directement.
struct CityView: View {
    @Binding var selectedParkingId: String?
    @State private var selectedTile: CityTile?

    var body: some View {
        ZStack {
            if let tile = selectedTile {
                content(for: tile)
                VStack {
                    CityHeader(tile: tile) { choose(nil) }
                    Spacer()
                }
            } else {
                CityChooserView { tile in choose(tile) }
            }
        }
        .onAppear {
            #if DEBUG
            if DemoShowcase.current?.hasPrefix("velov") == true { selectedTile = .velov }
            #endif
        }
        .onChange(of: selectedParkingId) { _, id in
            // Lien vers un parking : la carte des parkings voiture s'ouvre sans passer par l'accueil.
            if id != nil, selectedTile?.parkingType != Shared.ParkingType.car { selectedTile = .parkingCar }
        }
    }

    private func choose(_ tile: CityTile?) {
        withAnimation(.easeInOut(duration: 0.25)) { selectedTile = tile }
    }

    @ViewBuilder
    private func content(for tile: CityTile) -> some View {
        if let type = tile.parkingType.flatMap(ParkingType.init(shared:)) {
            ParkingMapView(parkingType: type, selectedParkingId: $selectedParkingId)
        } else {
            TravauxMapView()
        }
    }
}

// MARK: - Accueil

/// Une tuile en verre par entrée, les chantiers en pleine largeur, sur des taches de couleur floues.
private struct CityChooserView: View {
    let onChoose: (CityTile) -> Void

    private let tiles: [CityTile] = CityTile.companion.all
    private var parkingTiles: [CityTile] { tiles.filter { $0.parkingType != nil } }
    private var otherTiles: [CityTile] { tiles.filter { $0.parkingType == nil } }

    var body: some View {
        ZStack {
            GlassBackdrop(colors: tiles.map(\.color))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ville")
                        .font(.largeTitle.bold())
                    Text("Choisissez ce que la carte doit afficher.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    ForEach(Array(stride(from: 0, to: parkingTiles.count, by: 2)), id: \.self) { index in
                        HStack(alignment: .top, spacing: 14) {
                            CityTileCard(tile: parkingTiles[index], wide: false) { onChoose(parkingTiles[index]) }
                            if index + 1 < parkingTiles.count {
                                CityTileCard(tile: parkingTiles[index + 1], wide: false) { onChoose(parkingTiles[index + 1]) }
                            }
                        }
                    }
                    ForEach(otherTiles) { tile in
                        CityTileCard(tile: tile, wide: true) { onChoose(tile) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
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
                        VStack(alignment: .leading, spacing: 2) {
                            titleText
                            subtitleText
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        TileIcon(tile: tile)
                        titleText
                        subtitleText
                    }
                    .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassSurface(RoundedRectangle(cornerRadius: 26), interactive: true)
    }

    private var titleText: some View {
        Text(tile.title)
            .font(.headline)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
    }

    private var subtitleText: some View {
        Text(tile.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
    }
}

private struct TileIcon: View {
    let tile: CityTile
    var size: CGFloat = 46
    var iconSize: CGFloat = 22

    var body: some View {
        Image(systemName: tile.icon)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(tile.color)
            .frame(width: size, height: size)
            .glassSurface(Circle())
    }
}

// MARK: - Capsule de retour

/// Capsule en verre en haut de la carte : la tuile affichée, un toucher ramène à l'accueil.
private struct CityHeader: View {
    let tile: CityTile
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TileIcon(tile: tile, size: 28, iconSize: 13)
                    Text(tile.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .glassSurface(Capsule(), interactive: true)
            .accessibilityLabel("Retour à l'accueil de l'onglet Ville")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
