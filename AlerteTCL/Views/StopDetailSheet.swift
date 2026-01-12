import SwiftUI
import MapKit

struct StopDetailSheet: View {
    let stop: StopAnnotation
    @Environment(\.dismiss) private var dismiss
    
    init(stop: StopAnnotation) {
        self.stop = stop
        // Sauvegarder l'arrêt dans les récents pour la configuration du widget
        RecentItemsService.shared.saveRecentStop(id: stop.stop.stopId, name: stop.stop.name)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // En-tête avec nom de l'arrêt
                    stopHeader
                    
                    // Lignes desservies
                    if !stop.linesServed.isEmpty {
                        linesSection
                    }
                    
                    // Prochains passages
                    if !stop.passages.isEmpty {
                        passagesSection
                    } else {
                        noPassagesView
                    }
                }
                .padding()
            }
            .navigationTitle("Arrêt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var stopHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text(stop.stop.name)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("ID: \(stop.stop.stopId.components(separatedBy: ":").last ?? stop.stop.stopId)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lignes desservies")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stop.linesServed, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                    }
                }
            }
        }
    }
    
    private var passagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prochains passages")
                    .font(.headline)
                
                Spacer()
                
                Text("Temps réel")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
            }
            
            VStack(spacing: 0) {
                ForEach(Array(stop.passages.prefix(10).enumerated()), id: \.element.id) { index, passage in
                    PassageRow(passage: passage)
                    
                    if index < min(9, stop.passages.count - 1) {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private var noPassagesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Aucun passage prévu")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Aucun véhicule n'approche cet arrêt pour le moment")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct PassageRow: View {
    let passage: StopPassage
    
    var body: some View {
        HStack(spacing: 16) {
            // Icône du type de véhicule
            VStack {
                Image(systemName: passage.vehicleType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            
            // Ligne
            Text(passage.lineName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 40)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                )
            
            // Destination
            VStack(alignment: .leading, spacing: 2) {
                Text(passage.destination)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                if let distance = passage.distance {
                    Text("\(distance)m")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Temps et retard
            VStack(alignment: .trailing, spacing: 2) {
                Text(passage.arrivalFormatted)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                if passage.delay != 0 {
                    Text(passage.delayFormatted)
                        .font(.caption2)
                        .foregroundColor(passage.delay > 0 ? .orange : .green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
