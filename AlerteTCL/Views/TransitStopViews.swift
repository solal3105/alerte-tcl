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
                    .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
            )
    }
}

// MARK: - Line Passages Card

struct LinePassagesCard: View {
    let line: String
    let direction: String
    let passages: [Passage]
    /// « Où est mon bus » : véhicules de ce sens qui n'ont pas encore atteint l'arrêt, les plus proches d'abord.
    var approaching: [ApproachingVehicle] = []
    /// Véhicule suivi dans l'activité en direct, s'il y en a un.
    var trackedVehicleId: String? = nil
    /// Montre sur la carte les véhicules de cette ligne dans ce sens.
    var onShowOnMap: (() -> Void)? = nil
    /// Ouvre la fiche horaire théorique de cette ligne à cet arrêt.
    var onShowTimetable: (() -> Void)? = nil
    /// Cadre la carte sur un véhicule en approche.
    var onLocate: ((ApproachingVehicle) -> Void)? = nil
    /// Suit ce véhicule jusqu'à l'arrêt dans l'activité en direct (ou arrête ce suivi).
    var onTrack: ((ApproachingVehicle) -> Void)? = nil
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: line)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ligne header
            HStack {
                LineBadge(line: line, size: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Direction")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(direction)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Liste des passages
            HStack(spacing: 8) {
                ForEach(passages.prefix(4)) { passage in
                    PassageChip(passage: passage, color: bgColor)
                }
            }

            if passages.prefix(4).contains(where: { $0.isTheoretical }) {
                Text("Les horaires sans pastille verte sont théoriques : le véhicule n'est pas suivi en direct, vérifiez les alertes en cas de perturbation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !approaching.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Où est mon bus", systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(approaching, id: \.vehicle.id) { approach in
                        ApproachRow(
                            approach: approach,
                            lineColor: bgColor,
                            lineTextColor: LineColorHelper.textColor(for: line),
                            isTracked: trackedVehicleId == approach.vehicle.id,
                            onLocate: onLocate.map { locate in { locate(approach) } },
                            onTrack: onTrack.map { track in { track(approach) } }
                        )
                    }
                    Text(StopApproach.shared.NOTE)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if onShowOnMap != nil || onShowTimetable != nil {
                HStack(spacing: 8) {
                    if let onShowOnMap, let label = TransportMode.detectFromLine(line).shared.showOnMapLabel {
                        cardAction(label, icon: "map", action: onShowOnMap)
                    }
                    if let onShowTimetable {
                        cardAction("Tous les horaires", icon: "calendar", action: onShowTimetable)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(bgColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: bgColor.opacity(0.1), radius: 6, x: 0, y: 2)
    }
}

extension LinePassagesCard {
    private func cardAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(bgColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

// MARK: - Où est mon bus

/// Un véhicule en approche : arrêts restants, âge de la position, heure estimée, bouton de suivi.
struct ApproachRow: View {
    let approach: ApproachingVehicle
    let lineColor: Color
    let lineTextColor: Color
    let isTracked: Bool
    var onLocate: (() -> Void)? = nil
    var onTrack: (() -> Void)? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            HStack(alignment: .center, spacing: 10) {
                Button(action: { onLocate?() }) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(approach.stopsText)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                Spacer(minLength: 6)
                                if let arrival = approach.arrivalText(nowEpochMs: nowMs) {
                                    Text(arrival)
                                        .font(.subheadline.weight(.bold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .fixedSize()
                                } else {
                                    Text("Heure inconnue")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text(approach.positionText(nowEpochMs: nowMs))
                                    .font(.caption2)
                                    .foregroundStyle(Color(token: approach.vehicle.positionFreshness(nowEpochMs: nowMs).color))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 6)
                                if let time = approach.estimatedTime(timeZoneId: StopApproach.shared.TIME_ZONE) {
                                    Text("≈ \(time)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .fixedSize()
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Voir ce bus sur la carte")

                if let onTrack, BusTrackingController.isSupported {
                    Button(action: onTrack) {
                        Image(systemName: isTracked ? "bell.badge.fill" : "bell")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isTracked ? lineTextColor : Color.primary)
                            .frame(width: 32, height: 32)
                            .background(isTracked ? lineColor : Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isTracked ? "Arrêter le suivi de ce bus" : "Suivre ce bus jusqu'à l'arrêt")
                }
            }
        }
    }
}

// MARK: - Passage Chip

struct PassageChip: View {
    let passage: Passage
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            // Délai en minutes, pastille verte = suivi temps réel du véhicule
            HStack(spacing: 3) {
                if passage.isRealTime {
                    Circle()
                        .fill(Color.appSuccess)
                        .frame(width: 5, height: 5)
                }
                Text(passage.delaipassage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(.systemGray))
            }

            // Heure de passage
            Text(passage.formattedTime)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(passage.isTheoretical ? 0.65 : 1)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

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
    @ObservedObject private var tracker = BusTrackingController.shared
    @State private var allPassages: [Passage] = []
    @State private var isLoading = false
    @State private var showWidgetSheet = false
    /// Terminus par ligne et sens, pour déduire le sens d'une destination affichée.
    @State private var termini: [String: String] = [:]
    @State private var timetableRequest: StopTimetableRequest?
    /// Fiches horaires par ligne et sens (l'ordre des arrêts), chargées une fois par fiche ouverte.
    @State private var timetables: [LineDirectionKey: LineTimetable] = [:]
    @State private var timetableLookups: Set<LineDirectionKey> = []
    @State private var approaches: [LineDirectionKey: [ApproachingVehicle]] = [:]
    
    /// Clé unique pour grouper par ligne ET direction
    private struct LineDirectionKey: Hashable {
        let line: String
        let direction: String
    }
    
    private var availableLineDirections: [WidgetLineDirection] {
        sortedLineDirections.map { key in
            let stopId = passagesByLineDirection[key]?.first?.stopId ?? mergedStop.stops[0].id
            return WidgetLineDirection(stopId: stopId, line: key.line, direction: key.direction, terminusName: key.direction)
        }
    }
    
    private var passagesByLineDirection: [LineDirectionKey: [Passage]] {
        Dictionary(grouping: allPassages) { LineDirectionKey(line: $0.ligne, direction: $0.direction) }
    }
    
    private var sortedLineDirections: [LineDirectionKey] {
        passagesByLineDirection.keys.sorted { key1, key2 in
            let mode1 = TransportMode.detectFromLine(key1.line)
            let mode2 = TransportMode.detectFromLine(key2.line)
            if mode1.sortOrder != mode2.sortOrder {
                return mode1.sortOrder < mode2.sortOrder
            }
            if key1.line != key2.line {
                return key1.line < key2.line
            }
            return key1.direction < key2.direction
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    
                    if isLoading {
                        loadingState
                    } else if allPassages.isEmpty {
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
                if ["horaires-arret", "horaires-course"].contains(DemoShowcase.current ?? ""), timetableRequest == nil, let key = sortedLineDirections.first {
                    timetableRequest = timetableRequest(for: key)
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
            AddToWidgetSheet(
                stopName: mergedStop.nom,
                availableLineDirections: availableLineDirections
            )
        }
    }
    
    @MainActor
    private func loadAllPassages() async {
        // Le spinner ne s'affiche qu'au premier chargement : les refreshs
        // suivants remplacent les données en place, sans clignotement.
        if allPassages.isEmpty { isLoading = true }

        // Charger les passages de TOUS les arrêts du groupe en parallèle
        await withTaskGroup(of: Void.self) { group in
            for stop in mergedStop.stops {
                let stopId = stop.id
                group.addTask { @MainActor in
                    await stopsVM.loadAllPassagesForStop(stopId: stopId)
                }
            }
        }

        // Collecter tous les passages
        var passages: [Passage] = []
        for stop in mergedStop.stops {
            if let updatedStop = stopsVM.transitStops.first(where: { $0.id == stop.id }) {
                passages.append(contentsOf: updatedStop.passages)
            }
        }

        // Trier par heure et dédupliquer
        allPassages = passages.sorted { p1, p2 in
            p1.heurepassage < p2.heurepassage
        }

        isLoading = false
    }
    
    /// Charge l'ordre des arrêts de chaque ligne et sens affichés (une seule requête par sens, gardée en cache).
    private func loadTimetablesIfNeeded() {
        guard !termini.isEmpty || !allPassages.isEmpty else { return }
        for key in sortedLineDirections where !timetableLookups.contains(key) {
            timetableLookups.insert(key)
            Task { @MainActor in
                let timetable = try? await TimetableService.companion.shared.findForStopIds(
                    line: key.line, destination: key.direction,
                    stopIds: mergedStop.stops.map { KotlinInt(value: Int32($0.id)) },
                    stopName: mergedStop.nom, termini: termini
                )
                if let timetable {
                    timetables[key] = timetable
                    recomputeApproaches()
                }
            }
        }
    }

    /// « Où est mon bus » : recalculé à chaque réception de positions, pour les sens dont l'ordre des arrêts est connu.
    private func recomputeApproaches() {
        guard !timetables.isEmpty else { return }
        let lines = Set(timetables.keys.map(\.line))
        let candidates = liveVM.vehicles.filter { lines.contains($0.lineName) }.map(\.shared)
        let stopIds = mergedStop.stops.map { KotlinInt(value: Int32($0.id)) }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var result: [LineDirectionKey: [ApproachingVehicle]] = [:]
        for (key, timetable) in timetables {
            let list = StopApproach.shared.approaching(
                vehicles: candidates, timetable: timetable, stopIds: stopIds, stopName: mergedStop.nom,
                nowEpochMs: now, timeZoneId: StopApproach.shared.TIME_ZONE, limit: 3
            )
            if !list.isEmpty { result[key] = list }
        }
        approaches = result
        #if DEBUG
        // Mode démo « suivi » : suivre le premier bus en approche dès qu'il est connu.
        if DemoShowcase.current == "suivi", tracker.trackedVehicleId == nil,
           let key = sortedLineDirections.first(where: { result[$0] != nil }), let first = result[key]?.first {
            track(first, key: key)
        }
        #endif
    }

    private func locate(_ approach: ApproachingVehicle) {
        guard let onLocateVehicle, let vehicle = liveVM.vehicles.first(where: { $0.id == approach.vehicle.id }) else { return }
        onLocateVehicle(vehicle)
    }

    private func track(_ approach: ApproachingVehicle, key: LineDirectionKey) {
        if tracker.trackedVehicleId == approach.vehicle.id {
            tracker.cancel()
            return
        }
        guard let vehicle = liveVM.vehicles.first(where: { $0.id == approach.vehicle.id }), let timetable = timetables[key] else { return }
        tracker.start(vehicle: vehicle, approach: approach, stop: mergedStop, timetable: timetable, liveVM: liveVM)
    }

    private func stopLineFocus(for key: LineDirectionKey) -> StopLineFocus {
        StopLineFocus(
            line: key.line,
            direction: DirectionMatching.shared.resolveDirection(line: key.line, destination: key.direction, termini: termini),
            destination: key.direction,
            stopName: mergedStop.nom,
            latitude: mergedStop.coordinate.latitude,
            longitude: mergedStop.coordinate.longitude,
            vehicleId: nil
        )
    }

    private func timetableRequest(for key: LineDirectionKey) -> StopTimetableRequest {
        StopTimetableRequest(
            line: key.line,
            destination: key.direction,
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
    
    private var passagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Prochains passages", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(Color.appAccent)
            
            ForEach(sortedLineDirections, id: \.self) { key in
                if let linePassages = passagesByLineDirection[key] {
                    LinePassagesCard(
                        line: key.line,
                        direction: key.direction,
                        passages: linePassages,
                        approaching: approaches[key] ?? [],
                        trackedVehicleId: tracker.trackedVehicleId,
                        onShowOnMap: onFocus.map { focus in { focus(stopLineFocus(for: key)) } },
                        onShowTimetable: { timetableRequest = timetableRequest(for: key) },
                        onLocate: onLocateVehicle == nil ? nil : { approach in locate(approach) },
                        onTrack: { approach in track(approach, key: key) }
                    )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
            
            Text("Aucun passage prévu")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Les horaires seront affichés quand des véhicules seront en approche")
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

