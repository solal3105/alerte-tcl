package com.alertetcl.shared

import com.alertetcl.shared.models.AlertNotificationPhase
import com.alertetcl.shared.models.AlertNotifications
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.LineSubscriptions
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransportLine
import com.alertetcl.shared.models.TransportMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LineSubscriptionTest {
    private val c3 = TransportLine.create("C3", "C3", TransportMode.BUS_C)
    private val metroA = TransportLine.create("A", "MA", TransportMode.METRO)

    private fun alert(line: String, type: String, debut: Long? = null, fin: Long? = null, cli: String = line) = TCLAlert(
        id = "$line-$type", type = type, cause = "", debutEpoch = debut, finEpoch = fin,
        mode = TransportMode.BUS, ligneCom = line, ligneCli = cli, titre = "Titre", message = "Message"
    )

    @Test
    fun subscribeRegistersBothLineCodes() {
        val subs = LineSubscriptions.subscribe(emptyMap(), metroA)
        assertTrue("A" in subs && "MA" in subs)
        assertTrue(LineSubscriptions.isSubscribed(subs, metroA))
        assertEquals(LineSubscriptions.allSeverities, LineSubscriptions.preferences(subs, metroA))
        assertTrue(LineSubscriptions.unsubscribe(subs, metroA).isEmpty())
    }

    @Test
    fun emptySeveritiesMeansUnsubscribe() {
        val subs = LineSubscriptions.subscribe(emptyMap(), c3, setOf(AlertSeverity.MAJOR))
        assertEquals(setOf(AlertSeverity.MAJOR), LineSubscriptions.preferences(subs, c3))
        assertTrue(LineSubscriptions.subscribe(subs, c3, emptySet()).isEmpty())
    }

    @Test
    fun encodingRoundTripsAndMatchesIosFormat() {
        val subs = LineSubscriptions.subscribe(emptyMap(), c3, setOf(AlertSeverity.MAJOR, AlertSeverity.DISRUPTION))
        val encoded = LineSubscriptions.encode(subs)
        assertTrue("\"lineId\":\"C3\"" in encoded)
        assertTrue("Perturbation majeure" in encoded)
        assertEquals(subs, LineSubscriptions.decode(encoded))
        assertTrue(LineSubscriptions.decode("pas du json").isEmpty())
    }

    @Test
    fun concernsFiltersBySeverity() {
        val subs = LineSubscriptions.subscribe(emptyMap(), c3, setOf(AlertSeverity.MAJOR))
        assertTrue(LineSubscriptions.concerns(subs, alert("C3", "Perturbation majeure")))
        assertFalse(LineSubscriptions.concerns(subs, alert("C3", "Information")))
        assertFalse(LineSubscriptions.concerns(subs, alert("C5", "Perturbation majeure")))
    }

    @Test
    fun migrationKeepsFavoritesAndTheirSeverities() {
        val migrated = LineSubscriptions.migrateFromFavorites(
            existing = emptyMap(),
            favoriteLines = setOf("C3", "A"),
            severityPreferences = mapOf("C3" to setOf(AlertSeverity.INFO)),
            lines = listOf(c3, metroA)
        )
        assertEquals(setOf(AlertSeverity.INFO), LineSubscriptions.preferences(migrated, c3))
        assertTrue(LineSubscriptions.isSubscribed(migrated, metroA))
        assertEquals(migrated, LineSubscriptions.migrateFromFavorites(migrated, setOf("T1"), emptyMap(), emptyList()))
    }

    @Test
    fun pendingNotificationsFollowPhasesAndSeenKeys() {
        val subs = LineSubscriptions.subscribe(emptyMap(), c3)
        val now = 1_000_000L
        val upcoming = alert("C3", "Perturbation", debut = now + 3600)
        val ongoing = alert("C3", "Information", debut = now - 3600, fin = now + 3600)
        val expired = alert("C3", "Perturbation majeure", fin = now - 10)
        val other = alert("C5", "Perturbation majeure")

        val pending = AlertNotifications.pending(listOf(upcoming, ongoing, expired, other), subs, emptySet(), now)
        assertEquals(listOf(AlertNotificationPhase.ANNOUNCED, AlertNotificationPhase.ACTIVE), pending.map { it.phase })
        assertEquals(listOf(upcoming.id, ongoing.id), pending.map { it.alert.id })

        val seen = AlertNotifications.remember(emptyList(), pending.map { it.key })
        assertTrue(AlertNotifications.pending(listOf(upcoming, ongoing), subs, seen.toSet(), now).isEmpty())
        assertEquals(4, AlertNotifications.baselineKeys(listOf(upcoming, ongoing, other), subs).size)
    }

    @Test
    fun seenKeysArePurgedKeepingTheMostRecent() {
        val keys = (1..AlertNotifications.MAX_SEEN_KEYS).map { "k$it" }
        val purged = AlertNotifications.remember(keys, listOf("nouvelle"))
        assertEquals(AlertNotifications.MAX_SEEN_KEYS / 2, purged.size)
        assertEquals("nouvelle", purged.last())
    }

    @Test
    fun notificationTitlesUseTheCustomerLineCode() {
        val a = alert("302A", "Perturbation", cli = "C3")
        assertEquals("Bus C3 : à venir", AlertNotifications.title(a, AlertNotificationPhase.ANNOUNCED))
        assertEquals("Bus C3", AlertNotifications.title(a, AlertNotificationPhase.ACTIVE))
        assertEquals("À venir : Titre", AlertNotifications.subtitle(a, AlertNotificationPhase.ANNOUNCED))
    }
}

