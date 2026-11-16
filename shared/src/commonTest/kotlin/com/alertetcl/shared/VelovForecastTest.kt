package com.alertetcl.shared

import com.alertetcl.shared.models.VelovForecast
import com.alertetcl.shared.models.VelovForecastBundle
import com.alertetcl.shared.models.VelovForecastForest
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastState
import com.alertetcl.shared.models.VelovForecastStep
import com.alertetcl.shared.models.VelovForecastTree
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.network.HttpClientProvider
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Le calcul Kotlin doit donner les mêmes nombres que le prototype `velov-prevision/prevision.js`.
 *
 * Les données de [VelovForecastFixture] ont été produites par un script Node gardé hors du dépôt :
 * - le lot est tiré des vrais fichiers du prototype (dossier `donnees/`, état du 16 novembre 2026) : deux
 *   arbres par modèle, choisis pour couvrir le plus de variables et de types de valeur manquante,
 *   quatre stations (1001 et 3003 ordinaires, 555 dont certaines habitudes manquent, 12006 qui n'en
 *   a aucune), le calendrier entier ;
 * - s'y ajoutent des arbres de synthèse : un nœud « manquant = zéro » de LightGBM dans `velos_p1`,
 *   un arbre réduit à une feuille dans `bornes_p1`, et soixante sondes d'un seul nœud (une par
 *   variable et par seuil) réparties sur les douze modèles, parce que le vrai modèle se sert peu du
 *   calendrier et qu'une erreur sur le jour, le mois ou l'heure passerait sinon inaperçue ;
 * - les valeurs attendues sont celles de `Prevision.prevoir`, le fichier `prevision.js` étant
 *   exécuté tel quel, ses quatre fichiers lui étant servis depuis le lot.
 * Chaque sonde part des deux côtés au moins une fois sur l'ensemble des cas.
 */
class VelovForecastTest {
    private val json = HttpClientProvider.json
    private val model = VelovForecastModel(json.decodeFromString(VelovForecastBundle.serializer(), VelovForecastFixture.BUNDLE))

    @Serializable
    private class Expected(
        val name: String,
        val station: Int,
        val start: Long,
        val state: State,
        /** Échéances dont les valeurs sont données, numérotées à partir de 1. */
        val steps: List<Int>,
        val bikes: List<List<Double>>,
        val bikeProbability: List<Double>,
        val dockProbability: List<Double>,
        val electricShare: List<Double>,
        val sums: Sums
    )

    @Serializable
    private class State(val electric: Int, val mechanical: Int, val docks: Int, val capacity: Int)

    @Serializable
    private class Sums(val bikes: List<Double>, val bikeProbability: Double, val dockProbability: Double, val electricShare: Double)

    private fun assertClose(expected: Double, actual: Double, what: String) =
        assertEquals(expected, actual, 1e-9, what)

    private fun assertClose(expected: List<Double>, actual: List<Double>, what: String) {
        assertEquals(expected.size, actual.size, what)
        expected.forEachIndexed { rank, value -> assertClose(value, actual[rank], "$what, rang $rank") }
    }

