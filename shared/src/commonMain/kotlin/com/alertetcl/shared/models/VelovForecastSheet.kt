package com.alertetcl.shared.models

import kotlin.math.max
import kotlin.math.min

/**
 * Un point du graphique d'une fiche : ce qui est compté (vélos, classiques, électriques ou places) à
 * une échéance, de 0 à [VelovForecastPanel.scaleMax].
 */
data class VelovForecastChartPoint(
    /** Place sur l'axe des heures, de 0 (maintenant) à 1 (dans 24 h). */
    val position: Double,
    /** Le plus probable : la courbe. */
    val median: Double,
    /** Fourchette large (déciles 10 et 90), celle du « N fois sur 10 » : la bande claire. */
    val low: Double,
    val high: Double,
    /** Fourchette serrée (déciles 30 et 70) : la bande soutenue. */
    val midLow: Double,
    val midHigh: Double
)

/** Ce que la fiche montre pour un filtre, quelle que soit l'échéance choisie : le graphique et son curseur. */
data class VelovForecastPanel(
    /**
     * Les 97 points du graphique. Le premier est l'état réel de la station ; les 96 autres sont les
     * échéances, légèrement lissées (moyenne de trois voisines) pour le dessin seulement. Le curseur de
     * l'échéance `k` se pose sur `points[k]`.
     */
    val points: List<VelovForecastChartPoint>,
    /** Haut de l'axe vertical, seul nombre qui y est écrit : la capacité de la station. */
    val scaleMax: Int,
    /** Trait de minuit et nom du jour qui commence (« mardi »). */
    val midnight: VelovForecastTick?,
    /** Heures écrites sous le curseur, toutes les 6 h. */
    val ticks: List<VelovForecastTick>,
    /**
     * Couleur de la piste du curseur (`AppColors.velovChanceTrack`) : le palier de chacune des 96
     * échéances. Le segment de rang `i` va de la position `i / 96` à `(i + 1) / 96`.
     */
    val trackLevels: List<VelovChanceLevel>,
    /** « Souvent vide demain de 7 h à 9 h 45 » ; null quand aucune période n'est à risque. */
    val risk: String?
)

/** Ce que la fiche écrit pour un filtre à l'échéance choisie. */
data class VelovForecastReadout(
    /** L'échéance retenue, de 0 (maintenant) à 96. */
    val step: Int,
    /** « Maintenant », « Dans 30 min · 19 h 15 », « Demain · 8 h 30 » */
    val time: String,
    /** Le chiffre principal : « 7 à 17 vélos », ou le compte réel à l'échéance 0. */
    val count: String,
    /** « 8 fois sur 10 » sous la fourchette ; null maintenant, ou si le robot n'a pas mesuré la fourchette. */
    val reliability: String?,
    /** La chance d'en trouver au moins un ; null maintenant. */
    val chance: VelovChance?,
    /** « Plus sûr à côté » : vide tant que la chance est au moins « probable », et maintenant. */
    val saferNearby: List<VelovForecastNeighbour>
)

/**
 * La prévision d'une station telle que sa fiche la montre, pour chaque [VelovFilter] (celui de la carte
 * à l'ouverture). Les vues n'y calculent rien : [panel] donne le graphique et le curseur d'un filtre,
 * [readout] les textes de l'échéance sous le curseur. Les deux se lisent sur le fil principal.
 *
 * L'échéance va de 0, l'état réel (rien n'y est prévu), à 96, dans 24 h. La fourchette écrite est celle
 * des déciles 10 et 90 non lissés, la seule dont le robot mesure la justesse.
 */
