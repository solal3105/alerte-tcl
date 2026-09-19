import Foundation

/// Rapprochement des noms de destination : la règle de `DirectionMatching` (module partagé, que
/// l'extension ne lie pas). Accents, ponctuation et abréviations ne séparent pas deux sens.
enum WidgetDirectionMatching {
    private static let aliases = ["st": "saint", "ste": "sainte"]
    private static let prefixLength = 8

    /// Mots du nom, en minuscules sans accents (« Hôp. Feyzin » → ["hop", "feyzin"]).
    static func tokens(_ name: String) -> [String] {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
        var result: [String] = []
        var current = ""
        for character in folded {
            if character.isASCII && (character.isLetter || character.isNumber) {
                current.append(character)
            } else if !current.isEmpty {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.map { aliases[$0] ?? $0 }
    }

    private static func abbreviates(_ x: String, _ y: String) -> Bool {
        x == y || (min(x.count, y.count) >= 2 && (x.hasPrefix(y) || y.hasPrefix(x)))
    }

    static func namesMatch(_ a: String, _ b: String) -> Bool {
        let ta = tokens(a), tb = tokens(b)
        if ta.isEmpty || tb.isEmpty { return false }
        if ta == tb { return true }
        if ta.count == tb.count, zip(ta, tb).allSatisfy({ abbreviates($0, $1) }) { return true }
        let na = ta.joined(), nb = tb.joined()
        if na.count < prefixLength || nb.count < prefixLength { return false }
        return na.hasPrefix(String(nb.prefix(prefixLength))) || nb.hasPrefix(String(na.prefix(prefixLength)))
    }
}

/// Prochains passages d'un quai pour une ligne et un sens, depuis le relais `/passages`.
enum PassagesService {
    private struct Response: Decodable {
        let values: [Value]
    }

    private struct Value: Decodable {
        let ligne: String
        let direction: String
        let heurepassage: String
        let type: String
    }

    struct Result {
        let departures: [WidgetDeparture]
        let fetchedAt: Date
        /// Dernier chargement réussi, faute de réseau.
        let stale: Bool
        /// Tout ou partie des passages vient des fiches horaires théoriques (le direct n'annonçait plus rien).
        let theoretical: Bool
    }

    private static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f
    }()

    /// Fenêtre des passages gardés : de trente secondes avant maintenant à deux heures.
    private static let pastTolerance: TimeInterval = 30
    private static let horizon: TimeInterval = 2 * 3600
    private static let staleMaxAge: TimeInterval = 90 * 60
    private static let keptCount = 6
    /// Un passage théorique n'est ajouté qu'au-delà de ce délai après le dernier passage annoncé en direct.
    private static let theoreticalGap: TimeInterval = 5 * 60

    static func departures(for stop: WidgetStop, now: Date = Date()) async -> Result? {
        let lineKey = WidgetLinePalette.key(for: stop.line)
        let cacheKey = "passages.\(stop.stopId).\(lineKey).\(WidgetDirectionMatching.tokens(stop.direction).joined())"
        do {
            let response = try await WidgetNetwork.json(Response.self, from: "\(ProxyEndpoint.baseURL)/passages?id=\(stop.stopId)")
            var seen = Set<Date>()
            let departures = response.values
                .compactMap { value -> WidgetDeparture? in
                    guard WidgetLinePalette.key(for: value.ligne) == lineKey,
                          WidgetDirectionMatching.namesMatch(value.direction, stop.direction),
                          let time = apiFormatter.date(from: value.heurepassage),
                          time >= now.addingTimeInterval(-pastTolerance),
                          time <= now.addingTimeInterval(horizon),
                          seen.insert(time).inserted else { return nil }
                    return WidgetDeparture(time: time, realTime: value.type == "E")
                }
                .sorted { $0.time < $1.time }
                .prefix(keptCount)
            let kept = await completed(Array(departures), for: stop, now: now)
            WidgetStore.cache(kept.departures, key: cacheKey)
            return Result(departures: kept.departures, fetchedAt: now, stale: false, theoretical: kept.theoretical)
        } catch {
            AppLogger.debug("Passages de l'arrêt \(stop.stopId) injoignables : \(error.localizedDescription)", category: .widget)
            guard let cached = WidgetStore.cached([WidgetDeparture].self, key: cacheKey, maxAge: staleMaxAge) else {
                // Sans réseau vers le direct, les fiches horaires (souvent déjà en cache) donnent au moins l'horaire prévu.
                let planned = await TimetableService.departures(for: stop, after: now, limit: keptCount)
                guard !planned.isEmpty else { return nil }
                return Result(departures: planned, fetchedAt: now, stale: true, theoretical: true)
            }
            let remaining = cached.value.filter { $0.time >= now.addingTimeInterval(-pastTolerance) }
            guard !remaining.isEmpty else { return nil }
            return Result(departures: remaining, fetchedAt: cached.savedAt, stale: true, theoretical: !remaining.contains(where: \.realTime))
        }
    }

    /// Quand le direct annonce moins de deux passages, la suite vient des fiches horaires : le widget
    /// montre toujours les prochains départs, jusqu'à ceux du lendemain.
    private static func completed(_ live: [WidgetDeparture], for stop: WidgetStop, now: Date) async -> (departures: [WidgetDeparture], theoretical: Bool) {
        guard live.count < 2 else { return (live, false) }
        let after = live.last.map { $0.time.addingTimeInterval(theoreticalGap) } ?? now
        let planned = await TimetableService.departures(for: stop, after: after, limit: keptCount - live.count)
        guard !planned.isEmpty else { return (live, false) }
        return (live + planned, true)
    }
}
