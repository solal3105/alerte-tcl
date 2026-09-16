package com.alertetcl.shared.util

import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.LineSubscription
import com.alertetcl.shared.models.LineSubscriptions
import com.alertetcl.shared.models.MergedStop
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransportLine
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.StopInfo
import com.alertetcl.shared.models.StopLineFocus
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import com.alertetcl.shared.models.VelovStation
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.minutes

/**
 * Mode démo : états simulés pour provoquer à la demande les cas particuliers de
 * l'interface (capture d'écran, revue visuelle) sans dépendre de l'état réel du
 * réseau TCL. Activé par l'app hôte (Android : extra d'intent "demo"), jamais en
 * production.
 *
 * Cas : ages, fiche, fiche-vieille, vide, erreur401, fige, arret, bus-arret,
 * horaires, horaires-ligne, horaires-arrets, horaires-arret, horaires-course,
 * alertes, alertes-ligne, alertes-options, velov, velov-station : mêmes scénarios que le DemoShowcase iOS.
 */
object DemoShowcase {
    var current: String? = null
    val isActive: Boolean get() = current != null

    /** Place Bellecour — centre de la scène démo. */
    const val CENTER_LAT = 45.7578
    const val CENTER_LON = 4.8320

    /** Compteur de fetchs pour le cas "fige" (1er OK, suivants en panne). */
    var vehicleFetchCount = 0

    /** Cas « alertes », « alertes-ligne », « alertes-options » : écran des alertes avec abonnements. */
    val isAlertsCase: Boolean get() = current?.startsWith("alertes") == true

    /** Alertes factices : une majeure en cours (C12), une perturbation (T1), une information à venir (C25), une majeure ailleurs (27). */
    fun alerts(): List<TCLAlert> {
        val now = Clock.System.now().epochSeconds
        fun make(id: String, type: String, cause: String, debut: Long, fin: Long, mode: TransportMode, line: String, titre: String, message: String) =
            TCLAlert(id = id, type = type, cause = cause, debutEpoch = debut, finEpoch = fin, mode = mode,
                ligneCom = line, ligneCli = line, titre = titre, message = message)
        return listOf(
            make("demo-1", "Perturbation majeure", "Incident technique", now - 25 * 60, now + 3 * 3600, TransportMode.BUS_C, "C12",
                "Circulation interrompue entre Bellecour et Hôpital Feyzin",
                "Un incident technique interrompt la circulation. Reprise estimée en fin d'après-midi. Pensez au métro B jusqu'à Gare d'Oullins."),
            make("demo-2", "Perturbation", "Travaux", now - 5 * 3600, now + 2 * 86_400, TransportMode.TRAMWAY, "T1",
                "Trafic ralenti entre Perrache et Debourg",
                "Des travaux sur la voie ralentissent les rames. Comptez dix minutes de plus sur votre trajet."),
            make("demo-3", "Information", "Travaux prévus", now + 2 * 86_400, now + 9 * 86_400, TransportMode.BUS_C, "C25",
                "Arrêt Saint-Genis Centre non desservi à partir de jeudi",
                "Pendant les travaux de voirie, reportez-vous à l'arrêt Saint-Genis 2."),
            make("demo-4", "Perturbation majeure", "Manifestation", now - 3600, now + 4 * 3600, TransportMode.BUS, "27",
                "Ligne déviée dans le centre",
                "La ligne ne dessert pas les arrêts entre Bellecour et Cordeliers pendant la manifestation."),
        )
    }

    /** Abonnements factices : C12 (tous les types) et T1 (sans les informations). */
    fun subscriptions(): Map<String, LineSubscription> {
        val c12 = TransportLine.create("C12", "C12", TransportMode.BUS_C)
        val t1 = TransportLine.create("T1", "T1", TransportMode.TRAMWAY)
        return LineSubscriptions.subscribe(
            LineSubscriptions.subscribe(emptyMap(), c12), t1, setOf(AlertSeverity.MAJOR, AlertSeverity.DISRUPTION)
        )
    }