class VelovForecastSheet internal constructor(
    private val forecast: VelovForecast,
    originEpochMs: Long,
    /** Part des cas où la fourchette a dit vrai, par filtre ([VelovForecastModel.coverage]). */
    private val coverage: Map<VelovFilter, Double>,
    private val saferNearby: (step: Int, filter: VelovFilter) -> List<VelovForecastNeighbour>
) {
    private val timeline = VelovForecastTimeline(originEpochMs)
    private val panels: Map<VelovFilter, VelovForecastPanel> = VelovFilter.ordered.associateWith(::buildPanel)

    fun panel(filter: VelovFilter): VelovForecastPanel = panels.getValue(filter)

    /** Les textes de l'échéance [step], ramenée entre 0 et 96. */
    fun readout(filter: VelovFilter, step: Int): VelovForecastReadout {
        val shown = VelovForecastTimeline.bounded(step)
        if (shown == 0) {
            return VelovForecastReadout(0, VelovForecastTimeline.NOW, VelovTexts.count(forecast.state.count(filter), filter), null, null, emptyList())
        }
        val outlook = outlook(shown, filter)
        val chance = VelovChance.of(outlook.probability)
        return VelovForecastReadout(
            step = shown,
            time = if (timeline.isNextDay(shown) && shown > SOON_STEPS) "Demain · ${timeline.clock(shown)}"
            else "Dans ${VelovForecastTimeline.delay(shown)} · ${timeline.clock(shown)}",
            count = VelovTexts.range(outlook.range, filter),
            reliability = VelovTexts.reliability(coverage[filter]),
            chance = chance,
            saferNearby = if (chance.level.isSafe) emptyList() else saferNearby(shown, filter)
        )
    }

    private fun outlook(step: Int, filter: VelovFilter): VelovForecastOutlook = forecast.steps[step - 1].outlook(filter)

    private fun buildPanel(filter: VelovFilter): VelovForecastPanel {
        val now = forecast.state.count(filter).toDouble()
        val outlooks = forecast.steps.map { it.outlook(filter) }
        val curves = VelovForecastOutlook.SHOWN_LEVELS.associateWith { level -> smoothed(outlooks.map { it.at(level) }) }
        fun curve(level: Int, rank: Int): Double = curves.getValue(level)[rank]
        val levels = outlooks.map { VelovChance.of(it.probability).level }
        return VelovForecastPanel(
            points = listOf(VelovForecastChartPoint(0.0, now, now, now, now, now)) + outlooks.indices.map { rank ->
                VelovForecastChartPoint(
                    position = VelovForecastTimeline.position(rank + 1),
                    median = curve(VelovForecastOutlook.MEDIAN, rank),
                    low = curve(VelovForecastOutlook.LOW, rank),
                    high = curve(VelovForecastOutlook.HIGH, rank),
                    midLow = curve(VelovForecastOutlook.MID_LOW, rank),
                    midHigh = curve(VelovForecastOutlook.MID_HIGH, rank)
                )
            },
            scaleMax = maxOf(1, forecast.state.capacity, forecast.state.count(filter)),
            midnight = timeline.midnight,
            ticks = timeline.ticks(TICK_HOURS),
            trackLevels = levels,
            risk = risk(levels, filter)
        )
    }

    /**
     * La première suite d'échéances « peu probable » : « Souvent vide demain de 7 h à 9 h 45 », « … vers
     * 7 h » si elle n'en compte qu'une, « … à partir de 17 h » si elle court jusqu'à la dernière échéance
     * (rien ne dit qu'elle s'arrête là).
     */
    private fun risk(levels: List<VelovChanceLevel>, filter: VelovFilter): String? {
        val start = levels.indexOf(VelovChanceLevel.UNLIKELY)
        if (start < 0) return null
        val length = levels.drop(start).takeWhile { it == VelovChanceLevel.UNLIKELY }.size
        val first = start + 1
        val last = start + length
        val day = if (timeline.isNextDay(first)) " demain" else ""
        val hours = when {
            last == VelovForecast.STEP_COUNT -> "à partir de ${timeline.clock(first)}"
            first == last -> "vers ${timeline.clock(first)}"
            else -> "de ${timeline.clock(first)} à ${timeline.clock(last)}"
        }
        return "${VelovTexts.shortage(filter)}$day $hours"
    }

    companion object {
        /** Titre de la liste [VelovForecastReadout.saferNearby]. */
        const val SAFER_NEARBY_TITLE = "Plus sûr à côté"

        private const val TICK_HOURS = 6

        /** Jusqu'à 2 h, une échéance s'annonce par son délai (« Dans 1 h 30 ») même si elle tombe après minuit. */
        private const val SOON_STEPS = 8

        /**
         * La fiche de [station] dans son état relevé à [originEpochMs], ou null quand il n'y a rien à
         * prévoir : station fermée, ou que le modèle ne connaît pas. [stations] sert aux voisines.
         */
        internal fun of(model: VelovForecastModel, station: VelovStation, stations: List<VelovStation>, originEpochMs: Long): VelovForecastSheet? {
            if (!station.open || !model.knows(station.id)) return null
            val nearby = VelovForecastNearby(model, station, stations, originEpochMs)
            return VelovForecastSheet(model.forecast(station, originEpochMs), originEpochMs, model.coverage, nearby::saferAt)
        }

        /** Moyenne de chaque valeur avec ses deux voisines (la première et la dernière comptent double). */
        private fun smoothed(values: List<Double>): List<Double> =
            values.indices.map { rank -> (values[max(0, rank - 1)] + values[rank] + values[min(values.lastIndex, rank + 1)]) / 3 }
    }
}
