package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng

/**
 * Items pouvant être clusterisés sur la carte.
 * Les couleurs/icônes sont des identifiants (hex / clé string).
 */
interface Clusterable {
    val clusterId: String
    val coordinate: LatLng
    val clusterColorHex: String
    val clusterIconKey: String
}

/** Cluster générique. */
data class MapCluster<T : Clusterable>(
    val id: String,
    val center: LatLng,
    val items: List<T>
) {
    val coordinate: LatLng get() = center
    val count: Int get() = items.size
    val isSingle: Boolean get() = count == 1
}

/**
 * Algorithme de clustering avec hashing spatial.
 * Equivalent simplifié du ClusteringEngine Swift.
 */
class ClusteringEngine(
    /** Au-dessus de ce zoom (latitudeDelta) on ne cluster plus. */
    private val zoomThreshold: Double = 0.03,
    /** Taille d'un cluster en degrés. */
    private val clusterCellSizeDegrees: Double = 0.005
) {
    fun <T : Clusterable> cluster(items: List<T>, latitudeDelta: Double): List<MapCluster<T>> {
        if (items.isEmpty()) return emptyList()
        if (latitudeDelta < zoomThreshold) {
            return items.map { MapCluster(it.clusterId, it.coordinate, listOf(it)) }
        }

        // Spatial hashing
        val cells = mutableMapOf<Pair<Int, Int>, MutableList<T>>()
        for (item in items) {
            val key = Pair(
                (item.coordinate.latitude / clusterCellSizeDegrees).toInt(),
                (item.coordinate.longitude / clusterCellSizeDegrees).toInt()
            )
            cells.getOrPut(key) { mutableListOf() }.add(item)
        }

        return cells.values.map { group ->
            val sumLat = group.sumOf { it.coordinate.latitude  }
            val sumLon = group.sumOf { it.coordinate.longitude }
            val n = group.size.toDouble()
            MapCluster(
                id = "cluster-" + group.joinToString("|") { it.clusterId },
                center = LatLng(sumLat / n, sumLon / n),
                items = group
            )
        }
    }

    companion object {
        private val DEFAULT = ClusteringEngine()
        fun <T : Clusterable> cluster(items: List<T>, latitudeDelta: Double) =
            DEFAULT.cluster(items, latitudeDelta)
    }
}
