package com.alertetcl.shared.models

/**
 * Les tuiles de l'accueil de l'onglet Ville, dans l'ordre d'affichage : quatre types de stationnement
 * et les chantiers. Les textes sont ceux des deux applications.
 */
enum class CityTile(val title: String, val subtitle: String, val parkingType: ParkingType?) {
    PARKING_CAR("Parkings voiture", "Places libres en direct et parcs relais TCL", ParkingType.CAR),
    VELOV("Stations Vélo'v", "Vélos et places disponibles en direct", ParkingType.VELOV),
    BIKE_RACKS("Arceaux vélos", "Où attacher votre vélo dans la rue", ParkingType.BIKE),
    MOTO("Places deux-roues motorisés", "Emplacements réservés aux motos et scooters", ParkingType.MOTORIZED_2W),
    TRAVAUX("Travaux", "Chantiers en cours sur la voirie et le réseau", null);

    companion object {
        /** Liste ordonnée, exposée telle quelle à Swift. */
        val all: List<CityTile> = entries
    }
}

/**
 * Chiffres en direct affichés sur les tuiles de l'accueil ; `null` quand la donnée n'a pas pu être
 * chargée (la tuile garde alors sa ligne descriptive).
 */
data class CityOverview(
    val carFreePlaces: Int? = null,
    val velovBikes: Int? = null,
    val travauxInProgress: Int? = null
) {
    /** « 412 places libres », « 1 203 vélos disponibles », « 87 chantiers en cours », ou rien. */
    fun liveLine(tile: CityTile): String? = when (tile) {
        CityTile.PARKING_CAR -> carFreePlaces?.let { "${formatCount(it)} ${plural(it, "place libre", "places libres")}" }
        CityTile.VELOV -> velovBikes?.let { "${formatCount(it)} ${plural(it, "vélo disponible", "vélos disponibles")}" }
        CityTile.TRAVAUX -> travauxInProgress?.let { "${formatCount(it)} ${plural(it, "chantier en cours", "chantiers en cours")}" }
        CityTile.BIKE_RACKS, CityTile.MOTO -> null
    }

    companion object {
        val EMPTY = CityOverview()

        /** Milliers séparés par une espace fine insécable, à la française : « 1 203 ». */
        fun formatCount(value: Int): String {
            val digits = value.toString()
            if (digits.length <= 3) return digits
            return digits.reversed().chunked(3).joinToString(" ").reversed()
        }

        private fun plural(count: Int, one: String, many: String) = if (count > 1) many else one
    }
}
