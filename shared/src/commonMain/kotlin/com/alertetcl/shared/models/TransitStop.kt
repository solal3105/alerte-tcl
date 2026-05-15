package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

@Serializable
data class Passage(
    val stopId: Int,
    val ligne: String,
    val direction: String,
    val delaipassage: String,
    val heurepassage: String,
    val type: String  // "T" théorique ou "R" temps réel
) {
    val id: String get() = "$stopId-$ligne-$heurepassage"
    val isRealTime: Boolean get() = type == "R"

    /** Format `HH:mm` (extrait de heurepassage `yyyy-MM-dd HH:mm:ss`). */
    val formattedTime: String get() {
        val parts = heurepassage.split(" ")
        if (parts.size >= 2) {
            val tp = parts[1].split(":")
            if (tp.size >= 2) return "${tp[0]}:${tp[1]}"
        }
        return heurepassage
    }
}

@Serializable
data class TransitStop(
    val id: Int,
    val nom: String,
    val commune: String,
    val adresse: String? = null,
    val latitude: Double,
    val longitude: Double,
    /** Format CSV brut: "C20:A,JD975:R,..." */
    val desserte: String,
    val pmr: Boolean,
    val passages: List<Passage> = emptyList(),
    val isLoadingPassages: Boolean = false,
    val passagesLoaded: Boolean = false
) : Clusterable {
    override val clusterId: String get() = id.toString()
    override val coordinate: LatLng get() = LatLng(latitude, longitude)
    override val clusterColorHex: String get() = "#1976D2"
    override val clusterIconKey: String get() = "stop"

    /** Lignes uniques desservant cet arrêt. */
    val lines: List<String> by lazy {
        desserte.split(",")
            .mapNotNull { it.split(":").firstOrNull() }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
    }

    /** Directions desservies par cet arrêt. */
    val directions: List<String> by lazy {
        desserte.split(",")
            .mapNotNull {
                val parts = it.split(":")
                if (parts.size >= 2) parts[1].trim() else null
            }
            .distinct()
    }

    val nextPassage: Passage? get() = passages.firstOrNull()
    val hasPassages: Boolean get() = passages.isNotEmpty()
}

/** Plusieurs TransitStop fusionnés (même nom, distance < 30m, mêmes lignes). */
@Serializable
data class MergedStop(
    val id: String,
    val nom: String,
    val latitude: Double,
    val longitude: Double,
    val stops: List<TransitStop>,
    val directions: List<String>
) : Clusterable {
    override val clusterId: String get() = id
    override val coordinate: LatLng get() = LatLng(latitude, longitude)
    override val clusterColorHex: String get() = "#1976D2"
    override val clusterIconKey: String get() = "stop"

    val allLines: List<String> by lazy { stops.flatMap { it.lines }.distinct() }
    val pmr: Boolean by lazy { stops.any { it.pmr } }
    val commune: String get() = stops.firstOrNull()?.commune ?: ""
}

/** Fusionne les arrêts physiquement proches desservant les mêmes lignes (parité iOS). */
object StopMergingEngine {
    private const val MERGE_DISTANCE_METERS = 30.0
    private const val GRID_CELL_SIZE = 0.0005  // ~55m at Lyon latitude (~45.76°)
    private const val METERS_PER_DEG_LAT = 111_320.0
    private const val METERS_PER_DEG_LON = 78_710.0   // cos(45.76°) * 111_320

    private fun distSqMeters(aLat: Double, aLon: Double, bLat: Double, bLon: Double): Double {
        val dlat = (aLat - bLat) * METERS_PER_DEG_LAT
        val dlon = (aLon - bLon) * METERS_PER_DEG_LON
        return dlat * dlat + dlon * dlon
    }

    private data class GridKey(val x: Int, val y: Int)

    private fun gridKey(lat: Double, lon: Double) =
        GridKey((lat / GRID_CELL_SIZE).toInt(), (lon / GRID_CELL_SIZE).toInt())

    fun merge(stops: List<TransitStop>): List<MergedStop> {
        if (stops.isEmpty()) return emptyList()

        val mergeSqM = MERGE_DISTANCE_METERS * MERGE_DISTANCE_METERS

        // Spatial grid for O(n) neighbourhood lookup
        val grid = HashMap<GridKey, MutableList<TransitStop>>()
        for (stop in stops) {
            grid.getOrPut(gridKey(stop.latitude, stop.longitude)) { mutableListOf() }.add(stop)
        }
        val stopLines = HashMap<Int, Set<String>>(stops.size)
        for (stop in stops) stopLines[stop.id] = stop.lines.toHashSet()

        // Union-Find (path compression + union by rank)
        val parent = HashMap<Int, Int>(stops.size)
        val rank   = HashMap<Int, Int>(stops.size)
        for (stop in stops) { parent[stop.id] = stop.id; rank[stop.id] = 0 }

        fun find(id: Int): Int {
            var root = id
            while (parent[root] != root) root = parent[root]!!
            var cur = id
            while (cur != root) { val next = parent[cur]!!; parent[cur] = root; cur = next }
            return root
        }

        fun union(a: Int, b: Int) {
            val ra = find(a); val rb = find(b)
            if (ra == rb) return
            val rankA = rank[ra] ?: 0; val rankB = rank[rb] ?: 0
            when {
                rankA < rankB -> parent[ra] = rb
                rankA > rankB -> parent[rb] = ra
                else          -> { parent[rb] = ra; rank[ra] = rankA + 1 }
            }
        }

        for (stop in stops) {
            val key = gridKey(stop.latitude, stop.longitude)
            val myLines = stopLines[stop.id] ?: continue
            for (dx in -1..1) {
                for (dy in -1..1) {
                    val neighbors = grid[GridKey(key.x + dx, key.y + dy)] ?: continue
                    for (neighbor in neighbors) {
                        if (stop.id >= neighbor.id) continue
                        if (stopLines[neighbor.id] != myLines) continue
                        if (distSqMeters(stop.latitude, stop.longitude,
                                neighbor.latitude, neighbor.longitude) <= mergeSqM) {
                            union(stop.id, neighbor.id)
                        }
                    }
                }
            }
        }

        // Group by Union-Find root
        val groups = HashMap<Int, MutableList<TransitStop>>()
        for (stop in stops) groups.getOrPut(find(stop.id)) { mutableListOf() }.add(stop)

        return groups.values.map { group ->
            val avgLat = group.sumOf { it.latitude }  / group.size
            val avgLon = group.sumOf { it.longitude } / group.size
            val allDirs = group.flatMap { it.directions }.distinct()
            MergedStop(
                id         = group.minOf { it.id }.toString(),
                nom        = group.first().nom,
                latitude   = avgLat,
                longitude  = avgLon,
                stops      = group,
                directions = allDirs
            )
        }
    }
}
