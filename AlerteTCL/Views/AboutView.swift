import SwiftUI

/// Onglet Info : l'application d'abord (icône, nom, accroche, quatre promesses), puis qui est
/// derrière, ses autres projets avec leurs logos, d'où viennent les données. Une seule teinte
/// d'interface (l'accent), le vert réservé à l'étiquette d'élu écologiste.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                hero
                promises
                author
                projects
                data
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

            Text("Les bus et les trams en direct sur la carte, les alertes de vos lignes, les fiches horaires, les chantiers, les parkings et les Vélo'v. Tout Lyon dans la poche.")
                .font(.system(size: 19))
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

    // MARK: Promesses

    private var promises: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            promise(icon: "gift.fill", title: "Gratuite")
            promise(icon: "eye.slash.fill", title: "Sans publicité")
            promise(icon: "person.crop.circle.badge.xmark", title: "Sans compte")
            promise(icon: "lock.fill", title: "Sans traçage")
        }
    }

    private func promise(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 36, height: 36)
                .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(card)
    }

    // MARK: Qui est derrière

    private var author: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Qui est derrière")
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Solal Gendrin")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Conseiller métropolitain écologiste · Villeurbanne")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(Color.appSuccess)
                    Text("Je siège à la Métropole de Lyon pour Villeurbanne, chez les écologistes. Le soir, je code des outils pour rendre la ville plus lisible. Lyon Pocket est né comme ça, quand TCL Live a disparu : je voulais retrouver mon bus sur une carte. Vous êtes maintenant des milliers à l'utiliser : merci de votre confiance.")
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .foregroundStyle(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                Divider().padding(.leading, 18)
                linkRow(icon: "person.crop.circle.fill", title: "LinkedIn", subtitle: "Retours, idées, bugs : je lis tout", url: URL.trusted("https://www.linkedin.com/in/solal-gendrin/"))
                Divider().padding(.leading, 66)
                linkRow(icon: "cloud.fill", title: "Bluesky", subtitle: "@solalgendrin.bsky.social", url: URL.trusted("https://bsky.app/profile/solalgendrin.bsky.social"))
                Divider().padding(.leading, 66)
                linkRow(icon: "bubble.left.fill", title: "X", subtitle: "@_solal_", url: URL.trusted("https://x.com/_solal_"))
            }
            .background(card)
        }
    }

    // MARK: Ses autres projets

    private var projects: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Ses autres projets")
            VStack(spacing: 12) {
                project(
                    logo: "LogoTCL2040", logoBackground: Color.appAccent, logoPadding: 10,
                    title: "TCL 2040",
                    text: "Prenez la place du président du Sytral : un budget fermé, des projets réels, des impacts chiffrés. Dessinez le réseau de 2040 et voyez ce qu'il coûte vraiment.",
                    url: URL.trusted("https://tcl-2040.com/")
                )
                project(
                    logo: "LogoOpenProjets", logoBackground: .white, logoPadding: 7,
                    title: "Open Projets",
                    text: "Née « Grands Projets » pour la Métropole, devenue la carte que chaque commune peut ouvrir à ses habitants : chantiers, projets, avancement, documents. Construite chez Vazy, société à mission villeurbannaise.",
                    url: URL.trusted("https://openprojets.com/home")
                )
                project(
                    logo: "LogoNadir", logoBackground: nil, logoPadding: 0,
                    title: "Nadir",
                    text: "Rafraîchir son logement sans climatisation : l'app compare heure par heure la température chez vous et dehors, et vous dit quand ouvrir et fermer les fenêtres.",
                    url: URL.trusted("https://apps.apple.com/fr/app/nadir/id6788036137")
                )
            }
        }
    }

    private func project(logo: String, logoBackground: Color?, logoPadding: CGFloat, title: String, text: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(alignment: .top, spacing: 14) {
                Image(logo)
                    .resizable()
                    .scaledToFit()
                    .padding(logoPadding)
                    .frame(width: 60, height: 60)
                    .background(logoBackground ?? Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.appNeutralBorder.opacity(logoBackground == .white ? 0.6 : 0), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(text)
                        .font(.footnote)
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(card)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Les données

    private var data: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("D'où viennent les données")
            VStack(alignment: .leading, spacing: 0) {
                dataRow(
                    icon: "building.2.fill",
                    title: "Métropole de Lyon",
                    text: "Positions des bus et des trams, alertes, chantiers, parkings et Vélo'v, publiés en données ouvertes sur data.grandlyon.com.",
                    url: URL.trusted("https://data.grandlyon.com")
                )
                Divider().padding(.leading, 66)
                dataRow(
                    icon: "tram.fill",
                    title: "SYTRAL Mobilités",
                    text: "Arrêts, tracés et horaires des lignes TCL, au format GTFS.",
                    url: nil
                )
                Divider().padding(.leading, 18)
                Text("Merci aux équipes qui publient tout ça librement. Lyon Pocket est une application indépendante, sans lien avec SYTRAL Mobilités, Keolis Lyon ou TCL.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
            }
            .background(card)
        }
    }

    private func dataRow(icon: String, title: String, text: String, url: URL?) -> some View {
        let content = HStack(alignment: .top, spacing: 14) {
            iconBox(icon)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    if url != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())

        return Group {
            if let url {
                Link(destination: url) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    // MARK: Pied de page

    private var footer: some View {
        HStack(spacing: 14) {
            Link("Politique de confidentialité", destination: URL.trusted("https://solalgendrin.github.io/alerte-tcl/privacy"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appAccent)
            Text("Version \(appVersion), faite à Villeurbanne")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: Composants

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private func iconBox(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.appAccent)
            .frame(width: 38, height: 38)
            .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                iconBox(icon)
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
