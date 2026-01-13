import SwiftUI
import MapKit

// MARK: - Transit Stop Marker

struct TransitStopMarker: View {
    let stop: TransitStop
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Chip avec prochain passage
            if let next = stop.nextPassage {
                let bgColor = LineColorHelper.backgroundColor(for: next.ligne)
                let textColor = LineColorHelper.textColor(for: next.ligne)
                let needsBorder = LineColorHelper.needsBorder(for: next.ligne)
                
                HStack(spacing: 4) {
                    Text(next.ligne)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(textColor)
                    
                    Text(next.shortDelay)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
                )
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
            
            // Point de l'arrêt
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 6, height: 6)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Transit Stop Detail Sheet

struct TransitStopDetailSheet: View {
    let stop: TransitStop
    @Environment(\.dismiss) private var dismiss
    @State private var passages: [Passage] = []
    @State private var isLoading = false
    
    private var passagesByLine: [String: [Passage]] {
        Dictionary(grouping: stop.passages) { $0.ligne }
    }
    
    private var sortedLines: [String] {
        passagesByLine.keys.sorted { line1, line2 in
            let mode1 = TransportMode.detectFromLine(line1)
            let mode2 = TransportMode.detectFromLine(line2)
            if mode1.sortOrder != mode2.sortOrder {
                return mode1.sortOrder < mode2.sortOrder
            }
            return line1 < line2
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerSection
                    
                    // Passages par ligne
                    if stop.passages.isEmpty {
                        emptyState
                    } else {
                        passagesSection
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icône
            Image(systemName: "tram.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Nom de l'arrêt
            Text(stop.nom)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Commune
            Text(stop.commune)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Lignes desservies
            if !stop.lines.isEmpty {
                HStack(spacing: 6) {
                    ForEach(stop.lines.prefix(6), id: \.self) { line in
                        LineBadge(line: line)
                    }
                    if stop.lines.count > 6 {
                        Text("+\(stop.lines.count - 6)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Accessibilité PMR
            if stop.pmr {
                HStack(spacing: 4) {
                    Image(systemName: "figure.roll")
                        .foregroundStyle(.blue)
                    Text("Accessible PMR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var passagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Prochains passages", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            ForEach(sortedLines, id: \.self) { line in
                if let linePassages = passagesByLine[line] {
                    LinePassagesCard(line: line, passages: linePassages)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Aucun passage prévu")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Les horaires seront affichés quand des véhicules seront en approche")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Line Badge (réutilisable)

struct LineBadge: View {
    let line: String
    var size: CGFloat = 11
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: line)
    }
    
    private var textColor: Color {
        LineColorHelper.textColor(for: line)
    }
    
    private var needsBorder: Bool {
        LineColorHelper.needsBorder(for: line)
    }
    
    var body: some View {
        Text(line)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
            )
    }
}

// MARK: - Line Passages Card

struct LinePassagesCard: View {
    let line: String
    let passages: [Passage]
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: line)
    }
    
    private var direction: String {
        passages.first?.direction ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ligne header
            HStack {
                LineBadge(line: line, size: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Direction")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(direction)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Liste des passages
            HStack(spacing: 8) {
                ForEach(passages.prefix(4)) { passage in
                    PassageChip(passage: passage, color: bgColor)
                }
            }
        }
        .padding(16)
        .background(bgColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Passage Chip

struct PassageChip: View {
    let passage: Passage
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(passage.delaipassage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            
            if passage.isRealTime {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            } else {
                Text(passage.formattedTime)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    TransitStopDetailSheet(stop: TransitStop(
        id: 1,
        nom: "Bellecour",
        commune: "Lyon 2e",
        adresse: "Place Bellecour",
        coordinate: CLLocationCoordinate2D(latitude: 45.757, longitude: 4.832),
        desserte: "MA:A,MA:R,MD:A,MD:R,T1:A,T1:R",
        pmr: true,
        passages: [
            Passage(stopId: 1, ligne: "MA", direction: "Vaulx-en-Velin", delaipassage: "2 min", heurepassage: "2026-01-14 10:30:00", type: "R"),
            Passage(stopId: 1, ligne: "MA", direction: "Vaulx-en-Velin", delaipassage: "7 min", heurepassage: "2026-01-14 10:35:00", type: "T"),
            Passage(stopId: 1, ligne: "T1", direction: "IUT Feyssine", delaipassage: "3 min", heurepassage: "2026-01-14 10:31:00", type: "R")
        ]
    ))
}