    /**
     * Véhicules factices : frais (vert), vieillissant (orange), obsolète (parti de la carte, sa fiche le signale),
     * tram frais. Le C12 annonce Bellecour A. Poncet (11518) comme prochain arrêt : la fiche de cet arrêt le montre
     * « au prochain arrêt » (case « arret »).
     */
    fun vehicles(): List<Vehicle> {
        val nowSec = Clock.System.now().epochSeconds
        fun make(
            fleet: String, line: String, type: VehicleType,
            dLat: Double, dLon: Double, ageSeconds: Long, bearing: Double, destination: String
        ) = Vehicle(
            id = "ActIV:Vehicle:Bus:$fleet:LOC",
            latitude = CENTER_LAT + dLat,
            longitude = CENTER_LON + dLon,
            bearing = bearing,
            lineRef = "ActIV:Line::$line:SYTRAL",
            lineName = line,
            vehicleType = type,
            destination = destination,
            delay = 120,
            recordedAtEpoch = nowSec - ageSeconds,
            validUntilEpoch = nowSec + 60 - ageSeconds,
            nextStop = StopInfo(
                id = "ActIV:StopArea:SP:11518:SYTRAL",
                stopRef = "ActIV:StopArea:SP:11518:SYTRAL",
                stopName = "Bellecour A. Poncet",
                aimedArrivalTimeEpoch = nowSec + 180,
                aimedDepartureTimeEpoch = nowSec + 200,
                distanceFromStop = 350,
                order = 4
            )
        )
        return listOf(
            make("2101", "C12", VehicleType.BUS,   0.0006,  0.0008, 12,  45.0,  "Hôpital Feyzin Vénissieux"),
            make("2102", "C25", VehicleType.BUS,  -0.0007,  0.0010, 75,  190.0, "Saint-Genis 2"),
            make("2103", "27",  VehicleType.BUS,   0.0009, -0.0009, 200, 300.0, "Gare Saint-Paul"),
            make("881",  "T1",  VehicleType.TRAM, -0.0004, -0.0012, 20,  10.0,  "IUT Feyssine"),
        )
    }

    /** Le véhicule à ouvrir dans la fiche selon le cas ("fiche" ou "fiche-vieille"). */
    fun vehicleForSheet(): Vehicle? = when (current) {
        "fiche"         -> vehicles()[0]
        "fiche-vieille" -> vehicles()[2]
        else            -> null
    }

    /** Passages factices : deux estimés en temps réel (E) et deux théoriques (T). */
    fun passages(stopId: Int): List<Passage> {
        fun at(minutesFromNow: Int): String {
            val t = Clock.System.now().plus(minutesFromNow.minutes)
                .toLocalDateTime(TimeZone.of("Europe/Paris"))
            fun p(n: Int) = n.toString().padStart(2, '0')
            return "${t.year}-${p(t.monthNumber)}-${p(t.dayOfMonth)} ${p(t.hour)}:${p(t.minute)}:${p(t.second)}"
        }
        fun make(delai: String, minutes: Int, type: String) = Passage(
            stopId = stopId, ligne = "C12", direction = "Hôpital Feyzin Vénissieux",
            delaipassage = delai, heurepassage = at(minutes), type = type
        )
        return listOf(
            make("3 min", 3, "E"), make("12 min", 12, "E"),
            make("25 min", 25, "T"), make("40 min", 40, "T"),
        )
    }

    /** Filtre « bus de cet arrêt » pour la première ligne de l'arrêt de démo. */
    fun stopLineFocus(): StopLineFocus {
        val stop = mergedStop()
        val passage = passages(stop.stops[0].id)[0]
        return StopLineFocus(passage.ligne, "A", passage.direction, stop.nom, stop.latitude, stop.longitude)
    }

    /** Stations Vélo'v factices autour de la place Bellecour : bien fournie, presque vide, vide, fermée. */
    fun velovStations(): List<VelovStation> {
        val now = Clock.System.now().epochSeconds
        fun make(id: Int, name: String, address: String, dLat: Double, dLon: Double, bikes: Int, ebikes: Int, stands: Int, open: Boolean = true) =
            VelovStation(id = id, name = "$id - $name", address = address, lat = CENTER_LAT + dLat, lng = CENTER_LON + dLon,
                bikes = bikes, ebikes = ebikes, mbikes = bikes - ebikes, stands = stands, capacity = bikes + stands, open = open, updated = now - 120)
        return listOf(
            make(2001, "BELLECOUR / ANTONIN PONCET", "Place Antonin Poncet", 0.0004, 0.0011, 12, 7, 8),
            make(2002, "BELLECOUR / CHARITÉ", "Rue de la Charité", -0.0008, 0.0004, 2, 1, 21),
            make(2003, "BELLECOUR / VICTOR HUGO", "Rue Victor Hugo", 0.0002, -0.0012, 0, 0, 15),
            make(2004, "SALA / GASPARIN", "Rue Sala", -0.0011, -0.0007, 5, 2, 9, open = false),
        )
    }

    /** Arrêt fusionné factice pointant sur un vrai id d'arrêt (11518, Bellecour A. Poncet). */
    fun mergedStop(): MergedStop {
        val stop = TransitStop(
            id = 11518,
            nom = "Bellecour A. Poncet",
            commune = "Lyon 2ème",
            latitude = CENTER_LAT,
            longitude = CENTER_LON,
            desserte = "C12:A",
            pmr = true
        )
        return MergedStop(
            id = "demo-11518",
            nom = "Bellecour A. Poncet",
            latitude = CENTER_LAT,
            longitude = CENTER_LON,
            stops = listOf(stop),
            directions = listOf("Hôpital Feyzin Vénissieux")
        )
    }
}
