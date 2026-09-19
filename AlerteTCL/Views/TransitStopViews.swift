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

// MARK: - Prochains passages : une ligne par sens

/// Un sens d'une ligne à cet arrêt : le terminus, les trois prochains passages, et au toucher les
/// détails (où est mon bus, voir sur la carte, tous les horaires). Sans passage annoncé, les
/// prochains départs de la fiche horaire prennent le relais.
struct PassageGroupRow: View {
    let group: PassageGroup
    let expanded: Bool
    /// « Où est mon bus » : véhicules de ce sens qui n'ont pas encore atteint l'arrêt, les plus proches d'abord.
    var approaching: [ApproachingVehicle] = []
    /// Vrai quand l'ordre des arrêts du sens est connu : sans bus en approche, la ligne le dit au lieu de se taire.
    var approachKnown: Bool = false
    /// Prochains départs théoriques, affichés seulement quand aucun passage n'est annoncé.
    var next: NextDepartures? = nil
    let onToggle: () -> Void
    var onShowOnMap: (() -> Void)? = nil
    var onShowTimetable: (() -> Void)? = nil
    var onLocate: ((ApproachingVehicle) -> Void)? = nil

    private var lineColor: Color { LineColorHelper.backgroundColor(for: group.line) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    LineBadge(line: group.line, size: 14)
                    Text(group.terminus)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !group.passages.isEmpty {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(group.passages.prefix(3).enumerated()), id: \.element.id) { index, passage in
                        cell(passage.delaipassage, first: index == 0, live: passage.isRealTime,
                             caption: group.shortDestination(passage: passage).map { "jusqu'à \($0)" })
                    }
                    Spacer(minLength: 0)
                }
            } else if let next {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(next.departures.prefix(3).enumerated()), id: \.element.tripIndex) { index, departure in
                        cell(departure.time, first: index == 0, live: false,
                             caption: next.isTomorrow ? TimetableNext.shared.CAPTION_TOMORROW : TimetableNext.shared.CAPTION_TODAY)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text(approachKnown ? TimetableNext.shared.NONE_PLANNED : "Aucun passage annoncé pour l'instant.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if expanded {
                details
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.2), value: expanded)
    }

    /// Délai ou heure en chiffres, point vert quand le véhicule est suivi en direct, légende en dessous
    /// (destination courte d'un passage, « prévu » ou « demain » d'un départ théorique).
    private func cell(_ value: String, first: Bool, live: Bool, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if live {
                    Circle().fill(Color.appSuccess).frame(width: 6, height: 6)
                }
                Text(value)
                    .font(.system(size: first ? 17 : 15, weight: first ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(first ? Color.primary : Color.secondary)
                    .monospacedDigit()
            }
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !approaching.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Où est mon bus")
                        .font(.subheadline.weight(.semibold))
                    ForEach(approaching, id: \.vehicle.id) { approach in
                        ApproachRow(approach: approach, lineColor: lineColor,
                                    onLocate: onLocate.map { locate in { locate(approach) } })
                    }
                }
            } else if approachKnown, TransportMode.detectFromLine(group.line).shared.showOnMapLabel != nil {
                Text(StopApproach.shared.NONE_APPROACHING)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let onShowOnMap, let label = TransportMode.detectFromLine(group.line).shared.showOnMapLabel {
                    action(label, icon: "map", perform: onShowOnMap)
                }
                if let onShowTimetable {
                    action("Tous les horaires", icon: "calendar", perform: onShowTimetable)
                }
            }
        }
        .padding(.top, 2)
    }

    /// Action de la ligne : un lien sobre à l'accent, pictogramme puis texte, sans fond.
    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Où est mon bus

