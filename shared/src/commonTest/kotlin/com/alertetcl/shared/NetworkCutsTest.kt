package com.alertetcl.shared

import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.models.AlertIdentity
import com.alertetcl.shared.models.CutWindow
import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.NetworkCuts
import com.alertetcl.shared.models.NetworkCutsFile
import com.alertetcl.shared.models.PassageGroup
import com.alertetcl.shared.models.StopBoard
import com.alertetcl.shared.models.TimetableStop
import com.alertetcl.shared.models.TimetableTrip
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.util.parsePassageEpoch
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Coupures du dimanche 22 novembre 2026 à 11 h 22 (métro B arrêté le matin, D et T3 coupés lundi
 * soir, La Soie fermée vers Meyzieu, 36 et 38 limités), telles que coupures/construire.mjs les publie.
 */
class NetworkCutsTest {
    private val file: NetworkCutsFile = HttpClientProvider.json.decodeFromString(FIXTURE)
    private fun at(paris: String): Long = parsePassageEpoch(paris)!!
    private val sunday = at("2026-11-22 11:22:09")
    private val mondayEvening = at("2026-11-23 21:00:00")
    /** Le même fichier, relu lundi soir : il n'est pas périmé. */
    private val mondayFile = file.copy(genere = "2026-11-23T19:58:00Z")

    @Test
    fun theMapShowsCutsInProgressAndThoseOfLaterToday() {
        val cuts = NetworkCuts.mapCuts(file, sunday).associateBy { it.line }
        assertEquals(setOf("B", "38"), cuts.keys)
        assertEquals(NetworkCuts.MapStyleKind.CUT, cuts.getValue("B").style)
        assertEquals("Jusqu'à 13 h", cuts.getValue("B").label)
        assertEquals("Jusqu'au 27 novembre inclus", cuts.getValue("38").label)
        assertTrue(cuts.getValue("B").isRail)

        val evening = NetworkCuts.mapCuts(mondayFile, mondayEvening).associateBy { it.line }
        assertEquals(NetworkCuts.MapStyleKind.SOON, evening.getValue("D").style)
        assertEquals("Dès 21 h 20", evening.getValue("D").label)
        assertEquals(NetworkCuts.MapStyleKind.CUT, evening.getValue("T3").style)
        assertEquals("Jusqu'à la fin du service", evening.getValue("T3").label)
    }

    @Test
    fun aStaleFileShowsNothing() {
        assertTrue(NetworkCuts.mapCuts(file, mondayEvening).isEmpty())
        assertTrue(NetworkCuts.upcoming(file, mondayEvening).isEmpty())
    }

    @Test
    fun busCutsAreShownFromFarOnlyWhenAsked() {
        val bus = NetworkCuts.mapCuts(file, sunday).first { it.line == "38" }
        assertTrue(!NetworkCuts.isShown(bus, zoom = 12.0, busTracesShown = false, filteredLines = emptySet()))
        assertTrue(NetworkCuts.isShown(bus, zoom = 12.0, busTracesShown = true, filteredLines = emptySet()))
        assertTrue(NetworkCuts.isShown(bus, zoom = 12.0, busTracesShown = false, filteredLines = setOf("38")))
        assertTrue(NetworkCuts.isShown(bus, zoom = 15.0, busTracesShown = false, filteredLines = emptySet()))
    }

    @Test
    fun theLineSheetSaysWhatDoesNotRunAndUntilWhen() {
        val b = NetworkCuts.lineBlocks(file, "B", sunday).single()
        assertEquals("Le métro B ne circule pas sur toute la ligne.", b.headline)
        assertEquals("Jusqu'à 13 h.", b.detail)
        assertEquals("Ne circule pas", b.status)

        val d = NetworkCuts.lineBlocks(file, "D", sunday).single()
        assertEquals("Lundi 23 et mardi 24 novembre, dès 21 h 20, le métro D ne circulera pas de Saxe - Gambetta à Gare de Vénissieux.", d.headline)
        assertEquals("Lundi 23 et mardi 24 novembre, dès 21 h 20", NetworkCuts.previewTitle(d.cut, sunday))
        assertEquals("En ce moment, il circule sur toute la ligne.", d.detail)
        assertNull(d.status)
        assertEquals(listOf("Gare de Vaise-GCollomb", "Saxe - Gambetta", "Garibaldi", "Gare de Vénissieux"), d.diagram.map { it.name })
        assertEquals(listOf(false, false, true, true), d.diagram.map { it.cut })

        val tonight = NetworkCuts.lineBlocks(mondayFile, "D", mondayEvening).single()
        assertTrue(tonight.headline.startsWith("Ce soir, dès 21 h 20, le métro D ne circulera pas"), tonight.headline)
    }