    @Test
    fun theForecastMatchesTheReferencePrototype() {
        val cases = json.decodeFromString(ListSerializer(Expected.serializer()), VelovForecastFixture.EXPECTED)
        assertEquals(13, cases.size)
        for (case in cases) {
            val state = VelovForecastState(case.state.electric, case.state.mechanical, case.state.docks, case.state.capacity)
            val forecast = model.forecast(case.station, state, case.start)

            assertEquals(96, forecast.steps.size, case.name)
            assertEquals(listOf(10, 20, 30, 40, 50, 60, 70, 80, 90), forecast.deciles)
            forecast.steps.forEachIndexed { rank, step -> assertEquals(case.start + (rank + 1) * 900_000L, step.timeEpochMs, case.name) }

            case.steps.forEachIndexed { rank, number ->
                val step = forecast.steps[number - 1]
                val what = "${case.name}, échéance $number"
                assertClose(case.bikes[rank], step.bikeDeciles, "$what, vélos")
                assertClose(case.bikeProbability[rank], step.bikeProbability, "$what, au moins un vélo")
                assertClose(case.dockProbability[rank], step.dockProbability, "$what, au moins une place")
                assertClose(case.electricShare[rank], step.electricShare, "$what, part d'électriques")
            }
            val what = "${case.name}, somme des 96 échéances"
            assertClose(case.sums.bikes, case.sums.bikes.indices.map { rank -> forecast.steps.sumOf { it.bikeDeciles[rank] } }, "$what, vélos")
            assertClose(case.sums.bikeProbability, forecast.steps.sumOf { it.bikeProbability }, "$what, au moins un vélo")
            assertClose(case.sums.dockProbability, forecast.steps.sumOf { it.dockProbability }, "$what, au moins une place")
            assertClose(case.sums.electricShare, forecast.steps.sumOf { it.electricShare }, "$what, part d'électriques")
        }
    }

    @Test
    fun theStationSheetFeedsItsOwnStateToTheModel() {
        val station = VelovStation(
            id = 1001, name = "1001 - TERREAUX / TERME", lat = 45.7676, lng = 4.8321,
            bikes = 8, ebikes = 3, mbikes = 0, stands = 8, capacity = 16
        )
        val now = 1_795_000_000_000L
        val forecast = model.forecast(station, now)
        assertEquals(VelovForecastState(electric = 3, mechanical = 5, docks = 8, capacity = 16), forecast.state)
        assertEquals(model.forecast(1001, forecast.state, now), forecast)
        assertTrue(model.knows(1001))
        assertFalse(model.knows(99_999))
    }

    // --- Lots écrits à la main : chaque modèle se réduit à une feuille, sauf ceux que le test remplace.

    private fun leaf(value: Double) =
        VelovForecastTree(IntArray(0), DoubleArray(0), IntArray(0), IntArray(0), IntArray(0), doubleArrayOf(value), root = -1)

    /** Un nœud sur la première variable, seuil 0,5 : feuille 1 à gauche, feuille 2 à droite. */
    private fun split(decision: Int, left: Int = -1, right: Int = -2, feature: Int = 0) = VelovForecastTree(
        intArrayOf(feature), doubleArrayOf(0.5), intArrayOf(decision), intArrayOf(left), intArrayOf(right), doubleArrayOf(1.0, 2.0), root = 0
    )

    private fun bundle(
        format: Int = 1,
        variables: List<String> = listOf("velos0"),
        decileShifts: List<Double> = listOf(-1.0, 0.0, 1.0),
        forests: Map<String, VelovForecastForest> = emptyMap()
    ) = VelovForecastBundle(
        format = format,
        version = "essai",
        variables = variables,
        deciles = decileShifts.indices.map { (it + 1) * 10 },
        forests = decileShifts.mapIndexed { rank, shift -> "velos_q${(rank + 1) * 10}" to VelovForecastForest("quantile", listOf(leaf(shift))) }.toMap() +
            listOf("velos_p1", "bornes_p1", "part_elec").associateWith { VelovForecastForest("binary", listOf(leaf(0.0))) } +
            forests
    )

    private fun firstStep(bundle: VelovForecastBundle, state: VelovForecastState = VelovForecastState(2, 2, 6, 10)): VelovForecastStep =
        VelovForecastModel(bundle).forecast(1001, state, 1_795_000_000_000L).steps.first()

    @Test
    fun decilesAreSortedThenKeptWithinTheCapacity() {
        val step = firstStep(bundle(decileShifts = listOf(30.0, -30.0, 1.5, -0.5)))
        assertEquals(listOf(0.0, 3.5, 5.5, 10.0), step.bikeDeciles)
    }

    @Test
    fun aProbabilityGoesThroughTheSigmoidAndAQuantityDoesNot() {
        val step = firstStep(bundle(forests = mapOf("part_elec" to VelovForecastForest("cross_entropy", listOf(leaf(0.0), leaf(0.0))))))
        assertEquals(0.5, step.bikeProbability)
        assertEquals(0.5, step.electricShare)
        assertEquals(listOf(3.0, 4.0, 5.0), step.bikeDeciles)
    }

