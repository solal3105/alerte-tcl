import SwiftUI

/// Traduction des erreurs serveur brutes en message compréhensible.
///
/// Source unique : le texte était recopié à l'identique dans chaque vue carte.
enum ServerErrorMessage {
    /// Vrai entre 22 h et 6 h : Grand Lyon coupe ses serveurs la nuit,
    /// une erreur à ces heures n'est pas une panne.
    static var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 22 || hour < 6
    }

    static func friendly(for error: String) -> String {
        if error.contains("504") || error.contains("Timeout") || error.contains("timeout") || error.contains("timed out") {
            return "Le serveur Grand Lyon prend son temps... Réessayez dans quelques instants."
        } else if error.contains("500") || error.contains("502") || error.contains("503") {
            return "Le serveur Grand Lyon est en maintenance. Revenez bientôt !"
        } else if error.contains("connection") || error.contains("network") || error.contains("Network") {
            return "Vérifiez votre connexion internet."
        }
        return "Une erreur inattendue s'est produite. Réessayez dans quelques instants."
    }
}

/// Panneau d'erreur affiché par-dessus une carte, avec bouton de nouvelle tentative.
struct ServerErrorOverlay: View {
    let error: String
    let onRetry: () -> Void

    private var isNight: Bool { ServerErrorMessage.isNightTime }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isNight ? "moon.zzz.fill" : "cloud.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(isNight ? Color.indigo : Color.appWarning)

            Text(isNight ? "Les serveurs se reposent" : "Données temporairement indisponibles")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(isNight
                 ? "Grand Lyon coupe ses serveurs la nuit. Revenez après 6h !"
                 : ServerErrorMessage.friendly(for: error))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Réessayer", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        .padding(20)
    }
}
