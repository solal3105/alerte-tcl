import Foundation

/// Fiches horaires théoriques (GTFS SYTRAL découpé chaque nuit, relayé sous `/horaires/…`), pour
/// donner les prochains passages quand le direct n'en annonce plus : fin de service, nuit, ou lendemain.
///
/// Lecture minimale du format 1 (voir horaires/README.md), l'extension ne liant pas le module Kotlin.
enum TimetableService {
    private struct Index: Decodable {
        struct Line: Decodable {
            struct Direction: Decodable {
                let dir: String
                let headsign: String
            }
            let key: String
            let directions: [Direction]
        }
        let lines: [Line]
    }

    private struct LineTimetable: Codable {
        struct Stop: Codable {
            let id: Int
            let name: String
        }
        struct Trip: Codable {
            let p: Int
            let s: Int
            let t: [Int]
        }
        let validFrom: String
        let validTo: String
        let stops: [Stop]
        let patterns: [[Int]]
        let services: [[Int]]
        let trips: [Trip]
    }

    private static let minutesPerDay = 1440
    /// Avant 4 h du matin, on est encore sur la journée de service de la veille.
    private static let serviceDayStartHour = 4
    private static let indexMaxAge: TimeInterval = 6 * 3600
    private static let fileMaxAge: TimeInterval = 12 * 3600
    /// Journées de service explorées à partir de la courante (le lendemain, puis le surlendemain).
    private static let daysSearched = 3

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f
    }()

    /// Les prochains passages théoriques à ce quai pour la ligne et le sens, après `after`, sur trois journées de service.
    static func departures(for stop: WidgetStop, after: Date, limit: Int) async -> [WidgetDeparture] {
        guard let timetable = await timetable(for: stop) else { return [] }
        let stopIndexes = stopIndexes(in: timetable, stop: stop)
        guard !stopIndexes.isEmpty else { return [] }
        var result: [WidgetDeparture] = []
        var serviceDay = serviceDate(of: after)
        for _ in 0..<daysSearched {
            guard let dayStart = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: serviceDay)) else { break }
            let minutes = departureMinutes(in: timetable, stopIndexes: stopIndexes, serviceDay: serviceDay)
            for minute in minutes {
                let time = dayStart.addingTimeInterval(TimeInterval(minute * 60))
                if time > after { result.append(WidgetDeparture(time: time, realTime: false)) }
                if result.count >= limit { return result }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: serviceDay) else { break }
            serviceDay = next
        }
        return result
    }

    // MARK: - Chargement

    /// La fiche du sens : d'abord le sens dont le terminus correspond, sinon celui dont un quai porte l'identifiant de l'arrêt.
    private static func timetable(for stop: WidgetStop) async -> LineTimetable? {
        guard let index = await index() else { return nil }
        let key = WidgetLinePalette.key(for: stop.line)
        guard let line = index.lines.first(where: { $0.key == key }) else { return nil }
        let matching = line.directions.filter { WidgetDirectionMatching.namesMatch($0.headsign, stop.direction) }
        let candidates = matching.count == 1 ? matching : line.directions
        var fallback: LineTimetable?
        for direction in candidates {
            guard let timetable = await lineFile(key: key, dir: direction.dir) else { continue }
            if timetable.stops.contains(where: { $0.id == stop.stopId }) { return timetable }
            if fallback == nil, matching.contains(where: { $0.dir == direction.dir }) { fallback = timetable }
        }
        return fallback
    }

    private static func index() async -> Index? {
        let key = "horaires.index"
        if let cached = WidgetStore.cached(Data.self, key: key, maxAge: indexMaxAge) {
            return try? JSONDecoder().decode(Index.self, from: cached.value)
        }
        guard let url = URL(string: "\(ProxyEndpoint.baseURL)/horaires/index.json"),
              let data = try? await WidgetNetwork.data(from: url),
              let index = try? JSONDecoder().decode(Index.self, from: data) else { return nil }
        WidgetStore.cache(data, key: key)
        return index
    }

    private static func lineFile(key: String, dir: String) async -> LineTimetable? {
        let cacheKey = "horaires.\(key).\(dir)"
        if let cached = WidgetStore.cached(Data.self, key: cacheKey, maxAge: fileMaxAge) {
            return try? JSONDecoder().decode(LineTimetable.self, from: cached.value)
        }
        guard let url = URL(string: "\(ProxyEndpoint.baseURL)/horaires/lignes/\(key)/\(dir).json"),
              let data = try? await WidgetNetwork.data(from: url),
              let timetable = try? JSONDecoder().decode(LineTimetable.self, from: data) else { return nil }
        WidgetStore.cache(data, key: cacheKey)
        return timetable
    }

    // MARK: - Lecture de la fiche

    /// Les quais de la fiche pour cet arrêt : par identifiant, sinon par nom.
    private static func stopIndexes(in timetable: LineTimetable, stop: WidgetStop) -> [Int] {
        let byId = timetable.stops.indices.filter { timetable.stops[$0].id == stop.stopId }
        if !byId.isEmpty { return byId }
        return timetable.stops.indices.filter { WidgetDirectionMatching.namesMatch(timetable.stops[$0].name, stop.stopName) }
    }

    /// Minutes de départ (depuis minuit de la journée de service) des courses qui partent de ces quais ce jour-là, triées.
    private static func departureMinutes(in timetable: LineTimetable, stopIndexes: [Int], serviceDay: Date) -> [Int] {
        guard let validFrom = dayFormatter.date(from: timetable.validFrom),
              let validTo = dayFormatter.date(from: timetable.validTo),
              let offset = calendar.dateComponents([.day], from: validFrom, to: serviceDay).day,
              offset >= 0, serviceDay <= validTo else { return [] }
        let active = Set(timetable.services.indices.filter { timetable.services[$0].contains(offset) })
        guard !active.isEmpty else { return [] }
        let wanted = Set(stopIndexes)
        var minutes: [Int] = []
        for trip in timetable.trips where active.contains(trip.s) {
            guard trip.p < timetable.patterns.count else { continue }
            let pattern = timetable.patterns[trip.p]
            for (position, stopIndex) in pattern.enumerated() where wanted.contains(stopIndex) {
                // Le dernier arrêt d'une course est une arrivée, pas un départ.
                guard position < pattern.count - 1, position < trip.t.count else { continue }
                minutes.append(trip.t[position])
            }
        }
        return minutes.sorted()
    }

    /// Journée de service d'une date : la veille avant 4 h du matin (passages de nuit rattachés à la veille).
    private static func serviceDate(of date: Date) -> Date {
        let hour = calendar.component(.hour, from: date)
        let day = calendar.startOfDay(for: date)
        guard hour < serviceDayStartHour, let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return day }
        return previous
    }
}
