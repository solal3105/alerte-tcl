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
