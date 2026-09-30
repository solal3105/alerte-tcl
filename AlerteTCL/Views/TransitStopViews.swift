import SwiftUI
import MapKit
import Shared

// MARK: - Merged Stop Marker (supprimé)
//
// Le marqueur SwiftUI a été supprimé au profit de `MergedStopAnnotationView`
// (UIKit, UIImage pré-rendue). Voir `MarkerImageCache` + `MapAnnotations`.

// MARK: - Transit Stop Detail Sheet

// MARK: - Line Badge (réutilisable)

struct LineBadge: View {
    let line: String
    var size: CGFloat = 11
    @ObservedObject private var palette = LinePaletteObserver.shared
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: line)
    }
    
    private var textColor: Color {
        LineColorHelper.textColor(for: line)
    }
    
    private var needsBorder: Bool {
        LineColorHelper.needsBorder(for: line)
    }
    
    var body: some View {
        Text(line)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.appNeutralBorder, lineWidth: needsBorder ? 1 : 0)
            )
    }
}

// MARK: - Prochains passages : une carte par sens

/// Un sens d'une ligne à l'arrêt, en une carte : le prochain passage en gros (délai ou état, jamais une
/// heure passée), où est son véhicule sur une mini-ligne, puis « Ensuite … · dernier … ». Tout vient de
/// `LineBoard` (`StopBoard`, module partagé), recalculé chaque seconde avec `nowMs`.
struct LineBoardCard: View {
    let board: LineBoard
    let nowMs: Int64
    /// Fiche horaire connue : sans passage, on sait alors que rien n'est prévu.
    let timetableKnown: Bool
    /// Cadre la carte sur le véhicule du passage et l'arrêt.
    let onLocate: (ApproachingVehicle) -> Void
    var onShowOnMap: (() -> Void)? = nil
    let onShowTimetable: () -> Void

