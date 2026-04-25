import SwiftUI

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
                VStack(spacing: 28) {
                    heroSection
                    manifestoCard
                    openDataTribute
                    sourcesCard
                    creatorCard
                    contactCard
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

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            appIconView
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)

            VStack(spacing: 4) {
                Text("Lyon Pocket")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Les transports lyonnais, en direct.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var appIconView: some View {
        Group {
            if let img = UIImage(named: "AppIcon")
                ?? Bundle.main.iconImage() {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.green, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .overlay(
                        Image(systemName: "tram.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Manifesto

    private var manifestoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                badge(icon: "checkmark.seal.fill", tint: .green)
                Text("Respectueuse, par conception")
                    .font(.headline)
            }

            Text("Lyon Pocket est gratuit, sans publicité, sans compte. Aucune donnée personnelle n'est collectée. C'est tout.")
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

    // MARK: Open data tribute (highlighted)

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

            Text("Cette app n'existerait pas sans le travail remarquable des équipes Open Data du Grand Lyon. Position des bus en temps réel, alertes, travaux, parkings : tout est mis à disposition librement, sous licence ouverte. Un travail souvent invisible, qui rend possible des projets citoyens comme celui-ci.")
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
                .foregroundStyle(.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white, in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.55, blue: 0.30),
                    Color(red: 0.06, green: 0.42, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.green.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    // MARK: Sources

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                badge(icon: "antenna.radiowaves.left.and.right", tint: .blue)
                Text("Sources de données")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                sourceRow(
                    title: "Position des véhicules",
                    subtitle: "SIRI-Lite, temps réel",
                    icon: "location.fill",
                    tint: .green
                )
                separator
                sourceRow(
                    title: "Arrêts, lignes, horaires",
                    subtitle: "GTFS",
                    icon: "tram.fill",
                    tint: .indigo
                )
                separator
                sourceRow(
                    title: "Alertes & perturbations",
                    subtitle: "Flux officiel TCL",
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange
                )
                separator
                sourceRow(
                    title: "Travaux",
                    subtitle: "Chantiers du réseau et de la voirie",
                    icon: "hammer.fill",
                    tint: .yellow
                )
                separator
                sourceRow(
                    title: "Parkings P+R",
                    subtitle: "Occupation en temps réel",
                    icon: "car.fill",
                    tint: .purple
                )
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

    // MARK: Creator

    private var creatorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                badge(icon: "person.fill", tint: .indigo)
                Text("Derrière Lyon Pocket")
                    .font(.headline)
            }

            Text("**Solal Gendrin**, conseiller métropolitain à Lyon. Lyon Pocket est un projet personnel, né d'un usage quotidien des TCL.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL.trusted("https://openprojets.com/home")) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        AsyncImage(url: URL(string: "https://openprojets.com/home/img/logos/square_white.png")) { phase in
                            if let img = phase.image {
                                img
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            } else {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Projets")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Mon autre projet : la carte des projets urbains pour les collectivités")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Contact

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                badge(icon: "bubble.left.and.bubble.right.fill", tint: .pink)
                Text("Une idée ? Un bug ?")
                    .font(.headline)
            }

            Text("Suggestions, retours, propositions d'évolution : écrivez-moi sur LinkedIn, je lis tout.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL.trusted("https://www.linkedin.com/in/solal-gendrin/")) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Me contacter sur LinkedIn")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Links footer

    private var linksFooter: some View {
        VStack(spacing: 0) {
            footerLink(
                title: "Site officiel",
                subtitle: "lyon-pocket.netlify.app",
                icon: "globe",
                tint: .teal,
                url: URL.trusted("https://lyon-pocket.netlify.app/")
            )
            separator
            footerLink(
                title: "Politique de confidentialité",
                subtitle: "Aucune donnée personnelle collectée",
                icon: "lock.shield.fill",
                tint: .gray,
                url: URL.trusted("https://solalgendrin.github.io/alerte-tcl/privacy")
            )
        }
        .background(cardBackground)
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Lyon Pocket \(appVersion)\(buildNumber.isEmpty ? "" : " (\(buildNumber))")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Fait à Villeurbanne, avec ♥")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
            .background(
                Capsule().fill(Color(.tertiarySystemGroupedBackground))
            )
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
