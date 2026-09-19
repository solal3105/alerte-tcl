package com.alertetcl.shared

import com.alertetcl.shared.models.CityOverview
import com.alertetcl.shared.models.CityTile
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class CityOverviewTest {
    @Test
    fun ligneEnDirectAccordeeEtFormatee() {
        val overview = CityOverview(carFreePlaces = 1, velovBikes = 1203, travauxInProgress = 87)
        assertEquals("1 place libre", overview.liveLine(CityTile.PARKING_CAR))
        assertEquals("1 203 vélos disponibles", overview.liveLine(CityTile.VELOV))
        assertEquals("87 chantiers en cours", overview.liveLine(CityTile.TRAVAUX))
    }

    @Test
    fun rienSansDonneeNiPourLesJeuxStatiques() {
        assertNull(CityOverview.EMPTY.liveLine(CityTile.PARKING_CAR))
        assertNull(CityOverview(carFreePlaces = 5).liveLine(CityTile.BIKE_RACKS))
        assertNull(CityOverview(carFreePlaces = 5).liveLine(CityTile.MOTO))
        assertEquals("0 place libre", CityOverview(carFreePlaces = 0).liveLine(CityTile.PARKING_CAR))
    }
}
