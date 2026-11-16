package com.alertetcl.shared.models

import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.isoDayNumber
import kotlinx.datetime.toLocalDateTime
import kotlin.math.abs
import kotlin.math.exp

/**
 * Prévision Vélo'v calculée sur l'appareil à partir du modèle publié par le robot hebdomadaire.
 *
 * C'est le portage exact du prototype `velov-prevision/prevision.js` : mêmes variables, même calendrier
 * à l'heure de Lyon, même parcours des arbres que LightGBM (valeurs manquantes comprises), mêmes
 * opérations dans le même ordre, pour que les deux donnent les mêmes nombres (`VelovForecastTest`).
 *
 * Le calcul est pur : il ne lit ni l'horloge ni le réseau. Le constructeur refuse un fichier que cette
 * version ne sait pas lire, plutôt que de laisser une prévision fausse ou un plantage arriver plus tard.
 */
internal class VelovForecastModel @Throws(IllegalArgumentException::class) constructor(bundle: VelovForecastBundle) {
    val version: String = bundle.version

    private val deciles: List<Int> = bundle.deciles
    private val decileForests: List<VelovForecastForest> = bundle.deciles.map { bundle.forest("velos_q$it") }
    private val bikeForest = bundle.forest("velos_p1")
    private val dockForest = bundle.forest("bornes_p1")
    private val electricForest = bundle.forest("part_elec")

    /** Pour chaque variable attendue par les arbres, la case de [Feature] qui la fournit ([UNKNOWN_SLOT] si elle est inconnue). */
    private val featureSlots = IntArray(bundle.variables.size) { rank ->
        Feature.entries.firstOrNull { it.key == bundle.variables[rank] }?.ordinal ?: UNKNOWN_SLOT
    }
    private val sites: Map<Int, VelovForecastSite> = bundle.stations.associateBy { it.id }
    private val habits: Map<Int, DoubleArray> = compactHabits(bundle.habits)
    private val holidays: Set<String> = bundle.calendar.holidays.toSet()
    private val schoolHolidays: List<List<Long>> = bundle.calendar.schoolHolidays.filter { it.size == 2 }

    init {
        require(bundle.format == VelovForecastBundle.FORMAT) { "Format ${bundle.format} inconnu" }
        require(bundle.forests.values.all { forest -> forest.trees.all { it.isWellFormed(featureSlots.size) } }) { "Arbre illisible" }
    }

    /** Vrai si la station faisait partie de celles sur lesquelles le modèle a été entraîné. */
    fun knows(stationId: Int): Boolean = stationId in sites

    fun forecast(station: VelovStation, nowEpochMs: Long): VelovForecast =
        forecast(station.id, VelovForecastState(station), nowEpochMs)

