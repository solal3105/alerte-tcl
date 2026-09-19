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

/// Marqueur d'une station sur la carte des parkings : un point à la couleur de disponibilité de loin,
/// le carré avec le nombre compté par le filtre courant au zoom des arrêts.
struct VelovMarker: View {
    let station: VelovStation
    let filter: VelovFilter
    let compact: Bool

    private var availability: AvailabilityColor { station.availabilityFor(filter: filter) }
    private var color: Color { Color(token: AppColors.shared.parkingAvailability(color: availability)) }

    var body: some View {
        if compact {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 1)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        } else {
            Image(uiImage: MarkerImageCache.velovMarker(
                count: Int(station.shownCount(filter: filter)),
                availability: availability,
                symbol: velovFilterSymbol(filter == .all ? .mechanical : filter)
            ))
        }
    }
}

/// Fiche d'une station Vélo'v : vélos et places disponibles, dernière mise à jour, itinéraire à pied.
struct VelovStationSheet: View {
    let station: VelovStation
    @Environment(\.dismiss) private var dismiss

    private var color: Color { Color(token: AppColors.shared.parkingAvailability(color: station.availability)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(color)
                            .padding(16)
                            .background(color.opacity(0.12), in: Circle())
                        Text(station.displayName)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        if !station.address.isEmpty {
                            Text(station.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    HStack(spacing: 10) {
                        stat(value: "\(station.mechanicalBikes)", caption: "classiques", color: color)
                        stat(value: "\(station.ebikes)", caption: "électriques", color: color)
                        stat(value: "\(station.stands)", caption: station.stands > 1 ? "places libres" : "place libre", color: .primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(station.bikesText)
                        if !station.standsText.isEmpty { Text(station.standsText) }
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            let text = station.updatedText(nowEpochMs: Int64(context.date.timeIntervalSince1970 * 1000))
                            if !text.isEmpty {
                                Text(text).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button(action: openWalkingDirections) {
                        Label("Itinéraire à pied dans Plans", systemImage: "figure.walk")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                }
                .padding(20)
            }
            .background(.ultraThinMaterial)
            .navigationTitle("Station Vélo'v")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func stat(value: String, caption: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func openWalkingDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: station.lat, longitude: station.lng)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = "Vélo'v \(station.displayName)"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