    @Test
    fun conflictingDatesAreFlaggedInTheSheet() {
        val evening = NetworkCuts.lineBlocks(mondayFile, "T3", mondayEvening).first { it.cut.wholeLine }
        assertEquals("Le tram T3 ne circule pas sur toute la ligne.", evening.headline)
        assertTrue(evening.note != null)
    }

    @Test
    fun theTrafficSheetListsAnnouncedCutsByDay() {
        val groups = NetworkCuts.upcoming(file, sunday)
        // Dans l'ordre où elles commencent : le 36 lundi matin, le T3 lundi soir, le D lundi et mardi soir.
        assertEquals(listOf("À partir de demain", "Demain", "Lundi 23 et mardi 24 novembre"), groups.map { it.title })
        assertEquals("Toute la journée, jusqu'au 13 décembre inclus", groups[0].rows.single().subtitle)
        assertEquals("Ne circule pas", groups[1].rows.single().title)
        assertEquals("Dès 20 h 30", groups[1].rows.single().subtitle)
        val d = groups[2].rows.single()
        assertEquals("Coupé de Saxe - Gambetta à Gare de Vénissieux", d.title)
        assertEquals("Dès 21 h 20", d.subtitle)
    }

    @Test
    fun aStopKnowsWhichOfItsLinesNoLongerStop() {
        val jeanMace = LatLng(45.74618, 4.84241)
        val cuts = NetworkCuts.stopCuts(file, "Jean Macé", jeanMace, listOf("B", "T2"), sunday)
        assertEquals(listOf("B"), cuts.map { it.line })
        assertEquals(NetworkCuts.StopMark.SOME_LINES, NetworkCuts.stopMark(cuts, listOf("B", "T2")))
        assertEquals(NetworkCuts.StopMark.ALL_LINES, NetworkCuts.stopMark(cuts, listOf("B")))
        assertEquals("Le métro B ne passe pas ici, jusqu'à 13 h.", NetworkCuts.stopNotice(cuts.single(), sunday))

        val soie = NetworkCuts.stopCuts(file, "Vaulx-en-Velin La Soie", LatLng(45.76125, 4.92278), listOf("T3"), sunday).single()
        assertEquals("A", soie.direction)
        assertTrue(soie.appliesTo("A") && !soie.appliesTo("R"))

        val garibaldi = NetworkCuts.stopCuts(mondayFile, "Garibaldi", LatLng(45.75143, 4.85421), listOf("D"), mondayEvening).single()
        assertEquals(NetworkCuts.Phase.LATER_TODAY, garibaldi.timing.phase)
        assertNull(garibaldi.direction)
        assertEquals(listOf(CutWindow(at("2026-11-23 21:20:00"), at("2026-11-24 01:30:00"))), NetworkCuts.windowsAt(listOf(garibaldi), "D", "R"))
    }

    @Test
    fun theStopKeepsTripsThatLeftBeforeTheCut() {
        // D sens A : départ de Gare de Vaise (0), passage à Garibaldi (1) 13 minutes plus tard.
        val timetable = LineTimetable(
            line = "D", key = "D", dir = "A", validFrom = "2026-11-01", validTo = "2026-12-31",
            stops = listOf(TimetableStop(1, "Gare de Vaise"), TimetableStop(2, "Garibaldi"), TimetableStop(3, "Gare de Vénissieux")),
            patterns = listOf(listOf(0, 1, 2)),
            services = listOf((0..60).toList()),
            trips = listOf(1270, 1278, 1286, 1294).map { TimetableTrip(p = 0, s = 0, t = listOf(it, it + 13, it + 25)) }
        )
        val window = listOf(CutWindow(at("2026-11-23 21:20:00"), at("2026-11-24 01:30:00")))
        val group = PassageGroup("D", "A", "Gare de Vénissieux", 2, emptyList())
        val board = StopBoard.board(group, emptyList(), timetable, listOf(1), at("2026-11-23 21:20:00") * 1000, window)
        // Courses parties à 21:10 et 21:18 : elles passent à 21:23 et 21:31 ; celles de 21:26 et 21:34 n'ont pas lieu.
        assertEquals(1283, board.first?.scheduledMinutes)
        assertEquals(1291, board.lastDeparture?.scheduledMinutes)
        assertTrue(board.following.isEmpty())
    }

