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
