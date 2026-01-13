import SwiftUI

struct LineRow: View {
    let line: TransportLine
    let alertCount: Int
    let isSubscribed: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TransportLineBadge(line: line)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(line.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if alertCount > 0 {
                    Text("\(alertCount) alerte\(alertCount > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onToggle()
                }
            } label: {
                Image(systemName: isSubscribed ? "bell.fill" : "bell")
                    .font(.title3)
                    .foregroundStyle(isSubscribed ? line.mode.color : .secondary)
                    .symbolEffect(.bounce, value: isSubscribed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSubscribed ? "Se désabonner" : "S'abonner")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct TransportLineBadge: View {
    let line: TransportLine
    
    private var lineName: String {
        line.ligneCli.isEmpty ? line.ligneCom : line.ligneCli
    }
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: lineName)
    }
    
    private var textColor: Color {
        LineColorHelper.textColor(for: lineName)
    }
    
    private var needsBorder: Bool {
        LineColorHelper.needsBorder(for: lineName)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
                )
            
            Text(lineName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(textColor)
        }
    }
}

#Preview {
    List {
        LineRow(
            line: TransportLine(ligneCom: "MA", ligneCli: "A", mode: .metro),
            alertCount: 2,
            isSubscribed: true
        ) {}
        
        LineRow(
            line: TransportLine(ligneCom: "T1", ligneCli: "T1", mode: .tramway),
            alertCount: 0,
            isSubscribed: false
        ) {}
        
        LineRow(
            line: TransportLine(ligneCom: "C3", ligneCli: "C3", mode: .bus),
            alertCount: 1,
            isSubscribed: true
        ) {}
    }
}
