import SwiftUI

// MARK: - Verre des surfaces flottantes
//
// Tuiles, capsules et boutons de carte partagent le même verre : Liquid Glass dès iOS 26, un matériau
// translucide avec un liseré clair sur les versions précédentes.

extension View {
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
        }
    }
}

/// Taches de couleur floues derrière les surfaces en verre, pour que le verre ait quelque chose à laisser voir.
struct GlassBackdrop: View {
    let colors: [Color]

    private let placements: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-80, -40, 420), (160, 120, 380), (-60, 420, 360), (140, 620, 400), (20, 260, 300),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.background)
            ForEach(colors.indices, id: \.self) { index in
                let placement = placements[index % placements.count]
                Circle()
                    .fill(colors[index].opacity(0.55))
                    .frame(width: placement.size, height: placement.size)
                    .blur(radius: 60)
                    .offset(x: placement.x, y: placement.y)
            }
        }
        .ignoresSafeArea()
    }
}

/// Bouton rond des contrôles de carte (satellite, filtres, position), en verre.
struct MapGlassButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .glassSurface(Circle(), interactive: true)
    }
}
