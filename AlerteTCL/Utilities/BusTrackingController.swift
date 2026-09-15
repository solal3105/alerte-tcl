import ActivityKit
import Combine
import Foundation
import Shared

/// Suit un bus jusqu'à un arrêt dans une activité en direct (écran verrouillé, Dynamic Island).
///
/// L'application met l'activité à jour à chaque réception de positions tant qu'elle est ouverte. Une
/// fois en arrière-plan, le compte à rebours continue seul et l'activité se signale périmée après deux
/// minutes sans mise à jour : aucune position n'est extrapolée hors de l'application.
@MainActor
final class BusTrackingController: ObservableObject {
    static let shared = BusTrackingController()

    /// Les activités en direct peuvent être désactivées par l'utilisateur dans les réglages.
    static var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    @Published private(set) var trackedVehicleId: String?

    private var activity: Activity<BusTrackingAttributes>?
    private var vehiclesSubscription: AnyCancellable?
    private var stop: MergedStop?
    private var timetable: LineTimetable?
    private var startedAt = Date()
    private var lastSeenAt = Date()

    private static let maxDuration: TimeInterval = 45 * 60
    private static let lostAfter: TimeInterval = 120
    private static let staleAfter: TimeInterval = 120

    private init() {}

    /// Termine les activités laissées par un lancement précédent : personne ne les met plus à jour.
    func endOrphans() {
        guard activity == nil else { return }
        for orphan in Activity<BusTrackingAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func start(vehicle: Vehicle, approach: ApproachingVehicle, stop: MergedStop, timetable: LineTimetable, liveVM: LiveVehiclesViewModel) {
        end(text: nil)
        let attributes = BusTrackingAttributes(
            line: vehicle.lineName,
            lineColorHex: LineColors.shared.backgroundHex(line: vehicle.lineName),
            lineTextColorHex: LineColors.shared.textHex(line: vehicle.lineName),
            destination: vehicle.destination,
            stopName: stop.nom,
            vehicleId: vehicle.id
        )
        do {
            activity = try Activity.request(attributes: attributes, content: content(for: approach), pushType: nil)
        } catch {
            AppLogger.debug("⚠️ Activité en direct refusée : \(error.localizedDescription)")
            return
        }
        trackedVehicleId = vehicle.id
        self.stop = stop
        self.timetable = timetable
        startedAt = Date()
        lastSeenAt = Date()
        vehiclesSubscription = liveVM.$vehicles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vehicles in self?.refresh(with: vehicles) }
    }

    func cancel() { end(text: "Suivi arrêté") }

    private func refresh(with vehicles: [Vehicle]) {
        guard let id = trackedVehicleId, let stop, let timetable else { return }
        if Date().timeIntervalSince(startedAt) > Self.maxDuration {
            end(text: "Suivi terminé après 45 minutes")
            return
        }
        let tracked = vehicles.first { $0.id == id }
        let approach = tracked.flatMap { vehicle in
            StopApproach.shared.approaching(
                vehicles: [vehicle.shared], timetable: timetable,
                stopIds: stop.stops.map { KotlinInt(value: Int32($0.id)) }, stopName: stop.nom,
                nowEpochMs: Int64(Date().timeIntervalSince1970 * 1000), timeZoneId: StopApproach.shared.TIME_ZONE, limit: 1
            ).first
        }
        if let approach {
            lastSeenAt = Date()
            update(content(for: approach))
        } else if tracked != nil {
            end(text: "Le bus est passé à l'arrêt \(stop.nom)")
        } else if Date().timeIntervalSince(lastSeenAt) > Self.lostAfter {
            end(text: "TCL ne transmet plus la position de ce bus")
        }
    }

    private func content(for approach: ApproachingVehicle) -> ActivityContent<BusTrackingAttributes.ContentState> {
        let state = BusTrackingAttributes.ContentState(
            stopsText: approach.stopsText,
            estimatedArrival: approach.estimatedArrivalEpoch.map { Date(timeIntervalSince1970: TimeInterval($0.int64Value)) },
            positionRecordedAt: approach.vehicle.recordedAtEpoch.map { Date(timeIntervalSince1970: TimeInterval($0.int64Value)) },
            updatedAt: Date(),
            endedText: nil
        )
        return ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleAfter))
    }

    private func update(_ content: ActivityContent<BusTrackingAttributes.ContentState>) {
        guard let activity else { return }
        Task { await activity.update(content) }
    }

    /// Termine l'activité ; sans texte, elle disparaît aussitôt (remplacement par un autre suivi).
    private func end(text: String?) {
        vehiclesSubscription = nil
        trackedVehicleId = nil
        stop = nil
        timetable = nil
        guard let activity else { return }
        self.activity = nil
        let state = BusTrackingAttributes.ContentState(
            stopsText: "", estimatedArrival: nil, positionRecordedAt: nil, updatedAt: Date(), endedText: text ?? "Suivi arrêté"
        )
        let policy: ActivityUIDismissalPolicy = text == nil ? .immediate : .after(Date().addingTimeInterval(5 * 60))
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy) }
    }
}
