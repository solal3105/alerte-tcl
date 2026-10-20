package com.alertetcl.shared

import com.alertetcl.shared.network.LivePolling
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LivePollingTest {
    @Test
    fun theHeaderIsReadOnlyWhenItIsAPositiveNumber() {
        assertEquals(12_345L, LivePolling.refreshInMs("12345"))
        assertEquals(0L, LivePolling.refreshInMs(" 0 "))
        assertNull(LivePolling.refreshInMs(null))
        assertNull(LivePolling.refreshInMs("bientôt"))
        assertNull(LivePolling.refreshInMs("-5"))
    }

    @Test
    fun theAppAsksJustAfterTheRelayHasItsNextCopy() {
        repeat(50) {
            val delay = LivePolling.nextDelayMs(refreshInMs = 8_000, fetchDurationMs = 400, consecutiveErrors = 0)
            assertTrue(delay in 8_000L..9_000L, "attente $delay")
        }
    }

    @Test
    fun theAnnouncedDelayStaysWithinBounds() {
        assertEquals(LivePolling.MIN_INTERVAL_MS, LivePolling.nextDelayMs(0, 400, 0))
        assertEquals(LivePolling.MAX_INTERVAL_MS, LivePolling.nextDelayMs(45_000, 400, 0))
    }

    @Test
    fun anOlderRelayKeepsTheFifteenSecondRhythm() {
        assertEquals(14_600L, LivePolling.nextDelayMs(refreshInMs = null, fetchDurationMs = 400, consecutiveErrors = 0))
        assertEquals(2_000L, LivePolling.nextDelayMs(refreshInMs = null, fetchDurationMs = 14_000, consecutiveErrors = 0))
    }

    @Test
    fun errorsSlowDownUpToOneMinute() {
        assertEquals(22_500L, LivePolling.nextDelayMs(refreshInMs = 5_000, fetchDurationMs = 0, consecutiveErrors = 1))
        assertEquals(60_000L, LivePolling.nextDelayMs(refreshInMs = null, fetchDurationMs = 0, consecutiveErrors = 6))
    }
}
