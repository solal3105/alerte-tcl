package com.alertetcl.shared

import com.alertetcl.shared.models.Intro
import com.alertetcl.shared.models.IntroVisual
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class IntroTest {

    @Test
    fun introOpensOncePerRevision() {
        assertTrue(Intro.shouldShow(Intro.NEVER_SEEN), "première utilisation")
        assertFalse(Intro.shouldShow(Intro.REVISION), "déjà vue pour cette version")
        assertTrue(Intro.shouldShow(Intro.REVISION - 1), "vue avant la mise à jour")
    }

    @Test
    fun widgetsPageOnlyOnIos() {
        val ios = Intro.pages(includeWidgets = true)
        val android = Intro.pages(includeWidgets = false)
        assertEquals(android.size + 1, ios.size)
        assertTrue(ios.any { it.visual == IntroVisual.WIDGETS })
        assertFalse(android.any { it.visual == IntroVisual.WIDGETS })
    }

    @Test
    fun theAppOpensAndTheFixesClose() {
        val pages = Intro.pages(includeWidgets = true)
        assertEquals(IntroVisual.APP, pages.first().visual)
        assertEquals(IntroVisual.FIXES, pages.last().visual)
        assertTrue(pages.last().points.isNotEmpty(), "la page des corrections donne des exemples")
    }

    @Test
    fun everyPageHasItsOwnVisualAndText() {
        val pages = Intro.pages(includeWidgets = true)
        assertEquals(pages.size, pages.map { it.visual }.toSet().size, "une illustration par page")
        assertTrue(pages.all { it.title.isNotBlank() && it.body.isNotBlank() })
    }

    @Test
    fun lastButtonOpensTheApp() {
        val count = Intro.pages(includeWidgets = false).size
        assertEquals("Suivant", Intro.buttonTitle(0, count))
        assertEquals("Commencer", Intro.buttonTitle(count - 1, count))
    }
}
