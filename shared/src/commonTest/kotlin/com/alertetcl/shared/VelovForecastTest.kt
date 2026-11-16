package com.alertetcl.shared

import com.alertetcl.shared.VelovForecastSamples.bundle
import com.alertetcl.shared.VelovForecastSamples.leaf
import com.alertetcl.shared.VelovForecastSamples.split
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecastBundle
import com.alertetcl.shared.models.VelovForecastControl
import com.alertetcl.shared.models.VelovForecastForest
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastOutlook
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
 * - le lot est tiré des vrais fichiers du prototype (dossier `donnees/`, état du 16 novembre 2026). Le
 *   prototype ne prévoyait que l'ensemble des vélos, sur neuf déciles : chacun des dix-neuf modèles du
 *   lot (cinq déciles et une probabilité pour `velos`, `elec` et `meca`, plus `bornes_p1`) reçoit donc
 *   deux vrais arbres d'un modèle du prototype, jamais deux fois les mêmes, choisis pour couvrir le plus
 *   de variables et de types de valeur manquante. Quatre stations (1001 et 3003 ordinaires, 555 dont
 *   certaines habitudes manquent, 12006 qui n'en a aucune), le calendrier entier ;
 * - s'y ajoutent des arbres de synthèse : un nœud « manquant = zéro » de LightGBM dans `velos_p1`,
 *   un arbre réduit à une feuille dans `bornes_p1`, et soixante sondes d'un seul nœud (une par
 *   variable et par seuil) réparties sur les dix-neuf modèles, parce que le vrai modèle se sert peu du
 *   calendrier et qu'une erreur sur le jour, le mois ou l'heure passerait sinon inaperçue ;
 * - les valeurs attendues viennent du fichier `prevision.js` exécuté tel quel. Comme il ne connaît que
 *   ses propres noms de modèles, le lot lui est servi plusieurs fois, chaque modèle passant à son tour
 *   sous un nom qu'il calcule : la sortie de chaque modèle est donc celle de son parcours d'arbres et
 *   de ses variables. Pour l'ensemble des vélos, la fourchette est celle de `Prevision.prevoir` ; pour
 *   les classiques et les électriques, le script refait la même ligne (nombre présent de la sorte
 *   ajouté, tri, bornes) après avoir vérifié qu'elle redonne exactement celle des vélos. `loneMedian`
 *   est le décile 50 seul, borné mais pas reclassé parmi les autres : ce que lit un marqueur de carte.
 * Chaque sonde part des deux côtés au moins une fois sur l'ensemble des cas, et les déciles d'une même
 * sorte s'y croisent souvent (le tri compte).
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
        val bikes: Kind,
        val mechanical: Kind,
        val electric: Kind,
        val dockProbability: List<Double>,
        val dockProbabilitySum: Double
    ) {
        fun kind(filter: VelovFilter): Kind = when (filter) {
            VelovFilter.MECHANICAL -> mechanical
            VelovFilter.ELECTRIC -> electric
            else -> bikes
        }

        val forecastState get() = VelovForecastState(state.electric, state.mechanical, state.docks, state.capacity)

        /** La station dans l'état du cas, telle que le relais la donnerait. */
        val velovStation get() = VelovStation(
            id = station, name = "$station - ESSAI", lat = 45.76, lng = 4.83, bikes = state.electric + state.mechanical,
            ebikes = state.electric, mbikes = state.mechanical, stands = state.docks, capacity = state.capacity
        )
    }

    @Serializable
    private class State(val electric: Int, val mechanical: Int, val docks: Int, val capacity: Int)

    /** Ce qui est attendu d'une sorte de vélos : par échéance donnée, puis en somme sur les 96. */
    @Serializable
    private class Kind(val deciles: List<List<Double>>, val probability: List<Double>, val loneMedian: List<Double>, val sums: Sums)

    @Serializable
    private class Sums(val deciles: List<Double>, val probability: Double, val loneMedian: Double)

    private val cases = json.decodeFromString(ListSerializer(Expected.serializer()), VelovForecastFixture.EXPECTED)
    private val bikeKinds = listOf(VelovFilter.ALL, VelovFilter.MECHANICAL, VelovFilter.ELECTRIC)

    private fun assertClose(expected: Double, actual: Double, what: String) =
        assertEquals(expected, actual, 1e-9, what)

    private fun assertClose(expected: List<Double>, actual: List<Double>, what: String) {
        assertEquals(expected.size, actual.size, what)
        expected.forEachIndexed { rank, value -> assertClose(value, actual[rank], "$what, rang $rank") }
    }

    @Test
    fun theForecastMatchesTheReferencePrototype() {
        assertEquals(13, cases.size)
        for (case in cases) {
            val forecast = model.forecast(case.station, case.forecastState, case.start)

            assertEquals(96, forecast.steps.size, case.name)
            assertEquals(listOf(10, 30, 50, 70, 90), forecast.steps.first().bikes.levels)

            for (filter in bikeKinds) {
                val expected = case.kind(filter)
                case.steps.forEachIndexed { rank, number ->
                    val outlook = forecast.steps[number - 1].outlook(filter)
                    assertClose(expected.deciles[rank], outlook.deciles, "${case.name}, échéance $number, $filter")
                    assertClose(expected.probability[rank], outlook.probability, "${case.name}, échéance $number, $filter, au moins un")
                }
                val what = "${case.name}, somme des 96 échéances, $filter"
                assertClose(expected.sums.deciles, expected.sums.deciles.indices.map { rank -> forecast.steps.sumOf { it.outlook(filter).deciles[rank] } }, what)
                assertClose(expected.sums.probability, forecast.steps.sumOf { it.outlook(filter).probability }, "$what, au moins un")
            }
            case.steps.forEachIndexed { rank, number ->
                assertClose(case.dockProbability[rank], forecast.steps[number - 1].docks.probability, "${case.name}, échéance $number, au moins une place")
            }
            assertClose(case.dockProbabilitySum, forecast.steps.sumOf { it.docks.probability }, "${case.name}, au moins une place, somme")
        }
    }

    @Test
    fun oneStepAloneGivesWhatTheWholeForecastGivesThere() {
        for (case in cases) {
            val stations = listOf(case.velovStation)
            val forecast = model.forecast(case.station, case.forecastState, case.start)
            for (filter in VelovFilter.ordered) for (number in listOf(1, 2, 37, 96)) {
                val alone = model.outlooks(stations, case.start, number, filter).single()
                assertEquals(forecast.steps[number - 1].outlook(filter), alone, "${case.name}, échéance $number, $filter")
            }
        }
    }

    @Test
    fun aMapMarkerReadsTheMedianModelAndTheProbabilityOnly() {
        for (case in cases) {
            val stations = listOf(case.velovStation)
            val state = case.forecastState
            val forecast = model.forecast(case.station, state, case.start)
            var loneMedians = bikeKinds.associateWith { 0.0 }
            for (number in 1..96) for (filter in VelovFilter.ordered) {
                val glance = model.glances(stations, case.start, number, filter).single()
                val what = "${case.name}, échéance $number, $filter"
                assertEquals(forecast.steps[number - 1].outlook(filter).probability, glance.probability, what)
                val rank = case.steps.indexOf(number)
                if (filter == VelovFilter.STANDS) {
                    val bikes = model.glances(stations, case.start, number, VelovFilter.ALL).single().median
                    assertEquals(state.docksLeftBy(bikes), glance.median, what)
                } else {
                    loneMedians = loneMedians + (filter to loneMedians.getValue(filter) + glance.median)
                    if (rank >= 0) assertClose(case.kind(filter).loneMedian[rank], glance.median, what)
                }
            }
            for (filter in bikeKinds) assertClose(case.kind(filter).sums.loneMedian, loneMedians.getValue(filter), "${case.name}, somme, $filter")
        }
    }

    @Test
    fun severalStationsAtOnceAreEachComputedFromTheirOwnState() {
        val stations = cases.filter { it.start == cases.first().start }.map { it.velovStation } +
            cases.take(4).map { it.velovStation.copy(id = it.station + 1, ebikes = 0, mbikes = 2, bikes = 2) }
        val start = cases.first().start
        for (filter in VelovFilter.ordered) {
            val together = model.outlooks(stations, start, 8, filter)
            val glances = model.glances(stations, start, 8, filter)
            stations.forEachIndexed { rank, station ->
                assertEquals(model.forecast(station, start).steps[7].outlook(filter), together[rank], "${station.id}, $filter")
                assertEquals(together[rank].probability, glances[rank].probability, "${station.id}, $filter")
            }
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

    @Test
    fun theCoverageMeasuredByTheRobotIsReadForEachKind() {
        assertEquals(mapOf(VelovFilter.ALL to 0.8312, VelovFilter.MECHANICAL to 0.7461, VelovFilter.ELECTRIC to 0.9049), model.coverage)
        assertEquals(emptyMap(), VelovForecastModel(bundle()).coverage, "contrôle absent du fichier")
    }

    @Test
    fun theControlPublishedByTheRobotIsReadAsWritten() {
        // La forme décrite dans `velov-prevision/README.md` : des clés que l'application ne lit pas, une sorte sans mesure.
        val control = HttpClientProvider.json.decodeFromString(
            VelovForecastControl.serializer(),
            """{"entrainement":["2026-09-14T00:00:00Z","2026-11-09T00:00:00Z"],"lignes_entrainement":1199314,"sortes":{
                "velos":{"couv80":0.82,"horizons":[{"h":0.25,"lignes":81895,"err":1.31,"couv80":0.9}]},
                "elec":{},"meca":{"couv80":0.84,"horizons":[]},"bornes":{"couv80":0.807}}}"""
        )
        assertEquals(
            mapOf(VelovFilter.ALL to 0.82, VelovFilter.MECHANICAL to 0.84, VelovFilter.STANDS to 0.807),
            VelovForecastModel(bundle(control = control)).coverage
        )
    }

    // --- Lots écrits à la main ([VelovForecastSamples]).

    private fun firstStep(bundle: VelovForecastBundle, state: VelovForecastState = VelovForecastState(2, 2, 6, 10)): VelovForecastStep =
        VelovForecastModel(bundle).forecast(1001, state, 1_795_000_000_000L).steps.first()

    @Test
    fun decilesAreSortedThenKeptWithinTheCapacity() {
        val step = firstStep(bundle(decileShifts = listOf(30.0, -30.0, 1.5, -0.5, 0.0)))
        assertEquals(listOf(0.0, 3.5, 4.0, 5.5, 10.0), step.bikes.deciles)
        assertEquals(listOf(0.0, 1.5, 2.0, 3.5, 10.0), step.electric.deciles, "l'écart s'ajoute aux électriques présents")
        assertEquals(step.electric.deciles, step.mechanical.deciles)
    }

    @Test
    fun eachKindStartsFromItsOwnCount() {
        val step = firstStep(bundle(), VelovForecastState(electric = 5, mechanical = 3, docks = 4, capacity = 12))
        assertEquals(listOf(6.0, 7.0, 8.0, 9.0, 10.0), step.bikes.deciles)
        assertEquals(listOf(1.0, 2.0, 3.0, 4.0, 5.0), step.mechanical.deciles)
        assertEquals(listOf(3.0, 4.0, 5.0, 6.0, 7.0), step.electric.deciles)
        assertEquals(step.electric, step.outlook(VelovFilter.ELECTRIC))
        assertEquals(step.docks, step.outlook(VelovFilter.STANDS))
    }

    @Test
    fun aProbabilityGoesThroughTheSigmoidAndAQuantityDoesNot() {
        val step = firstStep(bundle(forests = mapOf("elec_p1" to VelovForecastForest("cross_entropy", listOf(leaf(0.0), leaf(0.0))))))
        assertEquals(0.5, step.bikes.probability)
        assertEquals(0.5, step.electric.probability)
        assertEquals(listOf(2.0, 3.0, 4.0, 5.0, 6.0), step.bikes.deciles)
    }

    /** Résultat brut d'un arbre posé seul dans `bornes_p1`, auquel un objectif de régression laisse la somme telle quelle. */
    private fun rawOutput(tree: VelovForecastTree, variables: List<String>, state: VelovForecastState = VelovForecastState(2, 2, 6, 10)): Double =
        firstStep(bundle(variables = variables, forests = mapOf("bornes_p1" to VelovForecastForest("regression", listOf(tree)))), state).docks.probability

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
        fun broken(tree: VelovForecastTree) = bundle(forests = mapOf("bornes_p1" to VelovForecastForest("regression", listOf(tree))))
        fun without(name: String) = VelovForecastBundle(1, "essai", listOf("velos0"), listOf(10, 30, 50, 70, 90), bundle().forests - name)

        VelovForecastModel(bundle())
        refused(bundle(format = 2))
        for (name in listOf("velos_q10", "elec_q50", "meca_q90", "velos_p1", "elec_p1", "meca_p1", "bornes_p1")) refused(without(name))
        refused(broken(split(decision = 3)))                 // seuil catégoriel
        refused(broken(split(decision = 2, left = 0)))       // nœud qui renvoie à lui-même
        refused(broken(split(decision = 2, right = -3)))     // feuille absente
        refused(broken(split(decision = 2, feature = 1)))    // variable hors de la liste
    }

    @Test
    fun theDecilesMustBeTheOnesTheScreensRead() {
        fun model(vararg deciles: Int) = VelovForecastModel(bundle(deciles = deciles.toList(), decileShifts = deciles.map { it / 10.0 }))
        model(10, 20, 30, 50, 70, 80, 90)
        assertFailsWith<IllegalArgumentException>("sans la fourchette serrée") { model(10, 50, 90) }
        assertFailsWith<IllegalArgumentException>("niveaux qui ne se répondent pas autour de 50") { model(10, 20, 30, 50, 70, 90) }
        assertFailsWith<IllegalArgumentException>("niveaux dans le désordre") { model(90, 70, 50, 30, 10) }
    }

    @Test
    fun aDecileIsReadByItsLevelNotByItsRank() {
        val forecast = VelovForecastModel(bundle(deciles = listOf(10, 20, 30, 50, 70, 80, 90), decileShifts = listOf(-3.0, -2.5, -1.0, 0.0, 1.0, 2.5, 3.0)))
            .forecast(1001, VelovForecastState(2, 2, 6, 10), 1_795_000_000_000L)
        val bikes = forecast.steps.first().bikes
        assertEquals(listOf(1.0, 3.0, 4.0, 5.0, 7.0), VelovForecastOutlook.SHOWN_LEVELS.map(bikes::at))
        assertEquals(listOf(7.0, 5.0, 4.0, 3.0, 1.0).map { 6 + 4 - it }.sorted(), VelovForecastOutlook.SHOWN_LEVELS.map(forecast.steps.first().docks::at), "les places gardent les mêmes niveaux")
        assertEquals(listOf(10, 30, 50, 70, 90), VelovForecastOutlook.SHOWN_LEVELS)
    }

    @Test
    fun freeDocksAreDeducedFromTheBikes() {
        // 4 vélos et 6 places libres sur 12 bornes : 2 sont hors service et le restent.
        val state = VelovForecastState(1, 3, 6, 12)
        assertEquals(9.0, state.docksLeftBy(1.0))
        assertEquals(0.0, state.docksLeftBy(11.0), "jamais moins de zéro")
        assertEquals(8.0, VelovForecastState(1, 3, 6, 8).docksLeftBy(1.0), "jamais plus de places que la capacité")

        val step = firstStep(bundle(decileShifts = listOf(-3.0, -1.0, 0.0, 2.0, 7.0)), state)
        assertEquals(listOf(1.0, 3.0, 4.0, 6.0, 11.0), step.bikes.deciles)
        assertEquals(listOf(0.0, 4.0, 6.0, 7.0, 9.0), step.docks.deciles, "beaucoup de vélos font peu de places : l'ordre est retourné")
    }

    @Test
    fun theStateCountsWhatEachFilterAnnounces() {
        val state = VelovForecastState(electric = 2, mechanical = 5, docks = 9, capacity = 18)
        assertEquals(listOf(7, 5, 2, 9), VelovFilter.ordered.map(state::count))
    }
}