/// Un véhicule en approche : deux grands chiffres (arrêts restants, heure estimée) et une ligne sur l'âge
/// de la position. Toucher la carte montre le bus sur la carte.
struct ApproachRow: View {
    let approach: ApproachingVehicle
    let lineColor: Color
    var onLocate: (() -> Void)? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            VStack(alignment: .leading, spacing: 10) {
                Button(action: { onLocate?() }) {
                    HStack(alignment: .top, spacing: 16) {
                        stat(value: approach.stopsValue, caption: approach.stopsCaption, color: .primary)
                        stat(
                            value: approach.estimatedTime(timeZoneId: StopApproach.shared.TIME_ZONE).map { "≈ \($0)" } ?? "—",
                            caption: approach.arrivalText(nowEpochMs: nowMs) ?? "heure inconnue",
                            color: Color.appAccent
                        )
                        Spacer(minLength: 24)
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Voir ce bus sur la carte")

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(token: approach.vehicle.positionFreshness(nowEpochMs: nowMs).color))
                        .frame(width: 7, height: 7)
                    Text(approach.freshnessLine(nowEpochMs: nowMs))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(lineColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func stat(value: String, caption: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
    }
}

// MARK: - Passage Chip

// MARK: - Merged Stop Detail Sheet (affiche les passages de TOUS les arrêts fusionnés)

struct MergedStopDetailSheet: View {
    let mergedStop: MergedStop
    let stopsVM: TransitStopViewModel
    /// Positions des véhicules, pour « où est mon bus » (mises à jour toutes les 15 s).
    @ObservedObject var liveVM: LiveVehiclesViewModel
    /// Appelé quand l'utilisateur veut voir sur la carte les bus d'une ligne dans un sens
    /// (le parent applique le filtre et referme la fiche).
    var onFocus: ((StopLineFocus) -> Void)? = nil
    /// Appelé quand l'utilisateur touche un véhicule en approche (le parent le cadre avec l'arrêt).
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
    @State private var timetableLookups: Set<String> = []
    @State private var approaches: [String: [ApproachingVehicle]] = [:]
    /// Sens dépliés dans la liste des prochains passages.
    @State private var expandedGroups: Set<String> = []
    
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
            return !TimetableNext.shared.isArrivalOnly(timetable: timetable, stopIds: stopIds, stopName: mergedStop.nom)
        }
    }

    /// Tous les sens connus, y compris ceux qui ne font qu'arriver ; sert à charger les fiches horaires.
    private var allGroups: [PassageGroup] {
        let dessertes = Dictionary(uniqueKeysWithValues: mergedStop.stops.map { (KotlinInt(value: Int32($0.id)), $0.desserte) })
        return StopPassages.shared.group(passages: allPassages.map(\.shared), dessertes: dessertes, termini: termini)
    }

    private var stopIds: [KotlinInt] { mergedStop.stops.map { KotlinInt(value: Int32($0.id)) } }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    
                    if isLoading {
                        loadingState
                    } else if passageGroups.isEmpty {
                        emptyState
                    } else {
                        passagesSection
                    }
                }
                .padding(20)
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
                    recomputeApproaches()
                }
            }
        }
    }

    /// « Où est mon bus » : recalculé à chaque réception de positions, pour les sens dont l'ordre des arrêts est connu.
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

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icône (même style que TransitStopDetailSheet)
            Image(systemName: "tram.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.appAccent)
                .padding(16)
                .background(Color.appAccent.opacity(0.1))
                .clipShape(Circle())
            
            // Nom de l'arrêt
            Text(mergedStop.nom)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Lignes desservies
            if !mergedStop.allLines.isEmpty {
                HStack(spacing: 6) {
                    ForEach(mergedStop.allLines.prefix(6), id: \.self) { line in
                        LineBadge(line: line)
                    }
                    if mergedStop.allLines.count > 6 {
                        Text("+\(mergedStop.allLines.count - 6)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Accessibilité PMR
            if mergedStop.pmr {
                HStack(spacing: 4) {
                    Image(systemName: "figure.roll")
                        .foregroundStyle(Color.appAccent)
                    Text("Accessible PMR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Bouton Ajouter au widget
            if !isLoading && !mergedStop.allLines.isEmpty {
                Button {
                    showWidgetSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Ajouter au widget")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    /// Une ligne par sens, dans une carte sobre ; un toucher déplie les détails du sens.
    private var passagesSection: some View {
        let groups = passageGroups
        return VStack(alignment: .leading, spacing: 12) {
            Text("Prochains passages")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.key) { index, group in
                    PassageGroupRow(
                        group: group,
                        expanded: expandedGroups.contains(group.key),
                        approaching: approaches[group.key] ?? [],
                        approachKnown: timetables[group.key] != nil,
                        next: group.passages.isEmpty ? nextDepartures(for: group) : nil,
                        onToggle: {
                            if expandedGroups.contains(group.key) { expandedGroups.remove(group.key) } else { expandedGroups.insert(group.key) }
                        },
                        onShowOnMap: onFocus.map { focus in { focus(stopLineFocus(for: group)) } },
                        onShowTimetable: { timetableRequest = timetableRequest(for: group) },
                        onLocate: onLocateVehicle == nil ? nil : { approach in locate(approach) }
                    )
                    if index < groups.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("Un point vert marque un passage suivi en direct ; les autres suivent l'horaire prévu. Sans passage annoncé, les heures viennent de la fiche horaire.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    /// Prochains départs de la fiche horaire d'un sens sans passage annoncé (le soir, une ligne peu fréquente).
    private func nextDepartures(for group: PassageGroup) -> NextDepartures? {
        guard let timetable = timetables[group.key] else { return nil }
        return TimetableNext.shared.upcoming(
            timetable: timetable,
            stopIds: stopIds,
            stopName: mergedStop.nom,
            nowEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
            timeZoneId: StopApproach.shared.TIME_ZONE,
            limit: 3
        )
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

