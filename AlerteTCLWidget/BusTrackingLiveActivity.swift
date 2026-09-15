import ActivityKit
import SwiftUI
import WidgetKit

/// Suivi d'un bus jusqu'à un arrêt : écran verrouillé et Dynamic Island.
/// Les textes viennent de l'application ; ici seuls le compte à rebours et le délai depuis la dernière
/// position vivent d'eux-mêmes, rendus par le système sans mise à jour.
struct BusTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusTrackingAttributes.self) { context in
            BusTrackingLockScreenView(context: context)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BusTrackingLineBadge(attributes: context.attributes, size: 14)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BusTrackingArrivalView(state: context.state)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.endedText ?? context.state.stopsText)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BusTrackingDetailsView(context: context)
                }
            } compactLeading: {
                BusTrackingLineBadge(attributes: context.attributes, size: 11)
            } compactTrailing: {
                BusTrackingCompactArrival(state: context.state)
            } minimal: {
                BusTrackingLineBadge(attributes: context.attributes, size: 9)
            }
        }
    }
}

private struct BusTrackingLockScreenView: View {
    let context: ActivityViewContext<BusTrackingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                BusTrackingLineBadge(attributes: context.attributes, size: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Vers \(context.attributes.destination)")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("Arrêt \(context.attributes.stopName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                BusTrackingArrivalView(state: context.state)
            }
            BusTrackingDetailsView(context: context)
        }
        .padding(14)
    }
}

/// Ligne du bas : nombre d'arrêts, délai depuis la dernière position, avertissement quand rien ne met plus à jour.
private struct BusTrackingDetailsView: View {
    let context: ActivityViewContext<BusTrackingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let ended = context.state.endedText {
                Text(ended).font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Text(context.state.stopsText).font(.caption.weight(.semibold))
                    if let at = context.state.positionRecordedAt {
                        Text("· position transmise il y a").font(.caption).foregroundStyle(.secondary)
                        Text(at, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                if context.isStale {
                    Text("Plus mis à jour depuis la fermeture de l'application, rouvrez-la pour actualiser.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Compte à rebours jusqu'à l'arrivée estimée, ou l'état quand il n'y en a pas.
private struct BusTrackingArrivalView: View {
    let state: BusTrackingAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if state.endedText != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
            } else if let eta = state.estimatedArrival {
                if eta > Date() {
                    Text(timerInterval: Date()...eta, countsDown: true)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 72)
                    Text(eta, style: .time).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Imminent").font(.headline)
                }
            } else {
                Text("Heure inconnue").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct BusTrackingCompactArrival: View {
    let state: BusTrackingAttributes.ContentState

    var body: some View {
        if state.endedText != nil {
            Image(systemName: "checkmark").font(.caption.weight(.bold))
        } else if let eta = state.estimatedArrival, eta > Date() {
            Text(timerInterval: Date()...eta, countsDown: true)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 46)
        } else {
            Text(state.stopsText).font(.caption2.weight(.semibold)).lineLimit(1)
        }
    }
}

private struct BusTrackingLineBadge: View {
    let attributes: BusTrackingAttributes
    let size: CGFloat

    var body: some View {
        Text(attributes.line)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color(hex: attributes.lineTextColorHex))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(hex: attributes.lineColorHex), in: Capsule())
    }
}
