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

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    /// « mer. 17 sept. » pour les puces de choix du jour.
    static func shortDay(_ date: Date) -> String { shortDayFormatter.string(from: date) }

    /// Délai annoncé par le temps réel (« 12 min », « Proche ») sous une forme lisible.
    static func delayLabel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.hasSuffix("min") ? "dans \(trimmed)" : trimmed.lowercased()
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

/// Passages d'une journée à un arrêt : les prochains passages en direct, puis les horaires
/// théoriques présentés comme une fiche d'arrêt (l'heure à gauche, les minutes à droite).
///
/// Tout ce qui se déduit de la journée (passages, lignes d'heures, repères de légende, prochain
/// passage) est calculé une seule fois par jour affiché, jamais pendant le rendu : la fiche d'une
/// ligne compte plusieurs centaines de passages et le module Kotlin est appelé à chaque calcul.
private struct TimetableDayList: View {
    let timetable: LineTimetable
    let stopIndexes: [Int]
    let stopName: String
    @Binding var date: Date
    let onSelect: (TimetableDeparture) -> Void

    @State private var showOtherDays = false
    @State private var livePassages: [Shared.Passage] = []
    @State private var liveLoaded = false
    @State private var model: DayModel
    @State private var otherDays: [Date]

    private struct HourRow: Identifiable {
        let hour: Int
        let departures: [TimetableDeparture]
        var id: Int { hour }
    }

    private struct LegendEntry: Identifiable {
        let mark: String
        let text: String
        var id: String { mark }
    }

    /// Données dérivées de la journée affichée.
    private struct DayModel {
        var departures: [TimetableDeparture] = []
        var hourRows: [HourRow] = []
        var isServiceDay = false
        var nowMinutes = 0
        var nextDeparture: TimetableDeparture?
        var terminusMarks: [String: String] = [:]
        var legend: [LegendEntry] = []
        var hasAfterMidnight = false

        init() {}

        init(timetable: LineTimetable, stopIndexes: [Int], date: Date) {
            departures = timetable.departures(stopIndexes: TimetableFormat.kotlinInts(stopIndexes), isoDate: TimetableFormat.iso(date))
            var rows: [HourRow] = []
            for departure in departures {
                let hour = Int(departure.minutes) / 60
                if let last = rows.indices.last, rows[last].hour == hour {
                    rows[last] = HourRow(hour: hour, departures: rows[last].departures + [departure])
                } else {
                    rows.append(HourRow(hour: hour, departures: [departure]))
                }
            }
            hourRows = rows
            isServiceDay = Calendar.current.isDate(date, inSameDayAs: TimetableFormat.serviceDate())
            nowMinutes = TimetableFormat.serviceMinutes()
            nextDeparture = isServiceDay ? departures.first { Int($0.minutes) >= nowMinutes } : nil
            // Lettre par terminus inhabituel, dans l'ordre d'apparition (comme sur une fiche papier).
            var marks: [String: String] = [:]
            for departure in departures where departure.terminus != timetable.headsign && marks[departure.terminus] == nil {
                marks[departure.terminus] = String(UnicodeScalar(UInt8(97 + marks.count % 26)))
            }
            terminusMarks = marks
            legend = marks.sorted { $0.value < $1.value }.map { LegendEntry(mark: $0.value, text: "vers \($0.key)") }
            if departures.contains(where: { $0.isTerminus }) {
                legend.append(LegendEntry(mark: "†", text: "heure d'arrivée, cet arrêt est le terminus"))
            }
            hasAfterMidnight = departures.contains { TimetableTime.shared.isAfterMidnight(minutes: $0.minutes) }
        }

        func mark(for departure: TimetableDeparture) -> String? {
            departure.isTerminus ? "†" : terminusMarks[departure.terminus]
        }
    }

    init(timetable: LineTimetable, stopIndexes: [Int], stopName: String, date: Binding<Date>, onSelect: @escaping (TimetableDeparture) -> Void) {
        self.timetable = timetable
        self.stopIndexes = stopIndexes
        self.stopName = stopName
        self._date = date
        self.onSelect = onSelect
        _model = State(initialValue: DayModel(timetable: timetable, stopIndexes: stopIndexes, date: date.wrappedValue))
        _otherDays = State(initialValue: Self.otherDays(of: timetable))
    }

    private var accent: Color { LineColorHelper.backgroundColor(for: timetable.line) }
    private var accentText: Color { LineColorHelper.textColor(for: timetable.line) }