class AlertDatesTest {
    // 15 septembre 2026 à 14:30, heure de Paris (UTC+2)
    private val now = 1_789_475_400L

    @Test
    fun startLabelDependsOnDistance() {
        assertEquals("Il y a 12 min", com.alertetcl.shared.models.AlertDates.startLabel(now - 12 * 60, now))
        assertEquals("09:05", com.alertetcl.shared.models.AlertDates.startLabel(now - 5 * 3600 - 25 * 60, now))
        assertEquals("1er sept.", com.alertetcl.shared.models.AlertDates.startLabel(now - 14 * 86_400, now))
        assertEquals("15 sept. 2025", com.alertetcl.shared.models.AlertDates.startLabel(now - 365 * 86_400, now))
    }

    @Test
    fun endLabelShowsDayAndTime() {
        assertEquals("Jusqu'au 16 sept. à 06:00", com.alertetcl.shared.models.AlertDates.endLabel(now + 15 * 3600 + 30 * 60, now))
    }
}

class TrafficBannerTest {
    private val now = 1_000_000L
    private fun alert(line: String, type: String, cli: String = line) = TCLAlert(
        id = "$line-$type", type = type, cause = "", debutEpoch = now - 60, finEpoch = now + 3600,
        mode = TransportMode.BUS, ligneCom = line, ligneCli = cli, titre = "t", message = "m"
    )
    private val c3 = TransportLine.create("C3", "C3", TransportMode.BUS_C)

    @Test
    fun withoutSubscriptionsTheBannerDescribesTheNetwork() {
        val normal = com.alertetcl.shared.models.TrafficBanner.compute(emptyMap(), listOf(alert("C5", "Information")), now)
        assertEquals("Réseau TCL normal", normal.title)
        val disrupted = com.alertetcl.shared.models.TrafficBanner.compute(
            emptyMap(), listOf(alert("C5", "Perturbation"), alert("T1", "Perturbation majeure")), now
        )
        assertEquals(com.alertetcl.shared.models.TrafficBanner.Tone.MAJOR, disrupted.tone)
        assertEquals("1 perturbation majeure sur le réseau", disrupted.title)
    }

    @Test
    fun withSubscriptionsTheBannerDescribesMyLinesFirst() {
        val subs = LineSubscriptions.subscribe(emptyMap(), c3)
        val others = com.alertetcl.shared.models.TrafficBanner.compute(subs, listOf(alert("C5", "Perturbation majeure")), now)
        assertEquals("Vos lignes sont normales", others.title)
        assertEquals("1 perturbation majeure sur le réseau", others.subtitle)
        assertEquals("Vos lignes circulent normalement",
            com.alertetcl.shared.models.TrafficBanner.compute(subs, listOf(alert("C5", "Perturbation")), now).title)
        val mine = com.alertetcl.shared.models.TrafficBanner.compute(subs, listOf(alert("C3", "Perturbation majeure")), now)
        assertEquals("1 ligne en alerte majeure", mine.title)
        assertEquals(null, mine.subtitle)
        assertTrue(mine.pulsing)
        val t1 = TransportLine.create("T1", "T1", TransportMode.TRAMWAY)
        val mixed = com.alertetcl.shared.models.TrafficBanner.compute(
            LineSubscriptions.subscribe(subs, t1), listOf(alert("C3", "Perturbation majeure"), alert("T1", "Perturbation")), now
        )
        assertEquals("1 ligne en alerte majeure", mixed.title)
        assertEquals("et 1 autre ligne perturbée", mixed.subtitle)
        val minor = com.alertetcl.shared.models.TrafficBanner.compute(subs, listOf(alert("C3", "Perturbation")), now)
        assertEquals("1 de vos ligne perturbée", minor.title)
        assertEquals(com.alertetcl.shared.models.TrafficBanner.Tone.WARNING, minor.tone)
    }

    @Test
    fun linesAreCountedOncePerLineUsingTheCustomerCode() {
        val lines = com.alertetcl.shared.models.TrafficBanner.linesInError(
            listOf(alert("302A", "Perturbation", cli = "C3"), alert("302A", "Perturbation majeure", cli = "C3"), alert("T1", "Information")), now
        )
        assertEquals(listOf("C3"), lines.map { it.lineId })
        assertEquals(AlertSeverity.MAJOR, lines.single().highestSeverity)
    }
}
