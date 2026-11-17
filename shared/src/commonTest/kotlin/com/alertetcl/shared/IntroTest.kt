package com.alertetcl.shared

import com.alertetcl.shared.models.Intro
import com.alertetcl.shared.models.IntroVisual
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class IntroTest {
    private fun visuals(includeWidgets: Boolean, seenRevision: Int) = Intro.pages(includeWidgets, seenRevision).map { it.visual }

    @Test
    fun introOpensOncePerRevision() {
        assertTrue(Intro.shouldShow(Intro.NEVER_SEEN), "première utilisation")
        assertFalse(Intro.shouldShow(Intro.REVISION), "déjà vue pour cette version")
        assertTrue(Intro.shouldShow(Intro.REVISION - 1), "vue avant la mise à jour")
    }

    @Test
    fun widgetsPageOnlyOnIos() {
        val ios = Intro.pages(includeWidgets = true, seenRevision = Intro.NEVER_SEEN)
        val android = Intro.pages(includeWidgets = false, seenRevision = Intro.NEVER_SEEN)
        assertEquals(android.size + 1, ios.size)
        assertTrue(ios.any { it.visual == IntroVisual.WIDGETS })
        assertFalse(android.any { it.visual == IntroVisual.WIDGETS })
    }

    @Test
    fun theAppOpensAndTheFixesClose() {
        val pages = Intro.pages(includeWidgets = true, seenRevision = Intro.NEVER_SEEN)
        assertEquals(IntroVisual.APP, pages.first().visual)
        assertEquals("Lyon Pocket, version 2", pages.first().title, "la page d'ouverture ne change pas")
        assertEquals(IntroVisual.FIXES, pages.last().visual)
        assertTrue(pages.last().points.isNotEmpty(), "la page des corrections donne des exemples")
    }

    @Test
    fun aNewUserSeesTheForecastRightAfterTheVelovStations() {
        val all = visuals(includeWidgets = false, seenRevision = Intro.NEVER_SEEN)
        val velov = all.indexOf(IntroVisual.VELOV)
        assertEquals(FORECAST_PAGES, all.subList(velov + 1, velov + 1 + FORECAST_PAGES.size))
        assertEquals(IntroVisual.entries.size - 2, all.size, "toutes les pages sauf les widgets et la page d'annonce")
    }

    @Test
    fun aUserOfTheFirstRevisionSeesOnlyWhatIsNew() {
        for (includeWidgets in listOf(true, false)) {
            assertEquals(
                listOf(IntroVisual.VELOV_FORECAST_HERO) + FORECAST_PAGES,
                visuals(includeWidgets, seenRevision = 1)
            )
        }
        val update = Intro.pages(includeWidgets = true, seenRevision = 1).first()
        val opening = Intro.pages(includeWidgets = true, seenRevision = Intro.NEVER_SEEN).first()
        assertNotEquals(opening.title, update.title, "la première page annonce la mise à jour")
    }

    @Test
    fun theIntroReopenedFromInfoShowsEverything() {
        assertEquals(visuals(includeWidgets = true, seenRevision = Intro.NEVER_SEEN), visuals(includeWidgets = true, seenRevision = Intro.REVISION))
    }

    @Test
    fun everyPageHasItsOwnVisualAndText() {
        for (seen in listOf(Intro.NEVER_SEEN, 1)) {
            val pages = Intro.pages(includeWidgets = true, seenRevision = seen)
            assertEquals(pages.size, pages.map { it.visual }.toSet().size, "une illustration par page")
            assertTrue(pages.all { it.title.isNotBlank() && it.body.isNotBlank() })
        }
    }

    @Test
    fun theTextsStayShort() {
        val pages = Intro.pages(includeWidgets = true, seenRevision = Intro.NEVER_SEEN) + Intro.pages(includeWidgets = true, seenRevision = 1).first()
        assertTrue(pages.all { it.body.length <= 220 }, pages.filter { it.body.length > 220 }.joinToString { it.title })
    }

    @Test
    fun lastButtonSaysWhereItLeads() {
        for (seen in listOf(Intro.NEVER_SEEN, 1)) {
            val count = Intro.pages(includeWidgets = false, seenRevision = seen).size
            assertEquals("Suivant", Intro.buttonTitle(0, count, atLaunch = true))
            assertEquals("Voir la carte", Intro.buttonTitle(count - 1, count, atLaunch = true))
            assertEquals("Fermer", Intro.buttonTitle(count - 1, count, atLaunch = false), "rouverte depuis l'onglet Info")
        }
    }

    private companion object {
        /** Les pages de la prévision Vélo'v, dans l'ordre où elles la racontent. */
        val FORECAST_PAGES = listOf(
            IntroVisual.VELOV_FORECAST_MAP, IntroVisual.VELOV_FORECAST_RANGE, IntroVisual.VELOV_FORECAST_CHANCE,
            IntroVisual.VELOV_FORECAST_KINDS, IntroVisual.VELOV_FORECAST_NEARBY, IntroVisual.VELOV_FORECAST_FRESH
        )
    }
}
