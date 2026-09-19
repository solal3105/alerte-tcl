import SwiftUI
import WidgetKit

// MARK: - Ajouter un arrêt aux widgets

/// Feuille ouverte depuis la fiche d'un arrêt : on coche une ou plusieurs lignes et sens, puis on
/// enregistre. La confirmation dit où retrouver l'arrêt et mène à la galerie des widgets.
struct AddToWidgetSheet: View {
    let stopName: String
    /// Un choix par ligne et par sens desservis, dans l'ordre de la fiche.
    let options: [WidgetStop]

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var bridge = WidgetBridge.shared
    @State private var selected: Set<String> = []
    @State private var saved = false
    @State private var feedback = false

    private var selectable: [WidgetStop] { options.filter { !bridge.contains($0) } }

    var body: some View {
        NavigationStack {
            Group {
                if saved {
                    confirmation
                } else {
                    chooser
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(saved ? "Arrêt enregistré" : "Ajouter au widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: feedback)
        }
    }

    // MARK: Choix des sens

    private var chooser: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(stopName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Choisissez la ligne et le sens que vous prenez à cet arrêt. Chaque sens enregistré devient un choix dans les widgets « Prochains passages » et « Tableau de départs ».")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if options.isEmpty {
                        Text("Nous ne connaissons pas encore les sens de cet arrêt. Réessayez dans un instant.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(card)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                                optionRow(option)
                                if index < options.count - 1 { Divider().padding(.leading, 70) }
                            }
                        }
                        .background(card)
                    }
                }
                .padding(20)
            }
            if !selectable.isEmpty {
                Button(action: save) {
                    Text(selected.count > 1 ? "Enregistrer ces \(selected.count) sens" : "Enregistrer ce sens")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .controlSize(.large)
                .disabled(selected.isEmpty)
                .padding(20)
                .background(.bar)
            }
        }
    }

    private func optionRow(_ option: WidgetStop) -> some View {
        let alreadySaved = bridge.contains(option)
        let isSelected = selected.contains(option.id)
        return Button {
            if isSelected { selected.remove(option.id) } else { selected.insert(option.id) }
        } label: {
            HStack(spacing: 14) {
                LineBadge(line: option.line, size: 14)
                    .frame(width: 56, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("vers \(option.direction)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if alreadySaved {
                        Text("Déjà enregistré")
                            .font(.caption)
                            .foregroundStyle(Color.appSuccess)
                    }
                }
                Spacer()
                Image(systemName: alreadySaved || isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(alreadySaved ? Color.appSuccess : (isSelected ? Color.appAccent : Color.appNeutralBorder))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(alreadySaved)
    }

    private func save() {
        let chosen = options.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { return }
        bridge.add(chosen)
        feedback.toggle()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { saved = true }
    }

    // MARK: Confirmation

    private var confirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack {
                    Circle().fill(Color.appSuccess).frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("C'est enregistré")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("« \(stopName) » est maintenant proposé dans les réglages des widgets « Prochains passages » et « Tableau de départs ».")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Pour l'afficher sur l'écran d'accueil, maintenez le fond d'écran appuyé, touchez « Modifier » puis « Ajouter un widget », et cherchez Lyon Pocket. Une fois le widget posé, maintenez-le appuyé et touchez « Modifier le widget » pour choisir cet arrêt.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
                    .background(card)
                NavigationLink {
                    WidgetGalleryView()
                } label: {
                    Text("Voir les widgets")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .controlSize(.large)
            }
            .padding(20)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Galerie des widgets

/// Ce que chaque widget montre, à quoi il ressemble, et comment on le règle. Depuis l'onglet Info
/// ou la confirmation d'un arrêt enregistré.
struct WidgetGalleryView: View {
    @ObservedObject private var bridge = WidgetBridge.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Vos prochains passages, un parking, une station Vélo'v, les chantiers autour de vous et le trafic de vos lignes, sans ouvrir l'application. Chaque widget existe en plusieurs tailles, et certains aussi sur l'écran verrouillé.")
                    .font(.system(size: 17))
                    .lineSpacing(4)
                    .foregroundStyle(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                howTo

                NavigationLink {
                    WidgetStopsView()
                } label: {
                    HStack(spacing: 14) {
                        iconBox("mappin.and.ellipse")
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Arrêts enregistrés")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(stopsSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(card)
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(WidgetKind.allCases) { kind in
                    WidgetGalleryCard(kind: kind)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
    }

    private var stopsSummary: String {
        switch bridge.stops.count {
        case 0: "Aucun pour l'instant. Ouvrez la fiche d'un arrêt sur la carte et touchez « Ajouter au widget »."
        case 1: "Un arrêt, proposé dans les widgets de passages."
        default: "\(bridge.stops.count) arrêts, proposés dans les widgets de passages. Vous pouvez les réordonner ou les retirer."
        }
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Comment ajouter un widget")
            VStack(alignment: .leading, spacing: 10) {
                step(1, "Maintenez le fond de l'écran d'accueil appuyé, puis touchez « Modifier » et « Ajouter un widget ».")
                step(2, "Cherchez Lyon Pocket, choisissez le widget et sa taille, puis touchez « Ajouter le widget ».")
                step(3, "Pour le régler, maintenez le widget appuyé et touchez « Modifier le widget ».")
                step(4, "Sur l'écran verrouillé, maintenez l'écran appuyé, touchez « Personnaliser », puis la zone des widgets.")
            }
            .padding(18)
            .background(card)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.appAccent, in: Circle())
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 22, weight: .bold, design: .rounded))
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
}

/// Un widget de la galerie : son aperçu réel (la vue de l'extension avec des données d'exemple),
/// ce qu'il montre, ses tailles et la façon de le régler.
private struct WidgetGalleryCard: View {
    let kind: WidgetKind

    private var previewFamily: WidgetFamily {
        kind.families.contains(.systemMedium) ? .systemMedium : .systemLarge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                Text(kind.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            WidgetPreview(kind: kind, family: previewFamily)
                .frame(maxWidth: .infinity)
            Text(kind.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tailles : \(kind.familiesText).")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(kind.setupHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

/// La vue du widget, rendue dans l'application avec des données d'exemple, à la taille du widget.
struct WidgetPreview: View {
    let kind: WidgetKind
    let family: WidgetFamily

    @State private var works = WidgetSamples.works
    @Environment(\.colorScheme) private var colorScheme

    private var size: CGSize {
        switch family {
        case .systemSmall: CGSize(width: 158, height: 158)
        case .systemLarge: CGSize(width: 338, height: 354)
        default: CGSize(width: 338, height: 158)
        }
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.appNeutralBorder.opacity(0.5), lineWidth: 0.5))
            .allowsHitTesting(false)
            .task(id: colorScheme) { await renderWorksMap() }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .departures: DeparturesWidgetView(entry: WidgetSamples.departures, family: family).padding(16)
        case .board: BoardWidgetView(entry: WidgetSamples.board, family: family).padding(16)
        case .parking: ParkingWidgetView(entry: WidgetSamples.parking, family: family).padding(16)
        case .velov: VelovWidgetView(entry: WidgetSamples.velov, family: family).padding(16)
        case .works: WorksWidgetView(entry: works, family: family)
        case .traffic: TrafficWidgetView(entry: WidgetSamples.traffic, family: family).padding(16)
        }
    }

    /// La carte de l'aperçu « Travaux » est une vraie capture, comme dans le widget.
    private func renderWorksMap() async {
        guard kind == .works, works.mapLight == nil || works.mapDark == nil else { return }
        let mapSize = family == .systemMedium ? CGSize(width: 150, height: size.height) : CGSize(width: size.width, height: 190)
        let scale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 3
        let sample = WidgetSamples.works
        let light = await WorksMapSnapshot.render(center: WorksMapSnapshot.lyonCenter, radiusMeters: 1000, shapes: WidgetSamples.worksShapes, size: mapSize, scale: scale, dark: false, showUser: true)
        let dark = await WorksMapSnapshot.render(center: WorksMapSnapshot.lyonCenter, radiusMeters: 1000, shapes: WidgetSamples.worksShapes, size: mapSize, scale: scale, dark: true, showUser: true)
        works = WorksEntry(
            date: sample.date, status: .ready, works: sample.works, radiusMeters: sample.radiusMeters,
            hasLocation: true, mapLight: light, mapDark: dark, fetchedAt: sample.fetchedAt
        )
    }
}

// MARK: - Arrêts enregistrés

/// La liste des arrêts proposés aux widgets de passages : on la réordonne (l'ordre est celui du
/// tableau de départs) et on retire ce qui ne sert plus.
struct WidgetStopsView: View {
    @ObservedObject private var bridge = WidgetBridge.shared

    var body: some View {
        List {
            if bridge.stops.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aucun arrêt enregistré")
                        .font(.headline)
                    Text("Sur la carte Transport, ouvrez la fiche d'un arrêt et touchez « Ajouter au widget » : la ligne et le sens choisis apparaîtront ici.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Section {
                    ForEach(bridge.stops) { stop in
                        HStack(spacing: 14) {
                            LineBadge(line: stop.line, size: 14)
                                .frame(width: 56, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.stopName).font(.subheadline.weight(.semibold))
                                Text("vers \(stop.direction)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { bridge.remove(at: $0) }
                    .onMove { bridge.move(from: $0, to: $1) }
                } footer: {
                    Text("Le premier arrêt est celui qu'un widget « Prochains passages » affiche tant qu'il n'est pas réglé, et le tableau de départs suit cet ordre.")
                }
            }
        }
        .navigationTitle("Arrêts enregistrés")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !bridge.stops.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}

#Preview("Galerie") {
    NavigationStack { WidgetGalleryView() }
}
