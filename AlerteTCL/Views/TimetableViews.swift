import SwiftUI
import Shared

// Fiches horaires théoriques : horaires d'une ligne à un arrêt, détail d'une course,
// recherche d'une ligne depuis la carte. Données : TimetableService (cf. horaires/README.md).
// Les couleurs de ligne viennent de la palette officielle (LineColorHelper, alimenté par l'index).

// MARK: - Sources

/// Fiche horaire demandée depuis la carte « ligne + destination » de la fiche d'un arrêt.
struct StopTimetableRequest: Hashable, Identifiable {
    let line: String
    let destination: String
    let stopIds: [Int]
    let stopName: String

    var id: String { "\(line)|\(destination)|\(stopName)" }
}

/// Ce qu'une vue d'horaires à un arrêt reçoit : une demande à résoudre, ou une fiche déjà chargée.
/// Identifiée par ligne, sens et arrêt : la navigation n'a pas besoin de comparer la fiche entière.
enum StopTimetableSource: Identifiable, Hashable {
    case request(StopTimetableRequest)
    case timetable(LineTimetable, stopIndexes: [Int], stopName: String)

    var id: String {
        switch self {
        case .request(let request): return request.id
        case .timetable(let timetable, let stopIndexes, _): return "\(timetable.key)|\(timetable.dir)|\(stopIndexes)"
        }
    }

    static func == (lhs: StopTimetableSource, rhs: StopTimetableSource) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct TimetableTripSelection: Identifiable, Hashable {
    let tripIndex: Int
    let stopIndex: Int
    var id: String { "\(tripIndex)-\(stopIndex)" }
}

// MARK: - Mise en forme commune

private enum TimetableFormat {
    /// Dates en français quelle que soit la langue du téléphone, comme le reste de l'application.
    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM yyyy"
        return f
    }()

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func longDate(_ date: Date, capitalized: Bool = true) -> String {
        let text = longDate.string(from: date)
        return capitalized ? text.prefix(1).uppercased() + text.dropFirst() : text
    }

    static func longDate(iso: String) -> String {
        guard let date = isoDay.date(from: iso) else { return iso }
        return longDate(date, capitalized: false)
    }

    static func iso(_ date: Date) -> String { isoDay.string(from: date) }

    static func date(iso: String) -> Date? { isoDay.date(from: iso) }

    /// Journée de service courante (avant 4 h du matin, la veille), calculée par le module partagé.
    /// Journée de service courante au format `yyyy-MM-dd`.
    static func serviceDateIso() -> String { iso(serviceDate()) }

    static func serviceDate() -> Date {
        let iso = TimetableTime.shared.serviceDateIso(epochMillis: Int64(Date().timeIntervalSince1970 * 1000), timeZoneId: TimeZone.current.identifier)
        return date(iso: iso) ?? Calendar.current.startOfDay(for: Date())
    }

    static func serviceMinutes() -> Int {
        Int(TimetableTime.shared.serviceMinutes(epochMillis: Int64(Date().timeIntervalSince1970 * 1000), timeZoneId: TimeZone.current.identifier))
    }

    static func kotlinInts(_ values: [Int]) -> [KotlinInt] { values.map { KotlinInt(int: Int32($0)) } }

    /// Libellé du mode de transport tel que l'index le nomme (metro, tram, bus…).
    static func modeLabel(_ mode: String) -> String {
        switch mode {
        case "metro": return "Métro"
        case "funicular": return "Funiculaire"
        case "tram": return "Tramway"
        case "trambus": return "Trambus"
        case "trolleybus": return "Trolleybus"
        case "ferry": return "Navette fluviale"
        default: return "Bus"
        }
    }
}

