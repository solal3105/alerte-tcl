package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.geo.fastDistance2D
import com.alertetcl.shared.util.easeOutQuad
import kotlinx.datetime.Clock

/**
 * Etat d'animation pour un véhicule. Plateforme-agnostique : les UI
 * (UIKit/MapKit ou Compose Maps) demandent la position interpolée à un instant T.
 *
 * - Distance > 500m : téléportation immédiate
 * - Distance < 1m : pas d'animation (bruit GPS)
 * - Sinon : interpolation easeOutQuad sur 5 s (chaque fetch API → nouvelle transition)
 */
class AnimatedVehicle(
    initial: Vehicle,
    var transitionDuration: Double = 5.0,
    var teleportDistanceMeters: Double = 500.0,
    var noiseDistanceMeters: Double = 1.0,
    var gracePeriodSeconds: Double = 45.0
) {
    var currentVehicle: Vehicle = initial
        private set

    private var sourceCoord: LatLng = initial.coordinate
    private var targetCoord: LatLng = initial.coordinate
    private var sourceBearing: Double = initial.bearing
    private var targetBearing: Double = initial.bearing
    private var transitionStartedAt: Double = nowSeconds()
    private var lastUpdateAt: Double = nowSeconds()

    // Deltas pré-calculés à chaque updateWith pour éviter les soustractions répétées à 10 Hz.
    private var latDelta: Double = 0.0
    private var lngDelta: Double = 0.0
    private var bearingDelta: Double = 0.0
    private var transitionDurationInv: Double = 1.0 / transitionDuration

    private fun nowSeconds(): Double = Clock.System.now().toEpochMilliseconds() / 1000.0

    private fun recomputeDeltas() {
        latDelta = targetCoord.latitude  - sourceCoord.latitude
        lngDelta = targetCoord.longitude - sourceCoord.longitude
        var bd   = targetBearing - sourceBearing
        if (bd >  180) bd -= 360
        if (bd < -180) bd += 360
        bearingDelta         = bd
        transitionDurationInv = 1.0 / transitionDuration
    }

    fun updateWith(newVehicle: Vehicle) {
        val now = nowSeconds()
        val newCoord = newVehicle.coordinate
        val distance = fastDistance2D(currentInterpolatedCoordinate(now), newCoord)

        when {
            distance < noiseDistanceMeters -> {
                // Bruit GPS : on garde la position courante
                currentVehicle = newVehicle
                lastUpdateAt = now
            }
            distance > teleportDistanceMeters -> {
                // Téléportation
                sourceCoord = newCoord
                targetCoord = newCoord
                sourceBearing = newVehicle.bearing
                targetBearing = newVehicle.bearing
                currentVehicle = newVehicle
                transitionStartedAt = now
                lastUpdateAt = now
                recomputeDeltas()
            }
            else -> {
                sourceCoord = currentInterpolatedCoordinate(now)
                sourceBearing = currentInterpolatedBearing(now)
                targetCoord = newCoord
                targetBearing = newVehicle.bearing
                currentVehicle = newVehicle
                transitionStartedAt = now
                lastUpdateAt = now
                recomputeDeltas()
            }
        }
    }

    fun currentInterpolatedCoordinate(now: Double = nowSeconds()): LatLng {
        val elapsed = now - transitionStartedAt
        if (elapsed >= transitionDuration) return targetCoord
        val t = easeOutQuad(elapsed * transitionDurationInv)
        return LatLng(
            sourceCoord.latitude  + latDelta * t,
            sourceCoord.longitude + lngDelta * t
        )
    }

    fun currentInterpolatedBearing(now: Double = nowSeconds()): Double {
        val elapsed = now - transitionStartedAt
        if (elapsed >= transitionDuration) return targetBearing
        val t = easeOutQuad(elapsed * transitionDurationInv)
        var v = sourceBearing + bearingDelta * t
        if (v < 0) v += 360
        if (v >= 360) v -= 360
        return v
    }

    /** Marque le véhicule comme expiré si pas de mise à jour depuis grace period. */
    fun isStale(now: Double = nowSeconds()): Boolean = (now - lastUpdateAt) > gracePeriodSeconds
}