    /**
     * Les 96 échéances d'une station à partir de son état [state] relevé à [nowEpochMs]. Une station que
     * le modèle ne connaît pas est calculée quand même, ses variables propres étant manquantes.
     */
    fun forecast(stationId: Int, state: VelovForecastState, nowEpochMs: Long): VelovForecast {
        val bikes = state.bikes
        val values = DoubleArray(UNKNOWN_SLOT + 1) { Double.NaN }
        values[Feature.BIKES.ordinal] = bikes.toDouble()
        values[Feature.ELECTRIC.ordinal] = state.electric.toDouble()
        values[Feature.MECHANICAL.ordinal] = state.mechanical.toDouble()
        values[Feature.DOCKS.ordinal] = state.docks.toDouble()
        values[Feature.CAPACITY.ordinal] = state.capacity.toDouble()
        if (bikes != 0) values[Feature.ELECTRIC_SHARE.ordinal] = state.electric.toDouble() / bikes
        values[Feature.ORIGIN_HOUR.ordinal] = moment(nowEpochMs).decimalHour
        sites[stationId]?.let { site ->
            values[Feature.ALTITUDE.ordinal] = site.altitude
            values[Feature.METRO_KM.ordinal] = site.metroKm
            values[Feature.TRAM_KM.ordinal] = site.tramKm
            values[Feature.RAIL_KM.ordinal] = site.railKm
            values[Feature.LATITUDE.ordinal] = site.lat
            values[Feature.LONGITUDE.ordinal] = site.lon
        }
        val habit = habits[stationId]
        val inputs = DoubleArray(featureSlots.size)

        val steps = (1..VelovForecast.STEP_COUNT).map { step ->
            val time = nowEpochMs + step * STEP_MS
            val target = moment(time)
            values[Feature.HORIZON_HOURS.ordinal] = step * STEP_HOURS
            values[Feature.TARGET_HOUR.ordinal] = target.decimalHour
            values[Feature.WEEKDAY.ordinal] = target.weekday.toDouble()
            values[Feature.MONTH.ordinal] = target.month.toDouble()
            values[Feature.HOLIDAY.ordinal] = if (target.holiday) 1.0 else 0.0
            values[Feature.SCHOOL_HOLIDAY.ordinal] = if (target.schoolHoliday) 1.0 else 0.0
            values[Feature.DAY_TYPE.ordinal] = target.dayType.toDouble()
            if (habit != null) {
                val offset = habitOffset(target.dayType, target.hour)
                habit.copyInto(values, Feature.HABIT_BIKES.ordinal, offset, offset + HABIT_SIZE)
            }
            for (rank in inputs.indices) inputs[rank] = values[featureSlots[rank]]

            VelovForecastStep(
                timeEpochMs = time,
                // Chaque décile est appris à part, sur l'écart au stock de départ : on les trie pour qu'ils
                // ne se croisent pas, puis on les borne à la capacité.
                bikeDeciles = decileForests.map { it.predict(inputs) + bikes }.sorted().map(state::bounded),
                bikeProbability = bikeForest.predict(inputs),
                dockProbability = dockForest.predict(inputs),
                electricShare = electricForest.predict(inputs)
            )
        }
        return VelovForecast(state, deciles, steps)
    }

    /** Calendrier d'un instant à l'heure de Lyon, comme à l'entraînement. */
    private fun moment(epochMs: Long): Moment {
        val local = Instant.fromEpochMilliseconds(epochMs).toLocalDateTime(LYON)
        return Moment(
            hour = local.hour,
            decimalHour = local.hour + local.minute / 60.0,
            weekday = local.dayOfWeek.isoDayNumber,
            month = local.monthNumber,
            holiday = local.date.toString() in holidays,
            schoolHoliday = schoolHolidays.any { epochMs >= it[0] && epochMs < it[1] }
        )
    }

    private class Moment(
        val hour: Int,
        val decimalHour: Double,
        /** 1 (lundi) à 7 (dimanche). */
        val weekday: Int,
        val month: Int,
        val holiday: Boolean,
        val schoolHoliday: Boolean
    ) {
        /** 0 en semaine, 1 le samedi, 2 le dimanche et les jours fériés. */
        val dayType: Int get() = if (holiday || weekday == 7) 2 else if (weekday == 6) 1 else 0
    }

    /**
     * Variables que cette version sait calculer, sous le nom que leur donne le modèle. Un nom absent
     * d'ici vaut « manquant » : un modèle réentraîné avec une variable de plus reste utilisable.
     */
    private enum class Feature(val key: String) {
        BIKES("velos0"),
        ELECTRIC("elec0"),
        MECHANICAL("meca0"),
        DOCKS("bornes0"),
        CAPACITY("capacite"),
        ELECTRIC_SHARE("part_elec0"),
        HORIZON_HOURS("horizon_h"),
        ORIGIN_HOUR("heure_origine"),
        TARGET_HOUR("heure_cible"),
        WEEKDAY("jour_sem"),
        MONTH("mois"),
        HOLIDAY("ferie"),
        SCHOOL_HOLIDAY("vacances"),
        DAY_TYPE("type_jour"),

        // Les quatre habitudes se suivent dans l'ordre du fichier (voir compactHabits).
        HABIT_BIKES("hab_velos"),
        HABIT_ANY_BIKE("hab1_velos"),
        HABIT_ANY_DOCK("hab1_bornes"),
        HABIT_ELECTRIC_SHARE("hab_part_elec"),
        ALTITUDE("altitude"),
        METRO_KM("dist_metro_km"),
        TRAM_KM("dist_tram_km"),
        RAIL_KM("dist_gare_km"),
        LATITUDE("lat"),
        LONGITUDE("lon")
    }

