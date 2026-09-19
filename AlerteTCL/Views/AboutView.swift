import SwiftUI

/// Onglet Info : Solal Gendrin d'abord, puis l'application, Open Projets, l'Open Data du Grand Lyon,
/// les sources et les liens. Toutes les couleurs viennent des jetons partagés.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    appCard
                    openProjetsCard
                    openDataTribute
                    sourcesCard
                    linksFooter
                    versionFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: Solal Gendrin

    private var heroSection: some View {
        VStack(spacing: 18) {
            Text("SG")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 104, height: 104)
                .background(
                    LinearGradient(colors: [Color.appSuccess, Color.appSuccess.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: Color.appSuccess.opacity(0.35), radius: 18, x: 0, y: 8)

            VStack(spacing: 8) {
                Text("Solal Gendrin")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Conseiller métropolitain écologiste")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appSuccess)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.appSuccess.opacity(0.12), in: Capsule())
            }

            Text("Élu écologiste à la Métropole de Lyon, je développe Lyon Pocket pour rendre les transports en commun, le vélo et le stationnement plus simples à utiliser au quotidien.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Link(destination: URL.trusted("https://www.linkedin.com/in/solal-gendrin/")) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.subheadline.weight(.semibold))
                    Text("Me suivre sur LinkedIn")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }

    // MARK: L'application

    private var appCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                appIconView
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lyon Pocket")
                        .font(.headline)
                    Text("Les transports lyonnais, en direct.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Une application indépendante, née d'un usage quotidien des TCL : gratuite, sans publicité, sans compte. Aucune donnée personnelle n'est collectée.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                pill("Gratuit")
                pill("Sans pub")
                pill("Sans tracking")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var appIconView: some View {
        Group {
            if let img = UIImage(named: "AppIcon") ?? Bundle.main.iconImage() {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appSuccess)
                    .overlay(
                        Image(systemName: "tram.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Open Projets

    private var openProjetsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 42, height: 42)
                    AsyncImage(url: URL(string: "https://openprojets.com/home/img/logos/square_white.png")) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit().padding(9)
                        } else {
                            Image(systemName: "map.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 42, height: 42)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Projets by Vazy")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Mon autre projet")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Vous travaillez dans une collectivité ou vous êtes élu ?")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Avec Vazy, société à mission villeurbannaise, on a construit Open Projets : une carte interactive que chaque commune peut déployer pour informer ses habitants sur ses chantiers et projets d'aménagement.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                Text("La carte reprend votre logo, vos couleurs, vos catégories. Vos agents ajoutent les projets en quelques clics. Les habitants consultent depuis leur téléphone, sans compte, sans téléchargement.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            VStack(spacing: 10) {
                tintedLink("Découvrir Open Projets", url: URL.trusted("https://openprojets.com/home"), filled: true)
                tintedLink("Voir la carte de la Métropole de Lyon", url: URL.trusted("https://openprojets.com/default"), filled: false)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.appAccent.opacity(0.25), radius: 18, x: 0, y: 8)
    }

    // MARK: Open Data

    private var openDataTribute: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Merci à l'Open Data du Grand Lyon")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Cette app n'existerait pas sans le travail remarquable des équipes Open Data du Grand Lyon. Position des bus en temps réel, alertes, travaux, parkings, Vélo'v : tout est mis à disposition librement, sous licence ouverte. Un travail souvent invisible, qui rend possible des projets citoyens comme celui-ci.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL.trusted("https://data.grandlyon.com")) {
                HStack(spacing: 6) {
                    Text("data.grandlyon.com")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.appSuccess)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white, in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.appSuccess, Color.appSuccess.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.appSuccess.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    // MARK: Sources

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                badge(icon: "antenna.radiowaves.left.and.right", tint: .appAccent)
                Text("Sources de données")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                sourceRow(title: "Position des véhicules", subtitle: "SIRI-Lite, temps réel", icon: "location.fill", tint: .appSuccess)
                separator
                sourceRow(title: "Arrêts, lignes, horaires", subtitle: "GTFS", icon: "tram.fill", tint: .appAccent)
                separator
                sourceRow(title: "Alertes et perturbations", subtitle: "Flux officiel TCL", icon: "exclamationmark.triangle.fill", tint: .appWarning)
                separator
                sourceRow(title: "Travaux", subtitle: "Chantiers du réseau et de la voirie", icon: "hammer.fill", tint: .appWarning)
                separator
                sourceRow(title: "Parkings et Vélo'v", subtitle: "Disponibilité en temps réel", icon: "car.fill", tint: .appAccent)
            }

            Text("Toutes les données sont publiées par le Grand Lyon sous licence ouverte (Etalab / ODbL).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardBackground)
    }

    // MARK: Liens

    private var linksFooter: some View {
        VStack(spacing: 0) {
            footerLink(title: "Site officiel", subtitle: "lyon-pocket.netlify.app", icon: "globe", tint: .appAccent,
                       url: URL.trusted("https://lyon-pocket.netlify.app/"))
            separator
            footerLink(title: "Politique de confidentialité", subtitle: "Aucune donnée personnelle collectée", icon: "lock.shield.fill", tint: .appNeutral,
                       url: URL.trusted("https://solalgendrin.github.io/alerte-tcl/privacy"))
        }
        .background(cardBackground)
    }

    private var versionFooter: some View {
        VStack(spacing: 6) {
            Text("Lyon Pocket \(appVersion)\(buildNumber.isEmpty ? "" : " (\(buildNumber))")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Fait à Villeurbanne, avec ♥")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("Application indépendante, sans aucune affiliation à SYTRAL Mobilités, Keolis Lyon ou TCL.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var separator: some View {
        Divider()
            .padding(.leading, 60)
    }

    private func badge(icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
    }

    /// Lien sur une carte colorée : plein (blanc) ou discret (blanc translucide).
    private func tintedLink(_ title: String, url: URL, filled: Bool) -> some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(filled ? .semibold : .medium))
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(filled ? Color.appAccent : Color.white.opacity(0.9))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(filled ? Color.white : Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sourceRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private func footerLink(title: String, subtitle: String, icon: String, tint: Color, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bundle helper for app icon

private extension Bundle {
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

#Preview {
    AboutView()
}
