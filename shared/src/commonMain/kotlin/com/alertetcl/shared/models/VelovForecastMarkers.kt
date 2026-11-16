package com.alertetcl.shared.models

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.yield
import kotlin.concurrent.Volatile
import kotlin.coroutines.CoroutineContext
import kotlin.math.abs

/**
 * Le marqueur d'une station sur la carte quand le curseur d'heure a quitté « Maintenant » : la
 * fourchette de ce que compte le filtre, la même que le chiffre de la fiche, écrite court (« 3–8 »,
 * « 5 » quand ses deux bornes sont égales), et la couleur de la chance d'en trouver au moins un (verte
 * dès « probable », orange « incertain », rouge « peu probable »).
 */
data class VelovForecastMarker(val station: VelovStation, val label: String, val availability: AvailabilityColor)

/**
 * Les marqueurs prévus de toutes les stations, échéance par échéance, calculés d'avance pour que le
 * curseur de la carte réponde tout de suite à chaque position.
 *
 * [prepare] lance en arrière-plan le calcul des 96 échéances, en partant de celles qui entourent la
 * dernière demandée ; [at] répond aussitôt pour une échéance prête, et fait passer avant les autres
 * celle qu'il attend. Tout est oublié et recommencé dès que le relevé des stations, l'heure de départ
 * ou le filtre change : n'est gardé qu'un jeu de 96 listes au plus.
 *
 * Une station fermée ou que le modèle ne connaît pas n'a pas de marqueur : l'application ne montre pas
 * une estimation qu'elle n'a pas, et un marqueur gris sans nombre dirait « fermée », ce qu'elle ne sait
 * pas davantage pour demain. La station réapparaît dès que le curseur revient à « Maintenant ».
 *
 * Tout l'état est lu et écrit dans [serial], un contexte qui n'exécute qu'une tâche à la fois : la
 * classe peut être appelée de n'importe quel fil. Les calculs y passent un à un, ce qui laisse passer
 * une demande entre deux échéances.
 */
internal class VelovForecastMarkers(
    private val model: VelovForecastModel,
    private val scope: CoroutineScope,
    private val serial: CoroutineContext
) {
    private data class Request(val stations: List<VelovStation>, val originEpochMs: Long, val filter: VelovFilter)

    private var request: Request? = null

    /** Les stations qui ont une prévision, parmi celles de [request]. */
    private var forecastable: List<VelovStation> = emptyList()
    private val bySteps = HashMap<Int, List<VelovForecastMarker>>()

    /** Les échéances attendues par [at] et pas encore calculées. */
    private val awaited = HashMap<Int, CompletableDeferred<List<VelovForecastMarker>>>()

    /** La dernière échéance demandée : le calcul part de là. */
    private var aim = 1
    private var filling: Job? = null

    /**
     * La dernière demande faite à [at]. Un curseur qui glisse en fait une à chaque cran, et l'annulation
     * d'une tâche Swift n'atteint pas une fonction `suspend` de Kotlin : une demande dépassée répond donc
     * null d'elle-même.
     */
    @Volatile
    private var latest: Any? = null

    /** Lance le calcul de toutes les échéances ; sans effet si elles sont déjà prêtes ou en cours pour les mêmes arguments. */
    suspend fun prepare(stations: List<VelovStation>, originEpochMs: Long, filter: VelovFilter) {
        withContext(serial) {
            select(Request(stations, originEpochMs, filter))
            fill()
        }
    }

    /**
     * Les marqueurs à l'échéance [step] ; aucun hors de 1 à 96, l'échéance 0 étant l'état réel. Une
     * échéance prête revient aussitôt ; sinon elle est calculée avant les autres, et la réponse est null
     * si une autre demande est arrivée entre-temps.
     */
    suspend fun at(stations: List<VelovStation>, originEpochMs: Long, step: Int, filter: VelovFilter): List<VelovForecastMarker>? {
        if (step !in 1..VelovForecast.STEP_COUNT) return emptyList()
        val ticket = Any().also { latest = it }
        val answer = withContext(serial) {
            select(Request(stations, originEpochMs, filter))
            aim = step
            fill()
            bySteps[step]?.let { CompletableDeferred(it) } ?: awaited.getOrPut(step) { CompletableDeferred() }
        }
        return answer.await().takeIf { ticket === latest }
    }

    /** Les échéances déjà calculées, pour les tests et les mesures. */
    suspend fun readySteps(): Set<Int> = withContext(serial) { bySteps.keys.toSet() }

    /**
     * Change de relevé, d'heure ou de filtre. Les demandes en attente le restent : elles recevront les
     * marqueurs de la même échéance pour ce qui est demandé maintenant, le plus récent.
     */
    private fun select(next: Request) {
        if (next == request) return
        request = next
        forecastable = next.stations.filter { it.open && model.knows(it.id) }
        bySteps.clear()
    }

    private fun fill() {
        if (filling?.isActive == true) return
        filling = scope.launch(serial) {
            while (true) {
                val step = nextStep(aim, bySteps.keys) ?: break
                val markers = compute(step)
                bySteps[step] = markers
                awaited.remove(step)?.complete(markers)
                yield()
            }
        }
    }

    private fun compute(step: Int): List<VelovForecastMarker> {
        val request = request ?: return emptyList()
        val outlooks = model.outlooks(forecastable, request.originEpochMs, step, request.filter)
        return forecastable.mapIndexed { rank, station ->
            VelovForecastMarker(station, VelovTexts.shortRange(outlooks[rank].range), VelovChance.of(outlooks[rank].probability).level.availability)
        }
    }

    companion object {
        /**
         * La prochaine échéance à calculer : celle qui manque au plus près de [aim], la suivante avant la
         * précédente à égale distance (le curseur avance plus souvent qu'il ne recule) ; null si toutes sont prêtes.
         */
        fun nextStep(aim: Int, ready: Set<Int>): Int? =
            (1..VelovForecast.STEP_COUNT).filter { it !in ready }.minWithOrNull(compareBy<Int>({ abs(it - aim) }, { it < aim }))
    }
}
