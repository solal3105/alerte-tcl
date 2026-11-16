package com.alertetcl.shared

import com.alertetcl.shared.models.NewBadges
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class NewBadgesTest {
    /** 28 février 2027, 23 h 59 59 à Lyon (heure d'hiver, UTC+1), puis minuit pile le 1er mars. */
    private val lastMoment = 1_803_855_599_000L
    private val end = 1_803_855_600_000L

    @Test
    fun theForecastBadgeShowsUntilTheFirstOfMarch() {
        assertEquals("Nouveau", NewBadges.LABEL)
        assertTrue(NewBadges.showsVelovForecast(opened = false, forecastAvailable = true, nowEpochMs = 1_794_851_100_000L), "16 novembre 2026")
        assertTrue(NewBadges.showsVelovForecast(opened = false, forecastAvailable = true, nowEpochMs = lastMoment))
        assertFalse(NewBadges.showsVelovForecast(opened = false, forecastAvailable = true, nowEpochMs = end), "1er mars 2027 à minuit, heure de Lyon")
    }

    @Test
    fun theBadgeGoesOnceTheMapIsOpened() {
        assertFalse(NewBadges.showsVelovForecast(opened = true, forecastAvailable = true, nowEpochMs = 1_794_851_100_000L))
    }

    @Test
    fun noBadgeForAFeatureThatWouldShowNothing() {
        assertFalse(NewBadges.showsVelovForecast(opened = false, forecastAvailable = false, nowEpochMs = 1_794_851_100_000L))
    }
}
