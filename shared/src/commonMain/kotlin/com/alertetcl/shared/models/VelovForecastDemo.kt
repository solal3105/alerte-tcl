package com.alertetcl.shared.models

import kotlin.math.exp
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Une station de la carte de démonstration : son marqueur et sa place sur l'illustration, en part de la
 * largeur et de la hauteur (0 à 1, depuis le coin haut gauche).
 */
data class VelovForecastDemoPin(val station: VelovStation, val x: Double, val y: Double)

/**
 * La prévision de démonstration des pages Vélo'v de l'intro, lue par iOS et Android : une matinée de
 * semaine où la station du quartier se vide vers 9 h et se remplit le soir, et sept stations autour.
 *
 * Rien n'y vient du modèle : les courbes sont écrites à la main, pour que l'intro montre la prévision
 * même quand aucune n'est encore publiée. Les vues ne dessinent qu'avec les vraies briques de l'écran
 * ([VelovForecastSheet], [VelovForecastMarker]), si bien que l'intro ressemble trait pour trait à ce que
 * l'on trouve ensuite dans l'application.
 */
object VelovForecastDemo {
    /** Mardi 17 novembre 2026, 7 h 30 à Lyon : l'heure de départ de la démonstration. */
    const val ORIGIN_EPOCH_MS = 1_794_897_000_000L

    /**
     * Les échéances par lesquelles passe le curseur animé, dans l'ordre : maintenant, 8 h 30 (la
     * station se vide), 9 h 15 (vide), midi, 19 h 30 (les bureaux se vident), demain 7 h 30.
     */
    val TOUR: List<Int> = listOf(0, 4, 7, 18, 48, 96)

    /** Ce que le graphique de la page « fourchette » montre : tous les vélos. */
    val SHEET_FILTER = VelovFilter.ALL

    /** Les filtres que la page « électriques, classiques, places » fait défiler. */
    val KINDS_TOUR: List<VelovFilter> = listOf(VelovFilter.ELECTRIC, VelovFilter.MECHANICAL, VelovFilter.STANDS)

    /** La page « elle apprend chaque semaine » : les semaines de relevés qui se remplissent, puis le contrôle. */
    const val LEARNING_WEEKS = 8
    const val LEARNING_LABEL = "8 semaines de relevés"
    const val CHECK_LABEL = "Contrôlée lundi"

    /** La station du quartier, celle de la fiche. */
    val station: VelovStation by lazy { site(HOME).station }

    /** Sa fiche, comme l'application la montrerait à 7 h 30. */
    val sheet: VelovForecastSheet by lazy {
        VelovForecastSheet(site(HOME).forecast, ORIGIN_EPOCH_MS, COVERAGE, ::saferNearby)
    }

    /** Les stations de la carte de démonstration, à leur place. */
    val pins: List<VelovForecastDemoPin> by lazy { SITES.map { VelovForecastDemoPin(it.station, it.x, it.y) } }

    /**
     * Les marqueurs de la carte de démonstration à l'échéance [step] (0 à 96) : l'état réel à 0, la
     * fourchette prévue ensuite, comme sur la vraie carte. Dans l'ordre de [pins].
     */
    fun markers(step: Int, filter: VelovFilter = SHEET_FILTER): List<VelovForecastMarker> {
        val shown = VelovForecastTimeline.bounded(step)
        return SITES.map { site ->
            if (shown == 0) {
                VelovForecastMarker(site.station, "${site.station.shownCount(filter)}", site.station.availabilityFor(filter))
            } else {
                val outlook = site.forecast.steps[shown - 1].outlook(filter)
                VelovForecastMarker(site.station, VelovTexts.shortRange(outlook.range), VelovChance.of(outlook.probability).level.availability)
            }
        }
    }

    // --- Les stations ---

    /** Une station de démonstration : son relevé de 7 h 30, sa place et sa prévision. */
    private class Site(val station: VelovStation, val x: Double, val y: Double, val forecast: VelovForecast)

    /**
     * Ce qu'une station fait de sa journée, en part de sa capacité occupée par des vélos, heure par
     * heure depuis 7 h 30 (31,5 = demain 7 h 30). Entre deux repères, la part suit une droite.
     */
    private enum class Rhythm(val keys: List<Pair<Double, Double>>) {
        /** Quartier d'habitation : on part au travail le matin, on rentre le soir. */
        HOMES(listOf(7.5 to 0.62, 8.25 to 0.32, 9.0 to 0.02, 10.0 to 0.03, 11.0 to 0.10, 12.5 to 0.28, 14.0 to 0.32, 17.0 to 0.42, 18.5 to 0.78, 20.0 to 0.86, 30.0 to 0.86, 31.5 to 0.62)),
        /** Quartier de bureaux : l'inverse. */
        OFFICES(listOf(7.5 to 0.30, 8.5 to 0.62, 9.5 to 0.92, 12.0 to 0.80, 14.0 to 0.86, 17.5 to 0.60, 19.0 to 0.08, 20.0 to 0.05, 30.0 to 0.06, 31.5 to 0.30)),
        /** Grande place : remplie à moitié toute la journée. */
        SQUARE(listOf(7.5 to 0.46, 9.0 to 0.58, 12.5 to 0.40, 18.0 to 0.52, 20.0 to 0.60, 31.5 to 0.46));