    /// Jours proposés au-delà de demain, dans la période couverte.
    private static func otherDays(of timetable: LineTimetable) -> [Date] {
        let calendar = Calendar.current
        let start = TimetableFormat.serviceDate()
        guard let last = TimetableFormat.date(iso: timetable.validTo) else { return [] }
        return (2..<60).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start), day <= last else { return nil }
            return timetable.isValidOn(isoDate: TimetableFormat.iso(day)) ? day : nil
        }
    }

    private func recompute() {
        model = DayModel(timetable: timetable, stopIndexes: stopIndexes, date: date)
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
                        if model.isServiceDay {
                            liveSection
                        }
                        if model.departures.isEmpty {
                            Text("Aucun passage prévu ce jour-là à cet arrêt.")
                                .foregroundStyle(.secondary)
                                .padding(20)
                        } else {
                            SectionLabel(text: model.isServiceDay ? "Horaires de la journée" : "Horaires")
                            ForEach(model.hourRows) { row in
                                hourRow(row)
                                    .id(row.hour)
                            }
                            if !model.legend.isEmpty {
                                legendView
                            }
                        }
                        notes
                    }
                    .padding(.bottom, 24)
                }
                .onAppear { scrollToNext(proxy) }
                .onChange(of: date) { _, _ in
                    recompute()
                    scrollToNext(proxy)
                }
                // Le bloc « En direct » change de hauteur en arrivant : on recale la liste sur le prochain passage.
                .onChange(of: liveLoaded) { _, _ in scrollToNext(proxy) }
            }
        }
        .task(id: stopIndexes) { await refreshLive() }
    }

    // MARK: En-tête et choix du jour

    private var header: some View {
        LineHeaderCard(line: timetable.line, title: "Vers \(timetable.headsign)", subtitle: "Arrêt \(stopName)") {
            VStack(alignment: .leading, spacing: 10) {
                Text(TimetableFormat.longDate(date))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    dayChip("Aujourd'hui", offset: 0)
                    dayChip("Demain", offset: 1)
                    chip(label: "Autre jour", icon: "calendar", selected: showOtherDays, available: !otherDays.isEmpty) {
                        withAnimation(.easeInOut(duration: 0.2)) { showOtherDays.toggle() }
                    }
                }
                if showOtherDays {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(otherDays, id: \.self) { day in
                                chip(label: TimetableFormat.shortDay(day), icon: nil,
                                     selected: Calendar.current.isDate(day, inSameDayAs: date), available: true) {
                                    date = day
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayChip(_ title: String, offset: Int) -> some View {
        let target = Calendar.current.date(byAdding: .day, value: offset, to: TimetableFormat.serviceDate()) ?? date
        return chip(label: title, icon: nil,
                    selected: Calendar.current.isDate(target, inSameDayAs: date),
                    available: timetable.isValidOn(isoDate: TimetableFormat.iso(target))) {
            date = target
        }
    }

    private func chip(label: String, icon: String?, selected: Bool, available: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon) }
                Text(label)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? accent.opacity(0.18) : Color.appNeutralFill, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? accent.opacity(0.6) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.4)
    }

    // MARK: Passages en direct

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(Color.appSuccess).frame(width: 7, height: 7)
                Text("EN DIRECT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 4)
            if livePassages.isEmpty {
                Text(liveLoaded ? "Aucun passage annoncé pour le moment." : "Chargement des passages en direct…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(livePassages, id: \.id) { passage in liveRow(passage) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func liveRow(_ passage: Shared.Passage) -> some View {
        HStack(spacing: 12) {
            Text(passage.formattedTime)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
            Text(TimetableFormat.delayLabel(passage.delaipassage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Pill(text: passage.isRealTime ? "estimé" : "théorique",
                 background: passage.isRealTime ? Color.appSuccess.opacity(0.15) : Color.appNeutralFill,
                 foreground: passage.isRealTime ? Color.appSuccess : Color.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Recharge les passages en direct toutes les 30 secondes tant que la journée en cours est affichée.
    private func refreshLive() async {
        let stopIds = stopIndexes.compactMap { index -> Int32? in
            guard index >= 0, index < timetable.stops.count else { return nil }
            return timetable.stops[index].id
        }
        let termini = (try? await LineTermini.shared.all()) ?? [:]
        while !Task.isCancelled {
            if model.isServiceDay {
                var all: [Shared.Passage] = []
                for stopId in stopIds {
                    if let passages = try? await Shared.TransitStopService.companion.shared.fetchPassagesForStop(stopId: stopId) {
                        all.append(contentsOf: passages)
                    }
                }
                livePassages = TimetableLive.shared.nextPassages(passages: all, line: timetable.line, direction: timetable.dir, termini: termini, limit: 3)
                liveLoaded = true
                recompute()  // le prochain passage avance avec l'heure
            }
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }

    // MARK: Grille des horaires

    private func hourRow(_ row: HourRow) -> some View {
        let containsNext = model.nextDeparture.map { Int($0.minutes) / 60 == row.hour } ?? false
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(hourLabel(row.hour))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            FlowLayout(spacing: 6) {
                ForEach(row.departures, id: \.rowID) { departure in minuteChip(departure) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(containsNext ? accent.opacity(0.07) : .clear)
    }

    private func minuteChip(_ departure: TimetableDeparture) -> some View {
        let isPast = model.isServiceDay && Int(departure.minutes) < model.nowMinutes
        let isNext = departure.rowID == model.nextDeparture?.rowID
        let minute = String(format: "%02d", Int(departure.minutes) % 60)
        let foreground: Color = isNext ? accentText : (isPast ? Color.secondary.opacity(0.55) : .primary)
        return Button {
            onSelect(departure)
        } label: {
            HStack(alignment: .top, spacing: 1) {
                Text(minute)
                    .font(.system(size: 15, weight: isNext ? .bold : .medium, design: .rounded).monospacedDigit())
                if let mark = model.mark(for: departure) {
                    Text(mark)
                        .font(.system(size: 9, weight: .semibold))
                        .baselineOffset(6)
                }
            }
            .foregroundStyle(foreground)
            .frame(minWidth: 36)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(isNext ? accent : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(model.legend) { entry in
                HStack(alignment: .top, spacing: 6) {
                    Text(entry.mark).fontWeight(.semibold).frame(width: 12, alignment: .leading)
                    Text(entry.text)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Horaires théoriques publiés par SYTRAL, connus jusqu'au \(TimetableFormat.longDate(iso: timetable.validTo)). Les passages en direct viennent du temps réel TCL ; en cas de perturbation, consultez les alertes trafic.")
            if model.hasAfterMidnight {
                Text("Les heures marquées +1 sont après minuit, rattachées à la journée de service de la veille.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func hourLabel(_ hour: Int) -> String {
        hour < 24 ? "\(hour) h" : "\(hour - 24) h +1"
    }

    private func scrollToNext(_ proxy: ScrollViewProxy) {
        guard let target = model.nextDeparture.map({ Int($0.minutes) / 60 }) ?? model.hourRows.first?.hour else { return }
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(target, anchor: .top) }
        }
    }
}

/// Dispose ses enfants en lignes, à la manière d'un texte qui passe à la ligne.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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
                            .foregroundStyle(Color.appFavorite)
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
                .contentShape(Rectangle())
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
                            .contentShape(Rectangle())
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
        let groups = timetable.stopGroups
        let indexes = groups.indices.filter { query.isEmpty || groups[$0].name.localizedCaseInsensitiveContains(query) }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                LineHeaderCard(line: timetable.line, title: "Vers \(timetable.headsign)", subtitle: "\(groups.count) arrêts dans l'ordre du parcours")
                SearchField(placeholder: "Rechercher un arrêt…", text: $searchText)
                    .padding(.bottom, 8)
                ForEach(indexes, id: \.self) { stopIndex in
                    let stop = groups[stopIndex]
                    let isEnd = stopIndex == 0 || stopIndex == groups.count - 1
                    Button {
                        selectedSource = .timetable(timetable, stopIndexes: stop.stopIndexes.map { $0.intValue }, stopName: stop.name)
                    } label: {
                        HStack(spacing: 0) {
                            // Rail de la ligne : les arrêts s'enchaînent visuellement comme sur un plan
                            TimelineDot(accent: accent, isEnd: isEnd, highlighted: false,
                                        showAbove: stopIndex > 0 && query.isEmpty,
                                        showBelow: stopIndex < groups.count - 1 && query.isEmpty)
                            Text(stop.name)
                                .font(.subheadline.weight(isEnd ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                            Spacer()
                            Chevron()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
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
