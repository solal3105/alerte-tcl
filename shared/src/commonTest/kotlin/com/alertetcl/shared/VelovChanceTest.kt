package com.alertetcl.shared

import com.alertetcl.shared.design.AppColors
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.VelovChance
import com.alertetcl.shared.models.VelovChanceLevel
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovTexts
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class VelovChanceTest {
    @Test
    fun theFourLevelsStartAt90And70And40PerCent() {
        assertEquals(VelovChance(90, VelovChanceLevel.NEAR_CERTAIN), VelovChance.of(0.90))
        assertEquals(VelovChance(89, VelovChanceLevel.LIKELY), VelovChance.of(0.89))
        assertEquals(VelovChance(70, VelovChanceLevel.LIKELY), VelovChance.of(0.70))
        assertEquals(VelovChance(69, VelovChanceLevel.UNCERTAIN), VelovChance.of(0.69))
        assertEquals(VelovChance(40, VelovChanceLevel.UNCERTAIN), VelovChance.of(0.40))
        assertEquals(VelovChance(39, VelovChanceLevel.UNLIKELY), VelovChance.of(0.39))
    }

    @Test
    fun theLevelIsReadOnThePercentageShown() {
        // 89,6 % s'affiche « 90 % » : il prend le palier de 90, pour que le chiffre et le mot ne se contredisent pas.
        assertEquals(VelovChance(90, VelovChanceLevel.NEAR_CERTAIN), VelovChance.of(0.896))
        assertEquals(VelovChance(89, VelovChanceLevel.LIKELY), VelovChance.of(0.894))
        assertEquals(VelovChance(70, VelovChanceLevel.LIKELY), VelovChance.of(0.696))
        assertEquals(VelovChance(40, VelovChanceLevel.UNCERTAIN), VelovChance.of(0.396))
    }

    @Test
    fun aForecastNeverClaimsCertainty() {
        assertEquals(99, VelovChance.of(1.0).percent)
        assertEquals(99, VelovChance.of(0.9991).percent)
        assertEquals(1, VelovChance.of(0.0).percent)
        assertEquals(1, VelovChance.of(0.004).percent)
        assertEquals("99 %", VelovChance.of(0.997).text)
        assertEquals("29 %", VelovChance.of(0.29).text)
    }

    @Test
    fun theWordsAreTheSameForABikeAndForADock() {
        assertEquals(listOf("quasi sûr", "probable", "incertain", "peu probable"), VelovChanceLevel.entries.map { it.label })
    }

    @Test
    fun aNeighbourIsWorthSuggestingFromLikely() {
        assertTrue(VelovChanceLevel.NEAR_CERTAIN.isSafe)
        assertTrue(VelovChanceLevel.LIKELY.isSafe)
        assertFalse(VelovChanceLevel.UNCERTAIN.isSafe)
        assertFalse(VelovChanceLevel.UNLIKELY.isSafe)
    }

    @Test
    fun theMapHasThreeColoursAndTheSliderTrackFour() {
        assertEquals(
            listOf(AvailabilityColor.GREEN, AvailabilityColor.GREEN, AvailabilityColor.ORANGE, AvailabilityColor.RED),
            VelovChanceLevel.entries.map { it.availability }
        )
        assertEquals(listOf(AppColors.success, AppColors.success, AppColors.warning, AppColors.error), VelovChanceLevel.entries.map(AppColors::velovChance))
        assertEquals(
            listOf(AppColors.success, AppColors.successSoft, AppColors.warning, AppColors.error),
            VelovChanceLevel.entries.map(AppColors::velovChanceTrack)
        )
        assertEquals("#9CC79F", AppColors.successSoft.hex(darkTheme = false))
        assertEquals("#3E6B41", AppColors.successSoft.hex(darkTheme = true))
    }

    // --- Les mots des comptes ([VelovTexts]).

    @Test
    fun whatIsCountedTakesTheNameOfTheFilter() {
        assertEquals(listOf("14 vélos", "5 classiques", "9 électriques", "4 places"), listOf(14, 5, 9, 4).zip(VelovFilter.ordered, VelovTexts::count))
        assertEquals(listOf("1 vélo", "1 classique", "1 électrique", "1 place"), VelovFilter.ordered.map { VelovTexts.count(1, it) })
        assertEquals("0 vélo", VelovTexts.count(0, VelovFilter.ALL))
        assertEquals("2 places", VelovTexts.count(2, VelovFilter.STANDS))
        assertEquals("places", VelovTexts.unit(VelovFilter.STANDS, 4))
        assertEquals("classique", VelovTexts.unit(VelovFilter.MECHANICAL, 1))
    }

    @Test
    fun aRangeIsWrittenWithItsRoundedBounds() {
        assertEquals("7 à 17 vélos", VelovTexts.range(6.6, 17.4, VelovFilter.ALL))
        assertEquals("0 à 2 classiques", VelovTexts.range(0.0, 2.3, VelovFilter.MECHANICAL))
        assertEquals("0 à 2 électriques", VelovTexts.range(0.4, 1.6, VelovFilter.ELECTRIC))
        assertEquals("0 à 9 places", VelovTexts.range(0.0, 9.0, VelovFilter.STANDS))
        assertEquals("0 à 1 vélo", VelovTexts.range(0.2, 1.4, VelovFilter.ALL), "le nom s'accorde avec la borne haute")
    }

    @Test
    fun boundsThatRoundToTheSameNumberAreWrittenOnce() {
        assertEquals("12 vélos", VelovTexts.range(11.6, 12.4, VelovFilter.ALL))
        assertEquals("1 place", VelovTexts.range(0.6, 1.2, VelovFilter.STANDS))
        assertEquals("0 électrique", VelovTexts.range(0.0, 0.3, VelovFilter.ELECTRIC))
    }

    @Test
    fun theReliabilityOfTheRangeIsTheOneTheRobotMeasured() {
        assertEquals("8 fois sur 10", VelovTexts.reliability(0.8276))
        assertEquals("7 fois sur 10", VelovTexts.reliability(0.7461))
        assertEquals("9 fois sur 10", VelovTexts.reliability(0.9049))
        assertEquals("8 fois sur 10", VelovTexts.reliability(0.75), "arrondi au dixième")
        assertEquals("9 fois sur 10", VelovTexts.reliability(0.97), "jamais 10 fois sur 10")
        assertNull(VelovTexts.reliability(null), "pas de chiffre que le robot n'a pas mesuré")
    }

    @Test
    fun aShortageIsNamedAfterWhatIsMissing() {
        assertEquals(
            listOf("Souvent vide", "Souvent sans classique", "Souvent sans électrique", "Souvent pleine"),
            VelovFilter.ordered.map(VelovTexts::shortage)
        )
    }
}