/// Carte d'en-tête : badge de la ligne, titre, sous-titre et contenu libre (date, filtres).
private struct LineHeaderCard<Content: View>: View {
    let line: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(line: String, title: String, subtitle: String, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.line = line
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(LineColorHelper.backgroundColor(for: line))
                .frame(height: 4)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    LineBadge(line: line, size: line.count > 3 ? 13 : 17)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                content
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Point sur le rail d'une ligne (détail d'une course, liste des arrêts).
private struct TimelineDot: View {
    let accent: Color
    let isEnd: Bool
    let highlighted: Bool
    let showAbove: Bool
    let showBelow: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(showAbove ? accent.opacity(0.35) : .clear).frame(width: 3)
                Rectangle().fill(showBelow ? accent.opacity(0.35) : .clear).frame(width: 3)
            }
            let size: CGFloat = highlighted ? 16 : (isEnd ? 13 : 10)
            Circle()
                .fill(highlighted || isEnd ? accent : Color(.secondarySystemGroupedBackground))
                .overlay(Circle().strokeBorder(accent.opacity(highlighted || isEnd ? 0 : 0.7), lineWidth: 2))
                .frame(width: size, height: size)
        }
        .frame(width: 20, height: 48)
    }
}

private struct Pill: View {
    let text: String
    let background: Color
    let foreground: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
    }
}

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

private struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

