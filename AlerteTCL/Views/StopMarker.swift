import SwiftUI

struct StopMarker: View {
    let stop: StopAnnotation
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                
                Image(systemName: "bus.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Afficher les lignes au lieu du temps
            if !stop.linesServed.isEmpty {
                HStack(spacing: 2) {
                    ForEach(stop.linesServed.prefix(3), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue)
                            )
                    }
                    
                    if stop.linesServed.count > 3 {
                        Text("+\(stop.linesServed.count - 3)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                            )
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
    }
}
