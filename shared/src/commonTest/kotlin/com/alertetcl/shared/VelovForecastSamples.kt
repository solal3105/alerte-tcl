package com.alertetcl.shared

import com.alertetcl.shared.models.VelovForecastBundle
import com.alertetcl.shared.models.VelovForecastControl
import com.alertetcl.shared.models.VelovForecastForest
import com.alertetcl.shared.models.VelovForecastSite
import com.alertetcl.shared.models.VelovForecastTree
import kotlin.math.ln

/**
 * Lots de prévision écrits à la main pour les tests : chaque modèle s'y réduit à une feuille, sauf
 * ceux que le test remplace.
 */
internal object VelovForecastSamples {
    /** Lundi 16 novembre 2026, 18 h 45 à Lyon : le départ des maquettes. */
    const val MONDAY_EVENING = 1_794_851_100_000L

    val BIKE_KINDS = listOf("velos", "elec", "meca")

    fun leaf(value: Double) =
        VelovForecastTree(IntArray(0), DoubleArray(0), IntArray(0), IntArray(0), IntArray(0), doubleArrayOf(value), root = -1)

    /** Un nœud sur la première variable, seuil 0,5 : feuille 1 à gauche, feuille 2 à droite. */
    fun split(decision: Int, left: Int = -1, right: Int = -2, feature: Int = 0) = VelovForecastTree(
        intArrayOf(feature), doubleArrayOf(0.5), intArrayOf(decision), intArrayOf(left), intArrayOf(right), doubleArrayOf(1.0, 2.0), root = 0
    )

    /**
     * Un escalier sur la variable de rang [feature] : `values[i]` tant qu'elle ne dépasse pas
     * `thresholds[i]`, la dernière valeur au-delà.
     */
    fun stairs(thresholds: List<Double>, values: List<Double>, feature: Int = 0): VelovForecastTree {
        val nodes = thresholds.indices
        return VelovForecastTree(
            features = IntArray(thresholds.size) { feature },
            thresholds = thresholds.toDoubleArray(),
            decisions = IntArray(thresholds.size) { 2 },
            left = IntArray(thresholds.size) { it.inv() },
            right = IntArray(thresholds.size) { if (it == nodes.last) (it + 1).inv() else it + 1 },
            leaves = values.toDoubleArray(),
            root = 0
        )
    }

    /** Ce qu'une feuille doit valoir pour qu'un modèle de probabilité réponde [probability]. */
    fun logit(probability: Double): Double = ln(probability / (1 - probability))

    fun probability(vararg trees: VelovForecastTree) = VelovForecastForest("binary", trees.toList())

    fun quantity(vararg trees: VelovForecastTree) = VelovForecastForest("quantile", trees.toList())

    /** Les trois sortes de vélos partagent les mêmes écarts [decileShifts], un par niveau de [deciles] ; chaque probabilité vaut 0,5. */
    fun bundle(
        format: Int = 1,
        variables: List<String> = listOf("velos0"),
        deciles: List<Int> = listOf(10, 30, 50, 70, 90),
        decileShifts: List<Double> = listOf(-2.0, -1.0, 0.0, 1.0, 2.0),
        forests: Map<String, VelovForecastForest> = emptyMap(),
        stations: List<VelovForecastSite> = emptyList(),
        control: VelovForecastControl = VelovForecastControl()
    ) = VelovForecastBundle(
        format = format,
        version = "essai",
        variables = variables,
        deciles = deciles,
        forests = BIKE_KINDS.flatMap { kind ->
            deciles.mapIndexed { rank, level -> "${kind}_q$level" to quantity(leaf(decileShifts[rank])) }
        }.toMap() + (BIKE_KINDS + "bornes").associate { "${it}_p1" to probability(leaf(0.0)) } + forests,
        stations = stations,
        control = control
    )
}