    /** Résultat brut d'un arbre posé seul dans `part_elec`, dont l'objectif de régression laisse la somme telle quelle. */
    private fun rawOutput(tree: VelovForecastTree, variables: List<String>, state: VelovForecastState = VelovForecastState(2, 2, 6, 10)): Double =
        firstStep(bundle(variables = variables, forests = mapOf("part_elec" to VelovForecastForest("regression", listOf(tree)))), state).electricShare

    @Test
    fun aVariableTheAppDoesNotKnowCountsAsMissing() {
        val unknown = listOf("meteo_de_demain")
        assertEquals(1.0, rawOutput(split(decision = 10), unknown), "manquant envoyé à gauche")
        assertEquals(2.0, rawOutput(split(decision = 8), unknown), "manquant envoyé à droite")
        assertEquals(1.0, rawOutput(split(decision = 2), unknown), "sans manquant prévu, compté pour zéro")
    }

    @Test
    fun missingValuesFollowTheDirectionLearntByLightGbm() {
        val empty = VelovForecastState(0, 0, 10, 10)
        val share = listOf("part_elec0")
        assertEquals(1.0, rawOutput(split(decision = 10), share, empty), "sans vélo, la part d'électriques manque")
        assertEquals(2.0, rawOutput(split(decision = 8), share, empty))
        assertEquals(1.0, rawOutput(split(decision = 10), share), "2 électriques sur 4 : 0,5 est sous le seuil")
        // « Manquant = zéro » : zéro vélo suit la direction par défaut, pas la comparaison au seuil.
        assertEquals(2.0, rawOutput(split(decision = 4), listOf("velos0"), empty))
        assertEquals(1.0, rawOutput(split(decision = 6), listOf("velos0"), empty))
        assertEquals(2.0, rawOutput(split(decision = 6), listOf("velos0")), "4 vélos : au-dessus du seuil")
    }

    @Test
    fun aBundleThisVersionCannotReadIsRefused() {
        fun refused(bundle: VelovForecastBundle) { assertFailsWith<IllegalArgumentException> { VelovForecastModel(bundle) } }
        fun broken(tree: VelovForecastTree) = bundle(forests = mapOf("part_elec" to VelovForecastForest("regression", listOf(tree))))

        VelovForecastModel(bundle())
        refused(bundle(format = 2))
        refused(VelovForecastBundle(1, "essai", listOf("velos0"), listOf(10), bundle().forests - "velos_q10"))
        refused(broken(split(decision = 3)))                 // seuil catégoriel
        refused(broken(split(decision = 2, left = 0)))       // nœud qui renvoie à lui-même
        refused(broken(split(decision = 2, right = -3)))     // feuille absente
        refused(broken(split(decision = 2, feature = 1)))    // variable hors de la liste
    }

    @Test
    fun freeDocksAreDeducedFromTheBikes() {
        fun step(vararg bikes: Double) = VelovForecastStep(0, bikes.toList(), 1.0, 1.0, 0.5)
        // 4 vélos et 6 places libres sur 12 bornes : 2 sont hors service et le restent.
        val forecast = VelovForecast(VelovForecastState(1, 3, 6, 12), listOf(10, 50, 90), emptyList())
        assertEquals(listOf(0.0, 6.0, 9.0), forecast.derivedDockDeciles(step(1.0, 4.0, 11.0)))
        assertEquals(listOf(4.5, 10.0, 10.0), forecast.derivedDockDeciles(step(0.0, 0.0, 5.5)))

        val small = VelovForecast(VelovForecastState(1, 3, 6, 8), listOf(10, 50, 90), emptyList())
        assertEquals(listOf(0.0, 6.0, 8.0), small.derivedDockDeciles(step(1.0, 4.0, 11.0)), "jamais plus de places que la capacité")
    }
}