        fun share(hour: Double): Double {
            val after = keys.indexOfFirst { it.first >= hour }.coerceAtLeast(1)
            val (h0, v0) = keys[after - 1]
            val (h1, v1) = keys[after]
            return if (h1 == h0) v1 else v0 + (v1 - v0) * ((hour - h0) / (h1 - h0)).coerceIn(0.0, 1.0)
        }
    }

    private const val HOME = 0

    private val SITES: List<Site> by lazy { listOf(
        site(1001, "Saint-Paul", 20, Rhythm.HOMES, 0.36, 0.52, 0.42),
        site(1002, "Place des Terreaux", 24, Rhythm.OFFICES, 0.30, 0.66, 0.16),
        site(1003, "Hôtel de Ville", 16, Rhythm.OFFICES, 0.42, 0.40, 0.24),
        site(1004, "Bellecour", 40, Rhythm.SQUARE, 0.32, 0.46, 0.74),
        site(1005, "Cordeliers", 18, Rhythm.OFFICES, 0.40, 0.78, 0.46),
        site(1006, "Saint-Jean", 14, Rhythm.HOMES, 0.34, 0.22, 0.62),
        site(1007, "Croix-Rousse", 22, Rhythm.HOMES, 0.38, 0.30, 0.06),
        site(1008, "Guillotière", 20, Rhythm.SQUARE, 0.36, 0.86, 0.84)
    ) }

    private fun site(rank: Int): Site = SITES[rank]

    private fun site(id: Int, name: String, capacity: Int, rhythm: Rhythm, electricShare: Double, x: Double, y: Double): Site {
        val bikes = (rhythm.share(START_HOUR) * capacity).roundToInt()
        val electric = (bikes * electricShare).roundToInt()
        val state = VelovForecastState(electric, bikes - electric, capacity - bikes, capacity)
        val station = VelovStation(
            id = id, name = "$id - $name", lat = 0.0, lng = 0.0, bikes = bikes, ebikes = electric,
            mbikes = bikes - electric, stands = capacity - bikes, capacity = capacity
        )
        val steps = (1..VelovForecast.STEP_COUNT).map { step ->
            val hour = START_HOUR + step * VelovForecast.STEP_MINUTES / 60.0
            val horizon = sqrt(step.toDouble() / VelovForecast.STEP_COUNT)
            val median = rhythm.share(hour) * capacity
            val spread = capacity * (0.03 + 0.11 * horizon)
            val all = outlook(state, median, spread)
            val electricOutlook = outlook(state, median * electricShare, spread * 0.6)
            val mechanicalOutlook = outlook(state, median * (1 - electricShare), spread * 0.8)
            val docks = VelovForecastOutlook(
                LEVELS, all.deciles.reversed().map { state.docksLeftBy(it) },
                chance(capacity - median, spread)
            )
            VelovForecastStep(all, mechanicalOutlook, electricOutlook, docks)
        }
        return Site(station, x, y, VelovForecast(state, steps))
    }

    private fun outlook(state: VelovForecastState, median: Double, spread: Double) = VelovForecastOutlook(
        LEVELS, Z.map { state.bounded(median + it * spread) }, chance(median, spread)
    )

    /** Chance d'en trouver au moins un quand on en attend [median], à [spread] près. */
    private fun chance(median: Double, spread: Double): Double = 1 / (1 + exp(-(median - 1.5) / (0.25 * spread + 0.5)))

    /** « Plus sûr à côté » de la démonstration : Bellecour, quand la station du quartier risque d'être vide. */
    private fun saferNearby(step: Int, filter: VelovFilter): List<VelovForecastNeighbour> {
        val square = site(3)
        val outlook = square.forecast.steps[step - 1].outlook(filter)
        val chance = VelovChance.of(outlook.probability)
        if (!chance.level.isSafe) return emptyList()
        return listOf(VelovForecastNeighbour(square.station, "4 min à pied · ${VelovTexts.range(outlook.range, filter)}", chance))
    }

    private const val START_HOUR = 7.5
    private val LEVELS = VelovForecastOutlook.SHOWN_LEVELS
    /** Écart de chaque décile à la médiane, en nombre de [spread] (loi normale). */
    private val Z = listOf(-1.28, -0.52, 0.0, 0.52, 1.28)
    /** La fourchette de la démonstration tombe juste 8 fois sur 10, comme celles du modèle. */
    private val COVERAGE: Map<VelovFilter, Double> = VelovFilter.ordered.associateWith { 0.8 }
}
