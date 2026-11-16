package com.alertetcl.shared.util

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.concurrent.Volatile

/**
 * Fait passer un travail à la fois et ne garde, parmi ceux qui attendent, que le dernier demandé.
 *
 * Un curseur qui glisse demande un calcul à chaque cran. Android annule les demandes dépassées, mais
 * l'annulation d'une tâche Swift n'atteint pas une fonction `suspend` de Kotlin : sans ce tri, iOS
 * calculerait un à un tous les crans traversés avant d'arriver à celui où le doigt s'est arrêté.
 */
internal class LatestOnly {
    private val mutex = Mutex()

    @Volatile
    private var latest: Any? = null

    /** Le résultat de [work], ou null s'il a été demandé autre chose pendant que celui-ci attendait son tour. */
    suspend fun <T : Any> run(work: suspend () -> T): T? {
        val ticket = Any().also { latest = it }
        return mutex.withLock { if (ticket === latest) work() else null }
    }
}
