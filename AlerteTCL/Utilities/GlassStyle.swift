import SwiftUI

// MARK: - Verre des surfaces flottantes
//
// Tuiles, capsules et boutons de carte partagent le même verre : Liquid Glass dès iOS 26, un matériau
// translucide avec un liseré clair sur les versions précédentes.

extension View {
    /// Surface en verre, teintée ou non ; jamais sur un bouton rond (voir `MapGlassButton`).
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(tint ?? .clear, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
        }
    }
}

/// Bouton rond des contrôles de carte (trafic, filtres, position) : deux couleurs seulement,
/// l'accent sur verre au repos, disque d'accent plein avec pictogramme blanc quand il est actif.
/// Sur iOS 26, ce sont les styles de bouton en verre du système, qui répondent au toucher sans délai.
struct MapGlassButton: View {
    let systemImage: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Group {
                if active {
                    Button(action: action) { icon(size: 28) }.buttonStyle(.glassProminent)
                } else {
                    Button(action: action) { icon(size: 28) }.buttonStyle(.glass)
                }
            }
            .buttonBorderShape(.circle)
            .tint(Color.appAccent)
        } else {
            Button(action: action) {
                icon(size: 50)
                    .foregroundStyle(active ? Color.white : Color.appAccent)
                    .background(active ? Color.appAccent : Color.clear, in: Circle())
            }
            .buttonStyle(.plain)
            .glassSurface(Circle())
        }
    }

    private func icon(size: CGFloat) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .medium))
            .frame(width: size, height: size)
    }
}
