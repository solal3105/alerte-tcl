package com.alertetcl.shared

import com.alertetcl.shared.models.AlertIdentity
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class AlertIdentityTest {
    private fun id(titre: String = "Ne circule plus - 21/09", debut: String? = "2026-09-21 12:10:00", message: String = "Trafic interrompu") =
        AlertIdentity.of(ligneCom = "A", ligneCli = "A", titre = titre, debut = debut, message = message)

    @Test
    fun theSameAlertKeepsItsIdentityWhateverItsRankInTheFeed() {
        assertEquals(id(), id())
    }

    @Test
    fun twoAlertsOfTheSameLineAreToldApart() {
        assertNotEquals(id(), id(titre = "Terminus provisoire - 21/09"))
        assertNotEquals(id(), id(debut = "2026-09-22 12:10:00"))
        assertNotEquals(id(), id(message = "Trafic perturbé"))
    }

    @Test
    fun spacesAroundTheFieldsChangeNothing() {
        assertEquals(id(), AlertIdentity.of(ligneCom = " A ", ligneCli = "A ", titre = " Ne circule plus - 21/09", debut = "2026-09-21 12:10:00 ", message = " Trafic interrompu "))
    }

    @Test
    fun anAlertWithoutAStartDateStillHasAnIdentity() {
        assertEquals(id(debut = null), id(debut = null))
        assertNotEquals(id(debut = null), id())
    }
}
