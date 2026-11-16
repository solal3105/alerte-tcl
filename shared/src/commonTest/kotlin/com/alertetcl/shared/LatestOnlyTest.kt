package com.alertetcl.shared

import com.alertetcl.shared.util.LatestOnly
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class LatestOnlyTest {
    @Test
    fun workAskedOneAtATimeIsAlwaysDone() = runTest {
        val queue = LatestOnly()
        assertEquals(listOf("a", "b", "c"), listOf("a", "b", "c").map { queue.run { it } })
    }

    @Test
    fun amongThoseWaitingOnlyTheLastAskedIsDone() = runTest {
        val queue = LatestOnly()
        val gate = CompletableDeferred<Unit>()
        val done = mutableListOf<Int>()
        val results = (1..5).map { step ->
            async {
                queue.run {
                    if (step == 1) gate.await()
                    done += step
                    step
                }
            }.also { yield() }
        }
        // Le premier calcul est en cours ; quatre autres crans du curseur attendent derrière lui.
        gate.complete(Unit)
        assertEquals(listOf(1, null, null, null, 5), results.map { it.await() })
        assertEquals(listOf(1, 5), done, "les crans dépassés ne sont pas calculés")
    }

    @Test
    fun workThatFailsLetsTheNextOneThrough() = runTest {
        val queue = LatestOnly()
        assertNull(runCatching { queue.run<Int> { error("panne") } }.getOrNull())
        assertEquals(2, queue.run { 2 })
    }
}
