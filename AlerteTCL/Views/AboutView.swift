import SwiftUI

/// Onglet Info : Solal Gendrin, son mandat, ses projets, comment le joindre, puis les remerciements
/// et les sources. Une seule teinte d'interface (l'accent), le vert pour son étiquette d'élu écologiste.
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
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    section("À la Métropole") { mandateCard }
                    section("Mes projets") { projectsCard }
                    section("On se parle ?") { contactCard }
                    section("Merci") { openDataCard }
                    section("D'où viennent les données") { sourcesCard }
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: Solal

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("SG")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.appSuccess, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Solal Gendrin")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Conseiller métropolitain écologiste")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appSuccess)
                    Text("Élu de Villeurbanne, mandat 2026 à 2032")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Bonjour, moi c'est Solal. Je siège à la Métropole de Lyon pour Villeurbanne, dans le groupe des écologistes. Le reste du temps, je construis des outils pour rendre la ville plus lisible. Lyon Pocket est né un soir, quand TCL Live a disparu et que je voulais simplement retrouver mon bus sur une carte. Depuis, plus de 25 000 personnes l'ont installée, et l'app a même passé quelques jours en tête des applications de navigation sur l'App Store, devant Google Maps et Waze.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            HStack(spacing: 8) {
                pill("Gratuite")
                pill("Sans pub")
                pill("Sans compte")
                pill("Sans données vendues")
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }

    // MARK: Mandat

    private var mandateCard: some View {
        VStack(spacing: 0) {
            row(icon: "house.fill", title: "Habitat et logement", subtitle: "Renouvellement urbain et politique de la ville")
            separator
            row(icon: "building.columns.fill", title: "Grands projets et rayonnement", subtitle: "Tourisme et relations internationales")
            separator
            row(icon: "leaf.fill", title: "Espace public", subtitle: "Territoires, propreté urbaine et qualité de l'espace public")
        }
        .background(cardBackground)
    }

    // MARK: Projets

    private var projectsCard: some View {
        VStack(spacing: 0) {
            projectRow(
                icon: "tram.fill",
                title: "Lyon Pocket",
                text: "Cette application : les bus et les trams en direct, les alertes, les fiches horaires, les chantiers, les parkings et les Vélo'v.",
                url: URL.trusted("https://lyon-pocket.netlify.app/")
            )
            separator
            projectRow(
                icon: "gamecontroller.fill",
                title: "TCL 2040",
                text: "Mettez-vous à la place du président du Sytral : un budget fermé, des projets réels, des impacts chiffrés. Dessinez le réseau de 2040 et voyez ce qu'il coûte vraiment.",
                url: URL.trusted("https://tcl-2040.com/")
            )
            separator
            projectRow(
                icon: "map.fill",
                title: "Grands Projets",
                text: "La carte des projets urbains et de mobilité autour de vous, avec leur avancement, leur calendrier et les documents officiels.",
                url: URL.trusted("https://grandsprojets.com/")
            )
            separator
            projectRow(
                icon: "building.2.fill",
                title: "Open Projets, avec Vazy",
                text: "La même idée, offerte aux communes : la carte de leurs chantiers et de leurs projets, que les habitants consultent sans compte. Construite chez Vazy, société à mission villeurbannaise, où je dirige le produit et la technique.",
                url: URL.trusted("https://openprojets.com/home")
            )
            separator
            projectRow(
                icon: "wind",
                title: "Nadir",
                text: "Rafraîchir son logement sans climatisation : l'app compare heure par heure la température chez vous et dehors, et vous dit quand ouvrir et fermer les fenêtres.",
                url: URL.trusted("https://apps.apple.com/fr/app/nadir/id6788036137")
            )
        }
        .background(cardBackground)
    }

    // MARK: Contact

    private var contactCard: some View {
        VStack(spacing: 0) {
            linkRow(icon: "person.crop.circle.fill", title: "LinkedIn", subtitle: "Pour me suivre et m'écrire, je lis tout", url: URL.trusted("https://www.linkedin.com/in/solal-gendrin/"))
            separator
            linkRow(icon: "bubble.left.fill", title: "X", subtitle: "@_solal_", url: URL.trusted("https://x.com/_solal_"))
            separator
            linkRow(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub", subtitle: "solal3105", url: URL.trusted("https://github.com/solal3105"))
        }
        .background(cardBackground)
    }

    // MARK: Open Data

    private var openDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rien de tout ça n'existerait sans les équipes Open Data du Grand Lyon, qui publient les positions des bus, les alertes, les chantiers, les parkings et les Vélo'v sous licence ouverte. C'est un travail discret qui rend possibles des projets citoyens comme celui-ci.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
            Link(destination: URL.trusted("https://data.grandlyon.com")) {
                HStack(spacing: 6) {
                    Text("data.grandlyon.com")
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Sources

    private var sourcesCard: some View {
        VStack(spacing: 0) {
            row(icon: "location.fill", title: "Position des véhicules", subtitle: "SIRI-Lite, en direct")
            separator
            row(icon: "tram.fill", title: "Arrêts, lignes, horaires", subtitle: "GTFS")
            separator
            row(icon: "exclamationmark.triangle.fill", title: "Alertes et perturbations", subtitle: "Flux officiel TCL")
            separator
            row(icon: "hammer.fill", title: "Travaux", subtitle: "Chantiers du réseau et de la voirie")
            separator
            row(icon: "car.fill", title: "Parkings et Vélo'v", subtitle: "Disponibilité en direct")
            Text("Toutes ces données sont publiées par le Grand Lyon sous licence ouverte (Etalab / ODbL).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardBackground)
    }

    // MARK: Pied de page

    private var footer: some View {
        VStack(spacing: 8) {
            Link("Politique de confidentialité", destination: URL.trusted("https://solalgendrin.github.io/alerte-tcl/privacy"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.appAccent)
            Text("Lyon Pocket \(appVersion)\(buildNumber.isEmpty ? "" : " (\(buildNumber))") · Fait à Villeurbanne")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Application indépendante, sans lien avec SYTRAL Mobilités, Keolis Lyon ou TCL.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: Composants

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var separator: some View {
        Divider().padding(.leading, 62)
    }

    private func iconBox(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.appAccent)
            .frame(width: 34, height: 34)
            .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            iconBox(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func projectRow(icon: String, title: String, text: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(alignment: .top, spacing: 14) {
                iconBox(icon)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                iconBox(icon)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutView()
}
