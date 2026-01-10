import SwiftUI

struct AlertCard: View {
    let alert: TCLAlert
    @State private var isExpanded = false
    
    private var severityColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .disruption: return .orange
        case .major: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            
            Text(alert.titre)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if isExpanded {
                expandedContent
            }
            
            footer
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: severityColor.opacity(0.15), radius: 12, x: 0, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(severityColor.opacity(0.3), lineWidth: 1.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
        }
        .scaleEffect(isExpanded ? 1.0 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(alert.mode.color.gradient)
                    .frame(width: 36, height: 36)
                
                Image(systemName: alert.mode.icon)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            Text(alert.ligneCli.isEmpty ? alert.ligneCom : alert.ligneCli)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(alert.mode.color)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: alert.severity.icon)
                    .font(.caption)
                Text(alert.severity.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(severityColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(severityColor.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            
            Text(alert.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if !alert.cause.isEmpty {
                Label(alert.cause, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var footer: some View {
        HStack {
            if let debut = alert.debut {
                Label(formatDate(debut), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            AlertCard(alert: TCLAlert(
                id: "1",
                type: "Perturbation majeure",
                cause: "Incident technique",
                debut: Date(),
                fin: Date().addingTimeInterval(86400),
                mode: .metro,
                ligneCom: "MD",
                ligneCli: "D",
                titre: "Ligne D interrompue entre Gare de Vaise et Gorge de Loup",
                message: "Suite à un incident technique, la ligne D est interrompue. Des bus relais sont mis en place. Veuillez prévoir un temps de trajet supplémentaire."
            ))
            
            AlertCard(alert: TCLAlert(
                id: "2",
                type: "Information",
                cause: "Événement",
                debut: Date(),
                fin: nil,
                mode: .tramway,
                ligneCom: "T1",
                ligneCli: "T1",
                titre: "Fréquence renforcée ce soir",
                message: "En raison du match OL, la fréquence est renforcée sur la ligne T1 entre 18h et minuit."
            ))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
