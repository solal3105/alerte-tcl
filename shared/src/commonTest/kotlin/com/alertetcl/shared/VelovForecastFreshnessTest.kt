package com.alertetcl.shared

import com.alertetcl.shared.models.VelovForecastFreshness
import com.alertetcl.shared.models.VelovForecastIndex
import com.alertetcl.shared.models.VelovForecastReceipt
import com.alertetcl.shared.network.HttpClientProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VelovForecastFreshnessTest {
    private val day = 86_400L
    private val now = 1_795_000_000L

    private fun index(version: String, verifiedAt: Long, format: Int = 1) = VelovForecastIndex(format, version, verifiedAt)

    @Test
    fun aForecastIsShownOnlyWhileTheRobotKeepsConfirmingTheModel() {
        assertEquals(21, VelovForecastFreshness.MAX_VERIFIED_AGE_DAYS)
        assertTrue(VelovForecastFreshness.canShow(verifiedAt = now, now = now))
        assertTrue(VelovForecastFreshness.canShow(verifiedAt = now - 21 * day + 1, now = now))
        assertFalse(VelovForecastFreshness.canShow(verifiedAt = now - 21 * day, now = now))
        assertFalse(VelovForecastFreshness.canShow(verifiedAt = 0, now = now), "modèle jamais confirmé")
    }

    @Test
    fun theRelayIsAskedOnceADay() {
        assertTrue(VelovForecastFreshness.isCheckDue(checkedAt = 0, attemptedAt = 0, now = now), "première fois")
        assertFalse(VelovForecastFreshness.isCheckDue(checkedAt = now - day + 1, attemptedAt = now - day + 1, now = now))
        assertTrue(VelovForecastFreshness.isCheckDue(checkedAt = now - day, attemptedAt = now - day, now = now))
        assertTrue(VelovForecastFreshness.isCheckDue(checkedAt = now + 3_600, attemptedAt = 0, now = now), "horloge reculée")
    }

    @Test
    fun aRelayThatDoesNotAnswerIsAskedAgainAfterAQuarterOfAnHour() {
        assertFalse(VelovForecastFreshness.isCheckDue(checkedAt = now - 2 * day, attemptedAt = now - 899, now = now))
        assertTrue(VelovForecastFreshness.isCheckDue(checkedAt = now - 2 * day, attemptedAt = now - 900, now = now))
    }

    @Test
    fun theReceiptOnlyStandsForTheModelActuallyOnDisk() {
        val receipt = VelovForecastReceipt("2026-11-16", verifiedAt = now - day, checkedAt = now - 3_600)
        assertEquals(receipt, receipt.matching("2026-11-16"))
        assertEquals(VelovForecastReceipt("2026-11-09"), receipt.matching("2026-11-09"))
        assertEquals(VelovForecastReceipt(), receipt.matching(null))
        assertTrue(receipt.canShow(now))
        assertFalse(receipt.matching("2026-11-09").canShow(now), "un modèle sans reçu attend d'être confirmé")
    }

    @Test
    fun aNewVersionCallsForADownloadUnlessItsFormatIsUnknown() {
        val receipt = VelovForecastReceipt("2026-11-09", verifiedAt = now - 8 * day, checkedAt = now - day)
        assertFalse(receipt.isOutdatedBy(index("2026-11-09", now)))
        assertTrue(receipt.isOutdatedBy(index("2026-11-16", now)))
        assertFalse(receipt.isOutdatedBy(index("2026-11-16", now, format = 2)))
        assertTrue(VelovForecastReceipt().isOutdatedBy(index("2026-11-16", now)), "premier lancement")
    }

    @Test
    fun onlyACheckOfTheHeldVersionRenewsTheReceipt() {
        val receipt = VelovForecastReceipt("2026-11-09", verifiedAt = now - 8 * day, checkedAt = now - day)
        assertEquals(VelovForecastReceipt("2026-11-09", now - 3_600, now), receipt.answeredBy(index("2026-11-09", now - 3_600), now))
        assertEquals(receipt.copy(checkedAt = now), receipt.answeredBy(index("2026-11-16", now - 3_600), now))
        assertEquals(receipt.copy(checkedAt = now), receipt.answeredBy(index("2026-11-09", now - 3_600, format = 2), now))
    }

    @Test
    fun theIndexAndTheReceiptAreReadFromTheirFiles() {
        val json = HttpClientProvider.json
        val published = """{"format":1,"version":"2026-11-16","genere":1794800000,"verifie":1794900000,"taille":4642000}"""
        assertEquals(index("2026-11-16", 1_794_900_000), json.decodeFromString(VelovForecastIndex.serializer(), published))

        val receipt = VelovForecastReceipt("2026-11-16", verifiedAt = 1_794_900_000, checkedAt = now)
        val saved = json.encodeToString(VelovForecastReceipt.serializer(), receipt)
        assertEquals(receipt, json.decodeFromString(VelovForecastReceipt.serializer(), saved))
        assertEquals(VelovForecastReceipt(), json.decodeFromString(VelovForecastReceipt.serializer(), "{}"))
    }
}
