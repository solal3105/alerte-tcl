package com.alertetcl.shared.util

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

/**
 * Cache spatial par tuiles. Stocke des items géolocalisés organisés en
 * tuiles indexées par (x,y) avec une taille en degrés et une expiration.
 *
 * Equivalent du SpatialTileCache Swift.
 */
data class TileKey(val x: Int, val y: Int)

data class TileCacheConfig(
    /** Taille d'une tuile en degrés (lon=lat). */
    val tileSizeDegrees: Double,
    /** Durée de validité d'une tuile en secondes. */
    val expirationSeconds: Long
) {
    companion object {
        /** Données statiques (vélos, 2-roues). 1 heure, ~2.2km. */
        val STATIC_DATA = TileCacheConfig(0.02, 3600)
        /** Données semi-temps réel (parkings voiture). 60s, ~5km. */
        val SEMI_REALTIME = TileCacheConfig(0.05, 60)
    }
}

class SpatialTileCache<T>(private val config: TileCacheConfig) {
    private data class Tile<T>(val items: List<T>, val timestampSeconds: Long)
    private val tiles = mutableMapOf<TileKey, Tile<T>>()
    private val mutex = Mutex()

    suspend fun set(tile: TileKey, items: List<T>) {
        mutex.withLock {
            tiles[tile] = Tile(items, Clock.System.now().epochSeconds)
        }
    }

    suspend fun pruneExpired() {
        val cutoff = Clock.System.now().epochSeconds - config.expirationSeconds
        mutex.withLock {
            tiles.entries.removeAll { it.value.timestampSeconds < cutoff }
        }
    }

    /** Pour une bbox (lon/lat min/max), retourne (items en cache, tuiles manquantes). */
    suspend fun getItemsForBoundingBox(
        minLat: Double, minLon: Double, maxLat: Double, maxLon: Double
    ): Pair<List<T>, List<TileKey>> {
        val needed = tilesFor(minLat, minLon, maxLat, maxLon)
        return mutex.withLock {
            val now = Clock.System.now().epochSeconds
            val cutoff = now - config.expirationSeconds
            val cached = mutableListOf<T>()
            val missing = mutableListOf<TileKey>()
            for (tile in needed) {
                val entry = tiles[tile]
                if (entry != null && entry.timestampSeconds >= cutoff) {
                    cached.addAll(entry.items)
                } else {
                    missing.add(tile)
                }
            }
            cached to missing
        }
    }

    private fun tilesFor(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double): List<TileKey> {
        val s = config.tileSizeDegrees
        val xMin = (minLon / s).toInt()
        val xMax = (maxLon / s).toInt()
        val yMin = (minLat / s).toInt()
        val yMax = (maxLat / s).toInt()
        val list = mutableListOf<TileKey>()
        for (x in xMin..xMax) for (y in yMin..yMax) list += TileKey(x, y)
        return list
    }

    fun bboxStringFor(tiles: List<TileKey>): String {
        if (tiles.isEmpty()) return ""
        val s = config.tileSizeDegrees
        val minX = tiles.minOf { it.x } * s
        val maxX = (tiles.maxOf { it.x } + 1) * s
        val minY = tiles.minOf { it.y } * s
        val maxY = (tiles.maxOf { it.y } + 1) * s
        return "$minX,$minY,$maxX,$maxY"
    }

    suspend fun clear() {
        mutex.withLock { tiles.clear() }
    }
}
