package com.alertetcl.shared

import com.alertetcl.shared.models.Intro
import com.alertetcl.shared.models.IntroIcon
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
        assertTrue(ios.any { it.icon == IntroIcon.WIDGETS })
        assertFalse(android.any { it.icon == IntroIcon.WIDGETS })
    }

    @Test
    fun everyPageHasItsOwnIconAndText() {
        val pages = Intro.pages(includeWidgets = true)
        assertEquals(pages.size, pages.map { it.icon }.toSet().size, "un pictogramme par page")
        assertTrue(pages.all { it.title.isNotBlank() && it.body.isNotBlank() })
    }

    @Test
    fun lastButtonOpensTheApp() {
        val count = Intro.pages(includeWidgets = false).size
        assertEquals("Suivant", Intro.buttonTitle(0, count))
        assertEquals("Commencer", Intro.buttonTitle(count - 1, count))
    }
}
