import SwiftUI

/// Onglet Info : une page éditoriale sur Lyon Pocket, puis sur celui qui la fait. L'application en
/// tête (icône, nom, accroche, quatre promesses, deux chiffres), « Qui est derrière » (Solal Gendrin,
/// ses contacts), ses autres projets, un remerciement, les sources. Une seule teinte d'interface
/// (l'accent), le vert réservé à l'étiquette d'élu écologiste.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                hero
                promises
                numbers
                author
                projects
                thanks
                sources
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: L'application

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            appIcon
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)

            Text("Lyon Pocket")
                .font(.system(size: 40, weight: .bold, design: .rounded))

            Text("Les bus et les trams en direct sur la carte, les alertes de vos lignes, les fiches horaires, les chantiers, les parkings et les Vélo'v. Tout Lyon dans la poche, sans compte et sans publicité.")
                .font(.system(size: 19, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appIcon: some View {
        Group {
            if let img = UIImage(named: "AppIcon") ?? Bundle.main.iconImage() {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appAccent)
                    .overlay(
                        Image(systemName: "tram.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Qui est derrière

    private var author: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("Qui est derrière")
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Conseiller métropolitain écologiste · Villeurbanne")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(Color.appSuccess)
                    Text("Solal Gendrin")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Je siège à la Métropole de Lyon pour Villeurbanne, chez les écologistes. Le soir, je code des outils pour rendre la ville plus lisible. Lyon Pocket est né comme ça, quand TCL Live a disparu : je voulais retrouver mon bus sur une carte. Vous êtes maintenant des milliers à l'utiliser, et ça me fait toujours quelque chose.")
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .foregroundStyle(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                Divider().padding(.leading, 18)
                contactRow(icon: "person.crop.circle.fill", title: "LinkedIn", subtitle: "Retours, idées, bugs : je lis tout", url: URL.trusted("https://www.linkedin.com/in/solal-gendrin/"))
                Divider().padding(.leading, 66)
                contactRow(icon: "bubble.left.fill", title: "X", subtitle: "@_solal_", url: URL.trusted("https://x.com/_solal_"))
            }
            .background(card)
        }
    }

    // MARK: Promesses

    private var promises: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("Lyon Pocket, c'est")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                promise(icon: "gift.fill", title: "Gratuite", text: "Pour tout le monde, pour toujours.")
                promise(icon: "eye.slash.fill", title: "Sans publicité", text: "Rien ne s'affiche entre vous et votre bus.")
                promise(icon: "person.crop.circle.badge.xmark", title: "Sans compte", text: "On ouvre, ça marche.")
                promise(icon: "lock.fill", title: "Sans traçage", text: "Aucune donnée collectée, donc rien à vendre.")
            }
        }
    }

    private func promise(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(height: 28)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(16)
        .background(card)
    }

    // MARK: Chiffres

    private var numbers: some View {
        HStack(spacing: 12) {
            number(value: "25 000", caption: "installations, et ça continue")
            number(value: "N° 1", caption: "des apps de navigation sur l'App Store, un temps devant Google Maps et Waze")
        }
    }

    private func number(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(16)
        .background(card)
    }

    // MARK: Projets

    private var projects: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("Ses autres projets")
            project(
                title: "TCL 2040",
                text: "Prenez la place du président du Sytral : un budget fermé, des projets réels, des impacts chiffrés. Dessinez le réseau de 2040 et voyez ce qu'il coûte vraiment.",
                url: URL.trusted("https://tcl-2040.com/")
            )
            project(
                title: "Open Projets",
                text: "Née « Grands Projets » pour la Métropole, devenue la carte que chaque commune peut ouvrir à ses habitants : chantiers, projets, avancement, documents. Je la construis chez Vazy, société à mission villeurbannaise.",
                url: URL.trusted("https://openprojets.com/home")
            )
            project(
                title: "Nadir",
                text: "Rafraîchir son logement sans climatisation : l'app compare heure par heure la température chez vous et dehors, et vous dit quand ouvrir et fermer les fenêtres.",
                url: URL.trusted("https://apps.apple.com/fr/app/nadir/id6788036137")
            )
        }
    }

    private func project(title: String, text: String, url: URL) -> some View {
        Link(destination: url) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Text(text)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(card)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func contactRow(icon: String, title: String, subtitle: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Merci

    private var thanks: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("Merci")
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appAccent)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rien de tout ça n'existerait sans les équipes Open Data du Grand Lyon, qui publient les positions des bus, les alertes, les chantiers, les parkings et les Vélo'v sous licence ouverte. Un travail discret, qui rend possibles des projets citoyens comme celui-ci.")
                        .font(.system(size: 17))
                        .lineSpacing(4)
                        .foregroundStyle(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
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
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Sources

    private var sources: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("D'où viennent les données")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                source(icon: "location.fill", title: "Positions des bus et trams", detail: "SIRI-Lite, en direct")
                source(icon: "tram.fill", title: "Arrêts, lignes, horaires", detail: "GTFS")
                source(icon: "exclamationmark.triangle.fill", title: "Alertes trafic", detail: "Flux officiel TCL")
                source(icon: "hammer.fill", title: "Travaux", detail: "Réseau et voirie")
                source(icon: "car.fill", title: "Parkings", detail: "Places libres en direct")
                source(icon: "bicycle", title: "Vélo'v", detail: "Vélos et places en direct")
            }
            Text("Toutes ces données sont publiées par le Grand Lyon sous licence ouverte (Etalab et ODbL).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func source(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 30, height: 30)
                .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .padding(14)
        .background(card)
    }

    // MARK: Pied de page

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link("Politique de confidentialité", destination: URL.trusted("https://solalgendrin.github.io/alerte-tcl/privacy"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appAccent)
            Text("Lyon Pocket \(appVersion), fait à Villeurbanne. Application indépendante, sans lien avec SYTRAL Mobilités, Keolis Lyon ou TCL.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: Composants

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Icône de l'application

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