    private var line: String { board.group.line }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LineBadge(line: line, size: 14)
                Text(board.group.terminus)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let onShowOnMap, let label = TransportMode.detectFromLine(line).shared.showOnMapLabel {
                    iconButton("map", label: label, action: onShowOnMap)
                }
                iconButton("calendar", label: "Tous les horaires", action: onShowTimetable)
            }
            if let first = board.first {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    PassageHeadline(status: first, nowMs: nowMs, size: 30)
                        .layoutPriority(1)
                    if let detail = PassageTexts.shared.headlineDetail(board: board, nowEpochMs: nowMs, timeZoneId: StopApproach.shared.TIME_ZONE) {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let approach = first.approach {
                    Button {
                        onLocate(approach)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            MiniLine(
                                line: line,
                                stopsBefore: Int(approach.stopsBefore),
                                atStop: first.phase == PassagePhase.atStop,
                                vehicleIcon: (VehicleType(shared: approach.vehicle.vehicleType) ?? .bus).icon
                            )
                            VehicleStatusLines(lead: first.location, vehicle: approach.vehicle, nowMs: nowMs)
                        }
                        .padding(.trailing, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Montre ce véhicule sur la carte")
                }
                if let then = PassageTexts.shared.thenLine(board: board, timeZoneId: StopApproach.shared.TIME_ZONE) {
                    Text(then)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(PassageTexts.shared.noPassage(timetableKnown: timetableKnown))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Lien de la carte (voir sur la carte, tous les horaires) : un pictogramme à l'accent.
    private func iconButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Le gros texte d'un passage, précédé de sa source : point vert qui pulse pour le direct, horloge grise
/// pour l'horaire prévu. Le même rendu sert à la fiche d'arrêt et à la fiche horaire.
struct PassageHeadline: View {
    let status: PassageStatus
    let nowMs: Int64
    let size: CGFloat

    var body: some View {
        // La source est posée devant le texte sans compter dans l'alignement : la ligne de base reste celle du texte.
        Text(status.headline(nowEpochMs: nowMs, timeZoneId: StopApproach.shared.TIME_ZONE))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(status.phase.isLive ? Color.primary : Color.secondary)
            .lineLimit(1)
            .padding(.leading, size * 0.75)
            .overlay(alignment: .leading) { source }
    }

    @ViewBuilder
    private var source: some View {
        if status.phase.isLive {
            Image(systemName: "circle.fill")
                .font(.system(size: size * 0.32))
                .foregroundStyle(Color.appSuccess)
                .symbolEffect(.pulse)
                .accessibilityLabel("Suivi en direct")
        } else {
            Image(systemName: "clock")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Horaire prévu")
        }
    }
}

/// Une phrase sur un véhicule, `lead` (où il est) puis sa ponctualité, en orange seulement quand il
/// s'écarte de l'horaire ; dessous, en gris, l'âge de sa position quand elle date. Carte d'un passage
/// et bandeau d'un véhicule touché sur la carte.
struct VehicleStatusLines: View {
    let lead: String?
    let vehicle: Shared.Vehicle
    let nowMs: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            sentence
                .font(.subheadline)
                .lineLimit(2)
            if let staleness = vehicle.stalenessLine(nowEpochMs: nowMs) {
                Text(staleness)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var sentence: Text {
        let punctuality = Text(vehicle.delayText)
            .fontWeight(vehicle.isOffSchedule ? .semibold : .regular)
            .foregroundStyle(vehicle.isOffSchedule ? Color.appWarning : Color.secondary)
        guard let lead else { return punctuality }
        return Text("\(lead) · \(punctuality)")
    }
}

/// Où est le véhicule : les derniers arrêts avant celui de l'usager (le plus gros, à droite), le
/// véhicule devant le prochain qu'il dessert, ou sur l'arrêt de l'usager quand il y est.
private struct MiniLine: View {
    /// Arrêts dessinés au plus ; au-delà, la ligne commence par « … ».
    private static let maxStops = 3

    let line: String
    let stopsBefore: Int
    let atStop: Bool
    let vehicleIcon: String

    private var color: Color { LineColorHelper.backgroundColor(for: line) }

    var body: some View {
        HStack(spacing: 0) {
            if stopsBefore > Self.maxStops {
                Text("…")
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
            if !atStop {
                vehicleMark
            }
            ForEach(0..<min(stopsBefore, Self.maxStops), id: \.self) { _ in
                segment
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 9, height: 9)
            }
            segment
            if atStop {
                vehicleMark
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: 3.5)
                    .frame(width: 14, height: 14)
            }
        }
        .frame(height: 22)
        // La phrase qui suit dit la même chose.
        .accessibilityHidden(true)
    }

    private var segment: some View {
        Rectangle()
            .fill(color.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 3)
    }

    private var vehicleMark: some View {
        Image(systemName: vehicleIcon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(LineColorHelper.textColor(for: line))
            .frame(width: 22, height: 22)
            .background(color, in: Circle())
    }
}

// MARK: - Fiche d'un arrêt (passages de tous les quais fusionnés)

struct MergedStopDetailSheet: View {
    let mergedStop: MergedStop
    let stopsVM: TransitStopViewModel
    /// Positions des véhicules, pour dire où est le bus de chaque passage (mises à jour toutes les 15 s).
    @ObservedObject var liveVM: LiveVehiclesViewModel
    /// Appelé quand l'utilisateur veut voir sur la carte les bus d'une ligne dans un sens
    /// (le parent applique le filtre et referme la fiche).
    var onFocus: ((StopLineFocus) -> Void)? = nil
    /// Appelé quand l'utilisateur touche le véhicule d'un passage (le parent le cadre avec l'arrêt).
    var onLocateVehicle: ((Vehicle) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var allPassages: [Passage] = []
    @State private var isLoading = false
    @State private var showWidgetSheet = false
    /// Terminus par ligne et sens, pour déduire le sens d'une destination affichée.
    @State private var termini: [String: String] = [:]
    @State private var timetableRequest: StopTimetableRequest?
    /// Fiches horaires par sens (l'ordre des arrêts), chargées une fois par fiche ouverte ; clé `PassageGroup.key`.
    @State private var timetables: [String: LineTimetable] = [:]
    /// Position de l'arrêt dans la fiche horaire de chaque sens.
    @State private var stopIndexes: [String: [KotlinInt]] = [:]
    @State private var timetableLookups: Set<String> = []
    @State private var approaches: [String: [ApproachingVehicle]] = [:]

    /// Un choix par ligne et par sens pour les widgets : le quai qui sert ce sens, le terminus du sens.
    /// Les sens viennent des dessertes des quais, donc connus même sans passage annoncé.
    private var widgetOptions: [WidgetStop] {
        passageGroups.map { group in
            let stopId = group.stopId.map { Int(truncating: $0) } ?? mergedStop.stops[0].id
            return WidgetStop(stopId: stopId, stopName: mergedStop.nom, line: group.line, direction: group.terminus)
        }
    }

    /// Un groupe par ligne et par sens réel (module partagé) : le sens vient du quai du passage, le
    /// terminus du sens ; une rame qui s'arrête avant reste dans son sens. Les sens desservis sans
    /// passage annoncé sont présents aussi, vides, pour montrer la fiche horaire ; un sens qui ne fait
    /// qu'arriver ici (terminus) n'est pas affiché.
    private var passageGroups: [PassageGroup] {
        allGroups.filter { group in
            guard group.passages.isEmpty, let timetable = timetables[group.key] else { return true }
            return !StopBoard.shared.isArrivalOnly(timetable: timetable, stopIds: stopIds, stopName: mergedStop.nom)
        }
    }

    /// Tous les sens connus, y compris ceux qui ne font qu'arriver ; sert à charger les fiches horaires.
    private var allGroups: [PassageGroup] {
        let dessertes = Dictionary(uniqueKeysWithValues: mergedStop.stops.map { (KotlinInt(value: Int32($0.id)), $0.desserte) })
        return StopPassages.shared.group(passages: allPassages.map(\.shared), dessertes: dessertes, termini: termini)
    }

    private var stopIds: [KotlinInt] { mergedStop.stops.map { KotlinInt(value: Int32($0.id)) } }

    private var commune: String? { mergedStop.stops.map(\.commune).first { !$0.isEmpty } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if isLoading {
                        loadingState
                    } else if passageGroups.isEmpty {
                        emptyState
                    } else {
                        boards
                        if !mergedStop.allLines.isEmpty {
                            widgetButton
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(.ultraThinMaterial)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationDestination(item: $timetableRequest) { request in
                StopTimetableView(source: .request(request))
            }
        }
        .task {
            // Rafraîchit les passages toutes les 30 s tant que la fiche est ouverte
            // (annulé automatiquement à la fermeture du sheet).
            while !Task.isCancelled {
                await loadAllPassages()
                #if DEBUG
                // Modes démo « horaires-arret » / « horaires-course » : ouvrir la fiche horaire de la première ligne.
                if ["horaires-arret", "horaires-course"].contains(DemoShowcase.current ?? ""), timetableRequest == nil, let group = passageGroups.first {
                    timetableRequest = timetableRequest(for: group)
                }
                #endif
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .task {
            termini = (try? await LineTermini.shared.all()) ?? [:]
            loadTimetablesIfNeeded()
        }
        .onChange(of: allPassages) { _, _ in loadTimetablesIfNeeded() }
        .onChange(of: liveVM.vehicles) { _, _ in recomputeApproaches() }
        .sheet(isPresented: $showWidgetSheet) {
            AddToWidgetSheet(stopName: mergedStop.nom, options: widgetOptions)
        }
    }

    @MainActor
    private func loadAllPassages() async {
        // Le spinner ne s'affiche qu'au premier chargement : les refreshs
        // suivants remplacent les données en place, sans clignotement.
        if allPassages.isEmpty { isLoading = true }

        // Charger les passages de TOUS les quais du groupe en parallèle, et afficher dès qu'un
        // quai a répondu : l'attente perçue est celle du plus rapide, pas du plus lent.
        await withTaskGroup(of: Void.self) { group in
            for stop in mergedStop.stops {
                let stopId = stop.id
                group.addTask { @MainActor in
                    await stopsVM.loadAllPassagesForStop(stopId: stopId)
                    mergeLoadedPassages()
                }
            }
        }
        mergeLoadedPassages()
        isLoading = false
    }

    /// Rassemble les passages déjà chargés de tous les quais du groupe, triés par heure.
    @MainActor
    private func mergeLoadedPassages() {
        let ids = Set(mergedStop.stops.map(\.id))
        let passages = stopsVM.transitStops
            .filter { ids.contains($0.id) }
            .flatMap(\.passages)
            .sorted { $0.heurepassage < $1.heurepassage }
        if passages != allPassages { allPassages = passages }
        if !passages.isEmpty { isLoading = false }
    }

    /// Charge l'ordre des arrêts de chaque ligne et sens affichés (une seule requête par sens, gardée en cache).
    private func loadTimetablesIfNeeded() {
        guard !termini.isEmpty || !allPassages.isEmpty else { return }
        for group in allGroups where !timetableLookups.contains(group.key) {
            timetableLookups.insert(group.key)
            Task { @MainActor in
                let timetable = try? await TimetableService.companion.shared.findForStopIds(
                    line: group.line, destination: group.terminus,
                    stopIds: stopIds,
                    stopName: mergedStop.nom, termini: termini
                )
                if let timetable {
                    timetables[group.key] = timetable
                    stopIndexes[group.key] = timetable.stopIndexesForIds(stopIds: stopIds, stopName: mergedStop.nom)
                    recomputeApproaches()
                }
            }
        }
    }

    /// Véhicules en route vers l'arrêt, recalculés à chaque réception de positions, pour les sens dont l'ordre des arrêts est connu.
    private func recomputeApproaches() {
        guard !timetables.isEmpty else { return }
        let lines = Set(timetables.values.map(\.line))
        let candidates = liveVM.vehicles.filter { lines.contains($0.lineName) }.map(\.shared)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var result: [String: [ApproachingVehicle]] = [:]
        for (key, timetable) in timetables {
            let list = StopApproach.shared.approaching(
                vehicles: candidates, timetable: timetable, stopIds: stopIds, stopName: mergedStop.nom,
                nowEpochMs: now, timeZoneId: StopApproach.shared.TIME_ZONE, limit: 3
            )
            if !list.isEmpty { result[key] = list }
        }
        approaches = result
    }

    private func locate(_ approach: ApproachingVehicle) {
        guard let onLocateVehicle, let vehicle = liveVM.vehicles.first(where: { $0.id == approach.vehicle.id }) else { return }
        onLocateVehicle(vehicle)
    }

    private func stopLineFocus(for group: PassageGroup) -> StopLineFocus {
        StopLineFocus(
            line: group.line,
            direction: group.directionCode,
            destination: group.terminus,
            stopName: mergedStop.nom,
            latitude: mergedStop.coordinate.latitude,
            longitude: mergedStop.coordinate.longitude,
            vehicleId: nil
        )
    }

    private func timetableRequest(for group: PassageGroup) -> StopTimetableRequest {
        StopTimetableRequest(
            line: group.line,
            destination: group.terminus,
            stopIds: mergedStop.stops.map(\.id).sorted(),
            stopName: mergedStop.nom
        )
    }

    /// En-tête sur une ligne : le premier passage reste visible sans défiler.
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mergedStop.nom)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let commune {
                        Text(commune)
                    }
                    if mergedStop.pmr {
                        Image(systemName: "figure.roll")
                            .accessibilityLabel("Accessible PMR")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                Task { await loadAllPassages() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rafraîchir les passages")
        }
    }

    /// Une carte par ligne et sens, recalculée chaque seconde : aucun délai ne reste figé entre deux rafraîchissements.
    private var boards: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            VStack(spacing: 10) {
                ForEach(passageGroups, id: \.key) { group in
                    LineBoardCard(
                        board: StopBoard.shared.board(
                            group: group, approaching: approaches[group.key] ?? [], timetable: timetables[group.key],
                            stopIndexes: stopIndexes[group.key] ?? [], nowEpochMs: nowMs, timeZoneId: StopApproach.shared.TIME_ZONE
                        ),
                        nowMs: nowMs,
                        timetableKnown: timetables[group.key] != nil,
                        onLocate: locate,
                        onShowOnMap: onFocus == nil ? nil : { onFocus?(stopLineFocus(for: group)) },
                        onShowTimetable: { timetableRequest = timetableRequest(for: group) }
                    )
                }
            }
        }
    }

    /// Ajout de l'arrêt à un widget, sous les passages : l'essentiel de la fiche reste en haut.
    private var widgetButton: some View {
        Button {
            showWidgetSheet = true
        } label: {
            Label("Ajouter au widget", systemImage: "plus.rectangle.on.rectangle")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(Color.appAccent)
        .padding(.top, 4)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Chargement des passages...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Aucune ligne connue")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Nous ne savons pas encore quelles lignes passent ici. Réessayez dans un instant.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