    private companion object {
        val LYON = TimeZone.of("Europe/Paris")
        const val STEP_MS = VelovForecast.STEP_MINUTES * 60_000L
        const val STEP_HOURS = VelovForecast.STEP_MINUTES / 60.0
        const val HOURS_PER_DAY = 24
        const val DAY_TYPES = 3

        /** Nombre de valeurs par « type de jour_heure » dans `habitude`. */
        const val HABIT_SIZE = 4

        /** Case toujours manquante, après celles de [Feature]. */
        val UNKNOWN_SLOT = Feature.entries.size

        // decision_type de LightGBM
        const val CATEGORICAL_BIT = 1
        const val DEFAULT_LEFT_BIT = 2
        const val MISSING_ZERO = 1
        const val MISSING_NAN = 2
        const val ZERO_THRESHOLD = 1e-35

        fun VelovForecastBundle.forest(name: String): VelovForecastForest =
            requireNotNull(forests[name]) { "Modèle $name absent" }

        /** Rang, dans le tableau d'une station, des [HABIT_SIZE] habitudes d'un type de jour à une heure. */
        fun habitOffset(dayType: Int, hour: Int): Int = (dayType * HOURS_PER_DAY + hour) * HABIT_SIZE

        /** `habitude` rangé en un tableau par station, indexé par [habitOffset] ; NaN là où le fichier n'a rien. */
        fun compactHabits(habits: Map<String, Map<String, List<Double?>>>): Map<Int, DoubleArray> = buildMap {
            for ((stationId, slots) in habits) {
                val id = stationId.toIntOrNull() ?: continue
                val table = DoubleArray(DAY_TYPES * HOURS_PER_DAY * HABIT_SIZE) { Double.NaN }
                for ((slot, averages) in slots) {
                    val dayType = slot.substringBefore('_').toIntOrNull() ?: continue
                    val hour = slot.substringAfter('_').toIntOrNull() ?: continue
                    if (dayType !in 0 until DAY_TYPES || hour !in 0 until HOURS_PER_DAY) continue
                    val offset = habitOffset(dayType, hour)
                    for (rank in 0 until minOf(HABIT_SIZE, averages.size)) averages[rank]?.let { table[offset + rank] = it }
                }
                put(id, table)
            }
        }

        fun VelovForecastForest.predict(inputs: DoubleArray): Double {
            var sum = 0.0
            for (tree in trees) sum += tree.leafFor(inputs)
            return if (objective == "binary" || objective == "cross_entropy") 1 / (1 + exp(-sum)) else sum
        }

        /** Parcours d'un arbre comme le fait LightGBM (`NumericalDecision`), valeurs manquantes comprises. */
        fun VelovForecastTree.leafFor(inputs: DoubleArray): Double {
            var node = root
            while (node >= 0) {
                var value = inputs[features[node]]
                val decision = decisions[node]
                val missing = (decision shr 2) and 3
                if (value.isNaN() && missing != MISSING_NAN) value = 0.0
                val goesLeft = if ((missing == MISSING_ZERO && abs(value) <= ZERO_THRESHOLD) || (missing == MISSING_NAN && value.isNaN())) {
                    (decision and DEFAULT_LEFT_BIT) != 0
                } else {
                    value <= thresholds[node]
                }
                node = if (goesLeft) left[node] else right[node]
            }
            return leaves[node.inv()]
        }

        /**
         * Vrai si [leafFor] peut parcourir l'arbre sans sortir des tableaux ni tourner en rond (LightGBM
         * numérote toujours un nœud après son parent) et s'il ne contient que des seuils numériques, les
         * seuls que ce parcours sait lire.
         */
        fun VelovForecastTree.isWellFormed(variableCount: Int): Boolean {
            val nodes = features.size
            fun isChild(child: Int, parent: Int) = if (child >= 0) child in (parent + 1) until nodes else child.inv() < leaves.size
            if (thresholds.size != nodes || decisions.size != nodes || left.size != nodes || right.size != nodes) return false
            return isChild(root, -1) && (0 until nodes).all { node ->
                features[node] in 0 until variableCount && (decisions[node] and CATEGORICAL_BIT) == 0 &&
                    isChild(left[node], node) && isChild(right[node], node)
            }
        }
    }
}