    @Test
    fun cutsCarryTheIdentityOfTheirAlert() {
        // Même valeur dans coupures/test/coupures.test.mjs.
        assertEquals("D|D|Titre|2026-11-23 21:20:00|c4c01b3c", AlertIdentity.of("D", "D", "Titre", "2026-11-23 21:20:00", "Métro D ne circule pas."))
    }

    private companion object {
        const val FIXTURE = """{"format":1,"genere":"2026-11-22T10:22:09.000Z","coupures":[{"id":"T3|T3|Station Vaulx-en-Velin La Soie non desservie|2026-11-16 04:30:00|a0df526f","ligne":"T3","mode":"tram","couleur":"#00A3A6","titre":"Station Vaulx-en-Velin La Soie non desservie","message":"Du 16 au 25 novembre, La station Vaulx-en-Velin La Soie n'es","debut":"2026-11-16 04:30:00","fin":"2026-11-26 01:30:00","fenetres":[{"debut":"2026-11-16 04:30:00","fin":"2026-11-26 01:30:00"}],"horairesPartiels":true,"datesContradictoires":false,"gravite":"SIGNIFICANT_DELAYS","destinations":{"A":"Meyzieu les Panettes","R":"Gare Part-Dieu"},"effets":[{"effet":"arret-non-desservi","sens":"A","de":"Vaulx-en-Velin La Soie"}],"traits":[],"arrets":[{"nom":"Vaulx-en-Velin La Soie","sens":"A","lon":4.92278,"lat":45.76125,"dansTroncon":false}],"bornes":[]},{"id":"38|38|Terminus Cuire -  23/08 au 27/11|2026-08-24 04:30:00|df38f5f0","ligne":"38","mode":"bus","couleur":"#83C491","titre":"Terminus Cuire -  23/08 au 27/11","message":"Les arrêts de Dépôt de Cuire à Caluire - Pl. Bascule ne sont","debut":"2026-08-24 04:30:00","fin":"2026-11-28 02:30:00","fenetres":[{"debut":"2026-08-24 04:30:00","fin":"2026-11-28 02:30:00"}],"horairesPartiels":false,"datesContradictoires":false,"gravite":"SIGNIFICANT_DELAYS","destinations":{"R":"Gare Part-Dieu V.Merle","A":"Caluire - Pl. Bascule"},"effets":[{"effet":"limitation","sens":"R","depart":"Cuire","origine":"Caluire - Pl. Bascule"},{"effet":"limitation","sens":"A","terminus":"Cuire"}],"traits":[{"sens":"R","deuxSens":false,"points":[[4.8513,45.80196],[4.84995,45.7986],[4.84069,45.7949],[4.83366,45.78601]]},{"sens":"A","deuxSens":false,"points":[[4.83358,45.78588],[4.84069,45.7949],[4.84865,45.8006],[4.85129,45.80214]]}],"arrets":[{"nom":"Dépôt de Cuire","sens":"R","lon":4.83513,"lat":45.78899,"dansTroncon":true},{"nom":"Caluire - Pl. Bascule","sens":"R","lon":4.8513,"lat":45.80205,"dansTroncon":true},{"nom":"Caluire Centre","sens":"R","lon":4.84816,"lat":45.79904,"dansTroncon":true},{"nom":"Caluire H. de V. Radiant","sens":"R","lon":4.84342,"lat":45.79715,"dansTroncon":true},{"nom":"Jamen Grand","sens":"R","lon":4.8408,"lat":45.79504,"dansTroncon":true},{"nom":"Stade Henri Cochet","sens":"R","lon":4.83868,"lat":45.79279,"dansTroncon":true},{"nom":"Caluire Centre","sens":"A","lon":4.84762,"lat":45.7998,"dansTroncon":true}],"bornes":[{"nom":"Cuire","sens":"R","lon":4.83357,"lat":45.78595}]},{"id":"36|36|Déviée deux sens -|2026-11-23 04:30:00|e1308715","ligne":"36","mode":"bus","couleur":"#6E8997","titre":"Déviée deux sens -","message":"En direction de St-Genis-Laval Hôp. Sud, l'arrêt Jean Macé n","debut":"2026-11-23 04:30:00","fin":"2026-12-14 01:30:00","fenetres":[{"debut":"2026-11-23 04:30:00","fin":"2026-12-14 01:30:00"}],"horairesPartiels":false,"datesContradictoires":false,"gravite":"SIGNIFICANT_DELAYS","destinations":{"R":"Gare Part-Dieu V.Merle","A":"St-Genis-Laval Hôp. Sud"},"effets":[{"effet":"limitation","sens":"R","terminus":"Place Jean Jaurès","auLieuDe":"Jean Macé"},{"effet":"limitation","sens":"A","depart":"Lortet","origine":"Jean Macé"}],"traits":[{"sens":"R","deuxSens":false,"points":[[4.83786,45.73846],[4.83786,45.73846],[4.84216,45.74568],[4.84216,45.74568]]},{"sens":"A","deuxSens":false,"points":[[4.84204,45.74549],[4.84204,45.74549],[4.8401,45.74222],[4.8401,45.74222]]}],"arrets":[{"nom":"Lortet","sens":"R","lon":4.84025,"lat":45.74243,"dansTroncon":true},{"nom":"Jean Macé","sens":"R","lon":4.84205,"lat":45.74559,"dansTroncon":true}],"bornes":[{"nom":"Place Jean Jaurès","sens":"R","lon":4.83793,"lat":45.73853},{"nom":"Lortet","sens":"A","lon":4.84025,"lat":45.74243}]},{"id":"T3|T3|Le 9, 10, 25 et 27 novembre 2026|2026-11-23 20:30:00|379d5705","ligne":"T3","mode":"tram","couleur":"#00A3A6","titre":"Le 9, 10, 25 et 27 novembre 2026","message":"La ligne T3 ne circule pas, en soirée à partir de 20h30. Nou","debut":"2026-11-23 20:30:00","fin":"2026-11-24 01:30:00","fenetres":[{"debut":"2026-11-23 20:30:00","fin":"2026-11-24 01:30:00"}],"horairesPartiels":false,"datesContradictoires":true,"gravite":"SIGNIFICANT_DELAYS","destinations":{"A":"Meyzieu les Panettes","R":"Gare Part-Dieu"},"effets":[{"effet":"interruption","sens":"A","toute":true},{"effet":"interruption","sens":"R","toute":true}],"traits":[{"sens":"A","deuxSens":false,"points":[[4.86192,45.76049],[4.88719,45.75524],[4.97163,45.77704],[5.03526,45.76609]]},{"sens":"R","deuxSens":false,"points":[[5.03527,45.76615],[4.96913,45.77747],[4.8856,45.75482],[4.862,45.76127]]}],"arrets":[{"nom":"Gare Part-Dieu Villette","sens":"A","lon":4.86188,"lat":45.76022,"dansTroncon":true},{"nom":"Dauphiné -Lacassagne","sens":"A","lon":4.86883,"lat":45.75293,"dansTroncon":true},{"nom":"Reconnaissance - Balzac","sens":"A","lon":4.88511,"lat":45.75454,"dansTroncon":true},{"nom":"Gare de Villeurbanne","sens":"A","lon":4.89211,"lat":45.75591,"dansTroncon":true},{"nom":"Bel Air - Les Brosses","sens":"A","lon":4.91046,"lat":45.75843,"dansTroncon":true},{"nom":"Vaulx-en-Velin La Soie","sens":"A","lon":4.92278,"lat":45.76125,"dansTroncon":true},{"nom":"Décines Roosevelt","sens":"A","lon":4.93841,"lat":45.76519,"dansTroncon":true},{"nom":"Décines Centre","sens":"A","lon":4.9559,"lat":45.77184,"dansTroncon":true},{"nom":"Décines Grand Large","sens":"A","lon":4.97597,"lat":45.77473,"dansTroncon":true},{"nom":"Meyzieu Gare","sens":"A","lon":4.99892,"lat":45.77166,"dansTroncon":true},{"nom":"Meyzieu Lycée Beltrame","sens":"A","lon":5.01419,"lat":45.76981,"dansTroncon":true},{"nom":"Meyzieu Z.i.","sens":"A","lon":5.03158,"lat":45.76765,"dansTroncon":true},{"nom":"Meyzieu les Panettes","sens":"A","lon":5.03497,"lat":45.76614,"dansTroncon":true},{"nom":"Gare Part-Dieu Villette","sens":"R","lon":4.86197,"lat":45.76104,"dansTroncon":true}],"bornes":[]},{"id":"D|D|Travaux modernisation ligne D - Du 05/10 au 24/11|2026-10-05 21:20:00|ac8fcc8c","ligne":"D","mode":"metro","couleur":"#009E3D","titre":"Travaux modernisation ligne D - Du 05/10 au 24/11","message":"En raison de travaux de modernisation, du 5 octobre au 24 no","debut":"2026-10-05 21:20:00","fin":"2026-11-25 01:30:00","fenetres":[{"debut":"2026-11-23 21:20:00","fin":"2026-11-24 01:30:00"},{"debut":"2026-11-24 21:20:00","fin":"2026-11-25 01:30:00"}],"horairesPartiels":false,"datesContradictoires":false,"gravite":"SIGNIFICANT_DELAYS","destinations":{"A":"Gare de Vénissieux","R":"Gare de Vaise-GCollomb"},"effets":[{"effet":"partiel","sens":"A","de":"Gare de Vaise-G.Collomb","a":"Saxe - Gambetta"},{"effet":"partiel","sens":"R","de":"Saxe - Gambetta","a":"Gare de Vaise-G.Collomb"}],"traits":[{"sens":"A","deuxSens":true,"points":[[4.84719,45.75397],[4.88809,45.73698],[4.88683,45.72187],[4.888,45.70564]]}],"arrets":[{"nom":"Garibaldi","sens":"A","lon":4.85421,"lat":45.75143,"dansTroncon":true},{"nom":"Sans Souci","sens":"A","lon":4.86482,"lat":45.74777,"dansTroncon":true},{"nom":"Monplaisir Lumière","sens":"A","lon":4.87183,"lat":45.74536,"dansTroncon":true},{"nom":"Grange Blanche","sens":"A","lon":4.87895,"lat":45.74289,"dansTroncon":true},{"nom":"Laennec","sens":"A","lon":4.8863,"lat":45.73869,"dansTroncon":true},{"nom":"Mermoz - Pinel","sens":"A","lon":4.88725,"lat":45.73048,"dansTroncon":true},{"nom":"Parilly","sens":"A","lon":4.88745,"lat":45.71976,"dansTroncon":true},{"nom":"Gare de Vénissieux","sens":"A","lon":4.88802,"lat":45.70559,"dansTroncon":true}],"bornes":[{"nom":"Saxe - Gambetta","sens":"A","lon":4.84713,"lat":45.75385}]},{"id":"B|B|Ne circule pas - le 22/11 jusqu'à 12h environ|2026-11-22 04:30:00|28fc7aa7","ligne":"B","mode":"metro","couleur":"#0075BF","titre":"Ne circule pas - le 22/11 jusqu'à 12h environ","message":"Dans le cadre d'essais d'augmentation de la capacité et du c","debut":"2026-11-22 04:30:00","fin":"2026-11-22 13:00:00","fenetres":[{"debut":"2026-11-22 04:30:00","fin":"2026-11-22 13:00:00"}],"horairesPartiels":false,"datesContradictoires":false,"gravite":"NO_SERVICE","destinations":{"R":"Charpennes Charles Hernu .","A":"St-Genis-Laval Hôp. Sud"},"effets":[{"effet":"interruption","sens":"R","toute":true},{"effet":"interruption","sens":"A","toute":true}],"traits":[{"sens":"R","deuxSens":true,"points":[[4.80517,45.7004],[4.82008,45.71749],[4.84657,45.75863],[4.86318,45.77044]]}],"arrets":[{"nom":"St-Genis-Laval Hôp. Sud","sens":"R","lon":4.80467,"lat":45.70121,"dansTroncon":true},{"nom":"Oullins Centre","sens":"R","lon":4.80541,"lat":45.71436,"dansTroncon":true},{"nom":"Gare d'Oullins","sens":"R","lon":4.81451,"lat":45.71669,"dansTroncon":true},{"nom":"Stade de Gerland Le LOU","sens":"R","lon":4.83127,"lat":45.7274,"dansTroncon":true},{"nom":"Debourg","sens":"R","lon":4.83397,"lat":45.73195,"dansTroncon":true},{"nom":"Place Jean Jaurès","sens":"R","lon":4.83749,"lat":45.73785,"dansTroncon":true},{"nom":"Jean Macé","sens":"R","lon":4.84241,"lat":45.74618,"dansTroncon":true},{"nom":"Saxe - Gambetta","sens":"R","lon":4.84688,"lat":45.75369,"dansTroncon":true},{"nom":"Place Guichard","sens":"R","lon":4.84761,"lat":45.7594,"dansTroncon":true},{"nom":"Gare Part-Dieu V.Merle","sens":"R","lon":4.85725,"lat":45.76162,"dansTroncon":true},{"nom":"Brotteaux","sens":"R","lon":4.85943,"lat":45.76689,"dansTroncon":true},{"nom":"Charpennes Charles Hernu","sens":"R","lon":4.86283,"lat":45.77017,"dansTroncon":true}],"bornes":[]}],"nonPlacees":[]}"""
    }
}
