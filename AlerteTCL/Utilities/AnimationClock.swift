//
//  AnimationClock.swift
//  AlerteTCL
//
//  Horloge d'animation partagée (~15 fps) isolée des autres @Published du ViewModel.
//  Objectif: les ticks d'horloge n'invalident QUE les vues qui lisent `time`
//  (typiquement les marqueurs de véhicules), pas le reste de la carte
//  (bandeaux, contrôles, polylines, clusters, arrêts — statiques entre deux fetchs).
//

import Foundation
import QuartzCore

@MainActor
final class AnimationClock: ObservableObject {
    /// Temps de référence lu par les interpolations. Mis à jour ~15 fps quand `isRunning == true`.
    @Published private(set) var time: CFTimeInterval = CACurrentMediaTime()

    private var tickTask: Task<Void, Never>?

    /// ~15 fps — compromis fluidité vs charge. Ne pas dépasser 20 fps sur MapKit SwiftUI.
    private static let tickInterval: UInt64 = 66_666_666 // 66.6 ms

    var isRunning: Bool { tickTask != nil }

    func start() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.time = CACurrentMediaTime()
                try? await Task.sleep(nanoseconds: Self.tickInterval)
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    deinit {
        tickTask?.cancel()
    }
}
