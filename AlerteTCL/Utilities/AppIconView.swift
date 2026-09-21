import SwiftUI
import UIKit

/// L'icône de l'application, arrondie comme sur l'écran d'accueil. Lue dans le bundle : aucune copie
/// de l'image n'est rangée dans les assets. Utilisée par l'onglet Info et par l'écran d'intro.
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(named: "AppIcon") ?? Bundle.main.iconImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Color.appAccent)
                    .overlay(
                        Image(systemName: "tram.fill")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

extension Bundle {
    /// L'icône déclarée dans l'Info.plist, dans sa plus grande taille.
    func iconImage() -> UIImage? {
        guard
            let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let last = files.last
        else { return nil }
        return UIImage(named: last)
    }
}
