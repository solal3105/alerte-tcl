import SwiftUI

// MARK: - Verre des surfaces flottantes
//
// Tuiles, capsules, panneaux et boutons de carte partagent le même verre, dépoli pour rester lisible
// sur n'importe quel fond de carte, en clair comme en sombre : un voile du fond des barres de carte
// (`appMapChrome`) et un liseré net par-dessus le verre du système (Liquid Glass dès iOS 26, matériau
// translucide avant). Le verre seul d'iOS 27 laissait trop passer la carte.

/// Le dépoli commun aux surfaces et aux boutons de verre.
private enum GlassFrost {
    /// Le voile posé sur le verre : assez couvrant pour que le texte ne se lise plus sur la carte.
    static let fill = Color.appMapChrome.opacity(0.72)
    /// Le liseré qui détache la surface de la carte.
    static let edge = Color.appNeutralBorder.opacity(0.85)
}

extension View {
    /// Surface en verre dépoli ; jamais sur un bouton rond (voir `MapGlassButton`).
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S) -> some View {
        let frosted = self
            .background(GlassFrost.fill, in: shape)
            .overlay(shape.strokeBorder(GlassFrost.edge, lineWidth: 1))
        if #available(iOS 26, *) {
            frosted.glassEffect(.regular, in: shape)
        } else {
            frosted
                .background(.ultraThinMaterial, in: shape)
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
        }
    }
}

/// Bouton rond des contrôles de carte (trafic, filtres, position) : deux couleurs seulement,
/// l'accent sur verre dépoli au repos, disque d'accent plein avec pictogramme blanc quand il est actif.
/// Sur iOS 26, c'est le style de bouton en verre plein du système, teinté du dépoli au repos, qui
/// répond au toucher sans délai.
struct MapGlassButton: View {
    let systemImage: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                icon(size: 34).foregroundStyle(active ? Color.white : Color.appAccent)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(active ? Color.appAccent : Color.appMapChrome)
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
            .font(.system(size: 22, weight: .medium))
            .frame(width: size, height: size)
    }
}

// MARK: - Haut des cartes « Autour de moi »

/// Ce qui se pose en haut d'une carte, sous la barre de navigation (la barre de filtres Vélo'v, ou
/// rien) : le tout sur un dégradé qui part du fond des barres (`appMapChrome`) sous la barre d'état et
/// s'efface sur la carte, pour que le bouton de retour, le titre et les filtres se lisent sur
/// n'importe quel fond. Il ne capte aucun toucher : la carte reste manipulable dessous.
struct MapTopBar<Content: View>: View {
    /// Hauteur sur laquelle le dégradé s'efface, sous le contenu.
    private static var fade: CGFloat { 36 }

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            Color.clear
                .frame(height: Self.fade)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                stops: [
                    .init(color: .appMapChrome, location: 0),
                    .init(color: .appMapChrome.opacity(0.85), location: 0.55),
                    .init(color: .appMapChrome.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }
}
