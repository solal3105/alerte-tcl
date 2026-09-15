import SwiftUI
import MapKit
import Shared

extension VelovStation: Identifiable {}

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

                    HStack(spacing: 12) {
                        stat(value: "\(station.bikes)", caption: station.bikes > 1 ? "vélos disponibles" : "vélo disponible", color: color)
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
                .font(.system(size: 34, weight: .bold, design: .rounded))
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