/// Avertissement quand les fiches n'ont pas pu être renouvelées (même texte que sur Android).
private struct StaleNotice: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.appWarning)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appWarning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct UnavailableView: View {
    let message: String
    let retry: (() -> Void)?
    var body: some View {
        ContentUnavailableView {
            Label("Horaires indisponibles", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Réessayer", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Horaires d'une ligne à un arrêt

struct StopTimetableView: View {
    let source: StopTimetableSource

    @State private var timetable: LineTimetable?
    @State private var stopIndexes: [Int] = []
    @State private var stopName = ""
    @State private var date = TimetableFormat.serviceDate()
    @State private var isLoading = true
    @State private var unavailableMessage: String?
    @State private var canRetry = false
    @State private var selectedTrip: TimetableTripSelection?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Chargement des horaires…")
            } else if let message = unavailableMessage {
                UnavailableView(message: message, retry: canRetry ? { Task { await load() } } : nil)
            } else if let timetable {
                TimetableDayList(timetable: timetable, stopIndexes: stopIndexes, stopName: stopName, date: $date) { departure in
                    selectedTrip = TimetableTripSelection(tripIndex: Int(departure.tripIndex), stopIndex: Int(departure.stopIndex))
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Horaires")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .navigationDestination(item: $selectedTrip) { selection in
            if let timetable {
                TripDetailView(timetable: timetable, tripIndex: selection.tripIndex, highlightedStopIndex: selection.stopIndex)
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        unavailableMessage = nil
        canRetry = false
        defer { isLoading = false }

        switch source {
        case .timetable(let loaded, let indexes, let name):
            timetable = loaded
            stopIndexes = indexes
            stopName = name
        case .request(let request):
            stopName = request.stopName
            do {
                let termini = (try? await LineTermini.shared.all()) ?? [:]
                guard let found = try await TimetableService.companion.shared.findForStopIds(
                    line: request.line,
                    destination: request.destination,
                    stopIds: TimetableFormat.kotlinInts(request.stopIds),
                    stopName: request.stopName,
                    termini: termini
                ) else {
                    unavailableMessage = "La ligne \(request.line) n'a pas de fiche horaire publiée."
                    return
                }
                let indexes = found.stopIndexesForIds(stopIds: TimetableFormat.kotlinInts(request.stopIds), stopName: request.stopName).map { $0.intValue }
                guard !indexes.isEmpty else {
                    unavailableMessage = "L'arrêt \(request.stopName) n'apparaît pas dans la fiche horaire de la ligne \(request.line) vers \(request.destination)."
                    return
                }
                timetable = found
                stopIndexes = indexes
            } catch {
                unavailableMessage = "Impossible de charger les horaires pour le moment."
                canRetry = true
                AppLogger.debug("⚠️ Fiche horaire \(request.line) : \(error.localizedDescription)")
            }
        }
        if let timetable, !timetable.isValidOn(isoDate: TimetableFormat.iso(date)) {
            // Fiche périmée : on montre le dernier jour connu, avec un avertissement dans la liste.
            let fallback = timetable.isStaleOn(isoDate: TimetableFormat.iso(date)) ? timetable.validTo : timetable.validFrom
            if let day = TimetableFormat.date(iso: fallback) { date = day }
        }
        #if DEBUG
        // Mode démo « horaires-course » : ouvrir le détail du prochain passage, une fois la transition finie.
        if DemoShowcase.current == "horaires-course", let timetable,
           let next = timetable.departures(stopIndexes: TimetableFormat.kotlinInts(stopIndexes), isoDate: TimetableFormat.iso(date))
               .first(where: { Int($0.minutes) >= TimetableFormat.serviceMinutes() }) {
            try? await Task.sleep(nanoseconds: DemoShowcase.pushDelayNanoseconds)
            selectedTrip = TimetableTripSelection(tripIndex: Int(next.tripIndex), stopIndex: Int(next.stopIndex))
        }
        #endif
    }
}

/// Liste des passages d'une journée, groupés par heure, avec le choix du jour.
private struct TimetableDayList: View {
    let timetable: LineTimetable
    let stopIndexes: [Int]
    let stopName: String
    @Binding var date: Date
    let onSelect: (TimetableDeparture) -> Void

    @State private var showPicker = false

    private struct HourGroup: Identifiable {
        let hour: Int
        let departures: [TimetableDeparture]
        var id: Int { hour }
    }

    private var accent: Color { LineColorHelper.backgroundColor(for: timetable.line) }

    private var departures: [TimetableDeparture] {
        timetable.departures(stopIndexes: TimetableFormat.kotlinInts(stopIndexes), isoDate: TimetableFormat.iso(date))
    }

    private var validRange: ClosedRange<Date> {
        let from = TimetableFormat.date(iso: timetable.validFrom) ?? date
        let to = TimetableFormat.date(iso: timetable.validTo) ?? date
        return from...max(from, to)
    }

    private var hourGroups: [HourGroup] {
        var groups: [HourGroup] = []
        for departure in departures {
            let hour = Int(departure.minutes) / 60
            if let last = groups.indices.last, groups[last].hour == hour {
                groups[last] = HourGroup(hour: hour, departures: groups[last].departures + [departure])
            } else {
                groups.append(HourGroup(hour: hour, departures: [departure]))
            }
        }
        return groups
    }

    /// Le jour affiché est la journée de service en cours : on distingue passé et prochain passage.
    private var isServiceDay: Bool {
        Calendar.current.isDate(date, inSameDayAs: TimetableFormat.serviceDate())
    }

    private var nowMinutes: Int { TimetableFormat.serviceMinutes() }

    private var nextDepartureID: String? {
        guard isServiceDay else { return nil }
        return departures.first { Int($0.minutes) >= nowMinutes }?.rowID
    }

    private var hasAfterMidnight: Bool {
        departures.contains { TimetableTime.shared.isAfterMidnight(minutes: $0.minutes) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // L'en-tête reste visible : la liste seule défile jusqu'au prochain passage.
            header
                .padding(.bottom, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                    if timetable.isStaleOn(isoDate: TimetableFormat.serviceDateIso()) {
                        StaleNotice(text: TimetableTexts.shared.staleNotice(validToLong: TimetableFormat.longDate(iso: timetable.validTo)))
                    }
                    if departures.isEmpty {
                        Text("Aucun passage prévu ce jour-là à cet arrêt.")
                            .foregroundStyle(.secondary)
                            .padding(20)
                    }

                    ForEach(hourGroups) { group in
                        SectionLabel(text: hourLabel(group.hour))
                        ForEach(group.departures, id: \.rowID) { departure in
                            departureRow(departure)
                                .id(departure.rowID)
                        }
                    }

                    notes
                    }
                    .padding(.bottom, 24)
                }
                .onAppear { scrollToNext(proxy) }
                .onChange(of: date) { _, _ in scrollToNext(proxy) }
            }
        }
    }

    private var header: some View {
        LineHeaderCard(line: timetable.line, title: "Vers \(timetable.headsign)", subtitle: "Arrêt \(stopName)") {
            VStack(alignment: .leading, spacing: 10) {
                Text(TimetableFormat.longDate(date))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    dayChip("Aujourd'hui", offset: 0)
                    dayChip("Demain", offset: 1)
                    Button {
                        withAnimation { showPicker.toggle() }
                    } label: {
                        Label("Autre jour", systemImage: "calendar")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(showPicker ? accent.opacity(0.18) : Color(.systemGray5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if showPicker {
                    DatePicker(
                        "Jour",
                        selection: $date,
                        in: validRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .tint(accent)
                }
            }
        }
    }

    private func dayChip(_ title: String, offset: Int) -> some View {
        let target = Calendar.current.date(byAdding: .day, value: offset, to: TimetableFormat.serviceDate()) ?? date
        let isSelected = Calendar.current.isDate(target, inSameDayAs: date)
        let isAvailable = timetable.isValidOn(isoDate: TimetableFormat.iso(target))
        return Button {
            date = target
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? accent.opacity(0.18) : Color(.systemGray5), in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? accent.opacity(0.6) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
    }

    private func departureRow(_ departure: TimetableDeparture) -> some View {
        let isPast = isServiceDay && Int(departure.minutes) < nowMinutes
        let isNext = departure.rowID == nextDepartureID
        let textColor: Color = isNext ? accent : (isPast ? .secondary : .primary)
        return VStack(spacing: 0) {
            Button {
                onSelect(departure)
            } label: {
                HStack(spacing: 10) {
                    Text(departure.time)
                        .font(.system(size: 17, weight: isNext ? .bold : .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(textColor)
                    if departure.terminus != timetable.headsign {
                        Text("vers \(departure.terminus)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if departure.isTerminus {
                        Pill(text: "arrivée", background: Color(.systemGray5), foreground: .secondary)
                    }
                    if isNext {
                        Pill(text: "prochain", background: accent, foreground: LineColorHelper.textColor(for: timetable.line))
                    }
                    Chevron()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 11)
                .background(isNext ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 20).padding(.trailing, 12)
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Horaires théoriques publiés par SYTRAL, connus jusqu'au \(TimetableFormat.longDate(iso: timetable.validTo)). Ils ne tiennent pas compte des perturbations du jour : consultez les alertes trafic.")
            if hasAfterMidnight {
                Text("Les passages après minuit sont rattachés à la journée de service de la veille.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func hourLabel(_ hour: Int) -> String {
        hour < 24 ? "\(hour) h" : "\(hour - 24) h, après minuit"
    }

    private func scrollToNext(_ proxy: ScrollViewProxy) {
        guard let target = nextDepartureID ?? departures.first?.rowID else { return }
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(target, anchor: .center) }
        }
    }
}

// MARK: - Détail d'une course

struct TripDetailView: View {
    let timetable: LineTimetable
    let tripIndex: Int
    let highlightedStopIndex: Int?

    private var calls: [TimetableCall] { timetable.calls(tripIndex: Int32(tripIndex)) }
    private var accent: Color { LineColorHelper.backgroundColor(for: timetable.line) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                LineHeaderCard(
                    line: timetable.line,
                    title: calls.last.map { "Vers \($0.stop.name)" } ?? "Course \(timetable.line)",
                    subtitle: calls.first.map { "Départ à \($0.time) de \($0.stop.name)" } ?? ""
                )
                SectionLabel(text: "Arrêts desservis")
                ForEach(calls, id: \.position) { call in
                    let highlighted = Int(call.stopIndex) == highlightedStopIndex
                    let isFirst = call.position == 0
                    let isLast = Int(call.position) == calls.count - 1
                    HStack(spacing: 0) {
                        Text(call.time)
                            .font(.system(size: 15, weight: highlighted ? .bold : .regular, design: .rounded).monospacedDigit())
                            .foregroundStyle(highlighted ? accent : .primary)
                            .frame(width: 56, alignment: .leading)
                        TimelineDot(accent: accent, isEnd: isFirst || isLast, highlighted: highlighted, showAbove: !isFirst, showBelow: !isLast)
                        Text(call.stop.name)
                            .font(.subheadline.weight(highlighted || isFirst || isLast ? .semibold : .regular))
                            .foregroundStyle(highlighted ? accent : .primary)
                            .padding(.horizontal, 12)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Course \(timetable.line)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Recherche d'une ligne (bouton « Fiches horaires » de la carte)

struct TimetableSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var favoritesService = FavoriteLinesService.shared
    @State private var index: TimetableIndex?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var searchText = ""
    @State private var selectedLine: TimetableLineSummary?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chargement des lignes…")
                } else if loadFailed {
                    UnavailableView(message: "Impossible de charger la liste des lignes pour le moment.") {
                        Task { await load() }
                    }
                } else if let index {
                    lineList(index)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fiches horaires")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(item: $selectedLine) { line in
                if line.directions.count == 1, let only = line.directions.first {
                    LineStopsView(line: line.line, direction: only)
                } else {
                    LineDirectionsView(line: line)
                }
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let loaded = try await TimetableService.companion.shared.fetchIndex()
            index = loaded
            #if DEBUG
            // Modes démo « horaires-ligne » / « horaires-arrets » : ouvrir directement une ligne à deux sens.
            if ["horaires-ligne", "horaires-arrets"].contains(DemoShowcase.current ?? "") {
                try? await Task.sleep(nanoseconds: DemoShowcase.pushDelayNanoseconds)
                selectedLine = loaded.lines.first { $0.directions.count == 2 }
            }
            #endif
        } catch {
            loadFailed = true
            AppLogger.debug("⚠️ Index des fiches horaires : \(error.localizedDescription)")
        }
    }

    private struct ModeGroup: Identifiable {
        let mode: String
        let lines: [TimetableLineSummary]
        var id: String { mode }
    }

    private func lineList(_ index: TimetableIndex) -> some View {
        let filtered = index.lines.filter(matchesSearch)
        let favorites = filtered.filter { favoritesService.isFavorite($0.line) }
        let others = filtered.filter { !favoritesService.isFavorite($0.line) }
        // Lignes groupées par mode, dans l'ordre de l'index (métro, funiculaire, tram, bus…)
        var groups: [ModeGroup] = []
        for line in others {
            if let last = groups.indices.last, groups[last].mode == line.mode {
                groups[last] = ModeGroup(mode: line.mode, lines: groups[last].lines + [line])
            } else {
                groups.append(ModeGroup(mode: line.mode, lines: [line]))
            }
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                SearchField(placeholder: "Rechercher une ligne ou un terminus…", text: $searchText)
                if index.isStaleOn(isoDate: TimetableFormat.serviceDateIso()) {
                    StaleNotice(text: TimetableTexts.shared.staleNotice(validToLong: TimetableFormat.longDate(iso: index.validTo)))
                }
                if !favorites.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        SectionLabel(text: "Favoris")
                    }
                    .padding(.leading, 20)
                    ForEach(favorites, id: \.key) { lineRow($0) }
                }
                ForEach(groups) { group in
                    SectionLabel(text: TimetableFormat.modeLabel(group.mode))
                    ForEach(group.lines, id: \.key) { lineRow($0) }
                }
                if filtered.isEmpty {
                    Text("Aucune ligne ne correspond à cette recherche.")
                        .foregroundStyle(.secondary)
                        .padding(20)
                }
                Text("Horaires théoriques SYTRAL, connus jusqu'au \(TimetableFormat.longDate(iso: index.validTo)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
        }
    }

    private func lineRow(_ line: TimetableLineSummary) -> some View {
        VStack(spacing: 0) {
            Button {
                selectedLine = line
            } label: {
                HStack(spacing: 14) {
                    LineBadge(line: line.line, size: line.line.count > 3 ? 11 : 13)
                        .frame(minWidth: 44)
                    Text(line.directions.map(\.headsign).joined(separator: " ↔ "))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Chevron()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 78)
        }
    }

    private func matchesSearch(_ line: TimetableLineSummary) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return true }
        if line.line.localizedCaseInsensitiveContains(query) { return true }
        return line.directions.contains { $0.headsign.localizedCaseInsensitiveContains(query) }
    }
}

/// Choix du sens d'une ligne.
private struct LineDirectionsView: View {
    let line: TimetableLineSummary
    @State private var selectedDirection: TimetableDirectionSummary?

    private var accent: Color { LineColorHelper.backgroundColor(for: line.line) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                LineHeaderCard(line: line.line, title: "Ligne \(line.line)", subtitle: TimetableFormat.modeLabel(line.mode))
                SectionLabel(text: "Dans quel sens ?")
                ForEach(line.directions, id: \.dir) { direction in
                    VStack(spacing: 0) {
                        Button {
                            selectedDirection = direction
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(accent)
                                    .frame(width: 32, height: 32)
                                    .background(accent.opacity(0.15), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vers \(direction.headsign)")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(direction.stops) arrêts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Chevron()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ligne \(line.line)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedDirection) { direction in
            LineStopsView(line: line.line, direction: direction)
        }
        #if DEBUG
        .task {
            // Mode démo « horaires-arrets » : ouvrir la liste des arrêts du premier sens, une fois la transition finie.
            guard DemoShowcase.current == "horaires-arrets" else { return }
            try? await Task.sleep(nanoseconds: DemoShowcase.pushDelayNanoseconds)
            selectedDirection = line.directions.first
        }
        #endif
    }
}

/// Choix de l'arrêt sur une ligne dans un sens, puis horaires à cet arrêt.
private struct LineStopsView: View {
    let line: String
    let direction: TimetableDirectionSummary

    @State private var timetable: LineTimetable?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var searchText = ""
    @State private var selectedSource: StopTimetableSource?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Chargement de la ligne…")
            } else if loadFailed {
                UnavailableView(message: "Impossible de charger la fiche de la ligne \(line) pour le moment.") {
                    Task { await load() }
                }
            } else if let timetable {
                stopList(timetable)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(line) vers \(direction.headsign)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .navigationDestination(item: $selectedSource) { source in
            StopTimetableView(source: source)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            timetable = try await TimetableService.companion.shared.fetchLine(line: line, direction: direction.dir)
        } catch {
            loadFailed = true
            AppLogger.debug("⚠️ Fiche \(line)/\(direction.dir) : \(error.localizedDescription)")
        }
    }

    private func stopList(_ timetable: LineTimetable) -> some View {
        let accent = LineColorHelper.backgroundColor(for: timetable.line)
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let indexes = timetable.stops.indices.filter { query.isEmpty || timetable.stops[$0].name.localizedCaseInsensitiveContains(query) }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                LineHeaderCard(line: timetable.line, title: "Vers \(timetable.headsign)", subtitle: "\(timetable.stops.count) arrêts dans l'ordre du parcours")
                SearchField(placeholder: "Rechercher un arrêt…", text: $searchText)
                    .padding(.bottom, 8)
                ForEach(indexes, id: \.self) { stopIndex in
                    let stop = timetable.stops[stopIndex]
                    let isEnd = stopIndex == 0 || stopIndex == timetable.stops.count - 1
                    Button {
                        selectedSource = .timetable(timetable, stopIndexes: [stopIndex], stopName: stop.name)
                    } label: {
                        HStack(spacing: 0) {
                            // Rail de la ligne : les arrêts s'enchaînent visuellement comme sur un plan
                            TimelineDot(accent: accent, isEnd: isEnd, highlighted: false,
                                        showAbove: stopIndex > 0 && query.isEmpty,
                                        showBelow: stopIndex < timetable.stops.count - 1 && query.isEmpty)
                            Text(stop.name)
                                .font(.subheadline.weight(isEnd ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                            Spacer()
                            Chevron()
                        }
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
                if indexes.isEmpty {
                    Text("Aucun arrêt ne correspond à cette recherche.")
                        .foregroundStyle(.secondary)
                        .padding(20)
                }
            }
            .padding(.bottom, 24)
        }
    }
}


// MARK: - Identifiants SwiftUI des types Kotlin

extension TimetableDeparture {
    /// Identifiant stable d'une ligne de passage (course + arrêt) pour ForEach et le défilement.
    var rowID: String { "\(tripIndex)-\(stopIndex)" }
}
