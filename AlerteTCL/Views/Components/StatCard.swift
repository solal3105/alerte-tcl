import SwiftUI

struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    HStack {
        StatCard(value: "15", label: "Alertes actives", color: .orange, icon: "exclamationmark.triangle.fill")
        StatCard(value: "8", label: "Lignes suivies", color: .blue, icon: "star.fill")
    }
    .padding()
}
