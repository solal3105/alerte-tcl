package com.alertetcl.shared.models

import kotlinx.serialization.Serializable

/**
 * Mode de transport. Les noms d'icônes sont des identifiants neutres (l'UI native
 * les mappe vers SF Symbols sur iOS ou des Material Icons sur Android).
 */
@Serializable
enum class TransportMode(val displayName: String, val iconKey: String, val sortOrder: Int) {
    METRO("Métro", "metro", 0),
    FUNICULAR("Funiculaire", "funicular", 1),
    TRAMWAY("Tramway", "tram", 2),
    BUS_C("Bus C", "bus_c", 3),
    BUS("Bus", "bus", 4),
    NAVIGONE("Navigone", "ferry", 5);

    companion object {
        /** Détection à partir du code ligne (M*, T*, F*, C*, JD*, etc.). */
        fun detectFromLine(line: String): TransportMode {
            val u = line.uppercase()
            return when {
                u.startsWith("M") && u.length <= 3 -> METRO
                u in setOf("A", "B", "C", "D") -> METRO
                u.startsWith("T") && u.length <= 3 -> TRAMWAY
                u.startsWith("F") && u.length <= 3 -> FUNICULAR
                u.startsWith("C") && u.length <= 3 -> BUS_C
                u == "RHONEXPRESS" -> TRAMWAY
                u.startsWith("NAVI") || u == "7601" -> NAVIGONE
                else -> BUS
            }
        }

        /** Classifie la hiérarchie d'affichage d'un arrêt selon les lignes qui le desservent. */
        fun classifyStopTier(lines: List<String>): TransportMode {
            val modes = lines.map { detectFromLine(it) }
            return when {
                METRO   in modes -> METRO
                TRAMWAY in modes -> TRAMWAY
                BUS_C   in modes -> BUS_C
                else             -> BUS
            }
        }

        /** Première ligne de la hiérarchie la plus haute parmi [lines]. */
        fun primaryStopLine(lines: List<String>): String? =
            lines.minByOrNull { detectFromLine(it).sortOrder }

        fun fromString(s: String?): TransportMode = when (s) {
            "Métro" -> METRO
            "Tramway", "Trambus" -> TRAMWAY
            "Bus C" -> BUS_C
            "Funiculaire" -> FUNICULAR
            "Navette maritime/fluviale", "Navette" -> NAVIGONE
            else -> BUS
        }
    }
}

@Serializable
data class TransportLine(
    val id: String,
    val ligneCom: String,
    val ligneCli: String,
    val mode: TransportMode
) {
    val displayName: String get() = if (ligneCli.isNotEmpty()) ligneCli else ligneCom

    companion object {
        fun create(ligneCom: String, ligneCli: String, mode: TransportMode): TransportLine =
            TransportLine(id = "${mode.displayName}-$ligneCom", ligneCom = ligneCom, ligneCli = ligneCli, mode = mode)

        val metroLines: List<TransportLine> = listOf(
            create("MA", "A", TransportMode.METRO),
            create("MB", "B", TransportMode.METRO),
            create("MC", "C", TransportMode.METRO),
            create("MD", "D", TransportMode.METRO),
        )

        val tramwayLines: List<TransportLine> = listOf(
            create("T1",   "T1",   TransportMode.TRAMWAY),
            create("T2",   "T2",   TransportMode.TRAMWAY),
            create("T3",   "T3",   TransportMode.TRAMWAY),
            create("T4",   "T4",   TransportMode.TRAMWAY),
            create("T5",   "T5",   TransportMode.TRAMWAY),
            create("T6",   "T6",   TransportMode.TRAMWAY),
            create("T7",   "T7",   TransportMode.TRAMWAY),
            create("RX",   "RX",   TransportMode.TRAMWAY),
            create("TS",   "TS",   TransportMode.TRAMWAY),
            create("TB11", "TB11", TransportMode.TRAMWAY),
            create("TB12", "TB12", TransportMode.TRAMWAY),
        )

        val funicularLines: List<TransportLine> = listOf(
            create("F1", "F1", TransportMode.FUNICULAR),
            create("F2", "F2", TransportMode.FUNICULAR),
        )

        val busCLines: List<TransportLine> = listOf(
            create("C1",  "C1",  TransportMode.BUS_C),
            create("C2",  "C2",  TransportMode.BUS_C),
            create("C3",  "C3",  TransportMode.BUS_C),
            create("C4",  "C4",  TransportMode.BUS_C),
            create("C5",  "C5",  TransportMode.BUS_C),
            create("C6",  "C6",  TransportMode.BUS_C),
            create("C7",  "C7",  TransportMode.BUS_C),
            create("C8",  "C8",  TransportMode.BUS_C),
            create("C9",  "C9",  TransportMode.BUS_C),
            create("C10", "C10", TransportMode.BUS_C),
            create("C11", "C11", TransportMode.BUS_C),
            create("C12", "C12", TransportMode.BUS_C),
            create("C13", "C13", TransportMode.BUS_C),
            create("C14", "C14", TransportMode.BUS_C),
            create("C15", "C15", TransportMode.BUS_C),
            create("C16", "C16", TransportMode.BUS_C),
            create("C17", "C17", TransportMode.BUS_C),
            create("C18", "C18", TransportMode.BUS_C),
            create("C19", "C19", TransportMode.BUS_C),
            create("C20", "C20", TransportMode.BUS_C),
            create("C21", "C21", TransportMode.BUS_C),
            create("C22", "C22", TransportMode.BUS_C),
            create("C23", "C23", TransportMode.BUS_C),
            create("C24", "C24", TransportMode.BUS_C),
            create("C25", "C25", TransportMode.BUS_C),
            create("C26", "C26", TransportMode.BUS_C),
            create("C200", "C200", TransportMode.BUS_C),
            create("C201", "C201", TransportMode.BUS_C),
            create("C202", "C202", TransportMode.BUS_C),
            create("C205", "C205", TransportMode.BUS_C),
            create("C15E", "C15E", TransportMode.BUS_C),
            create("C20E", "C20E", TransportMode.BUS_C),
            create("C22E", "C22E", TransportMode.BUS_C),
        )

        val regularBusLines: List<TransportLine> = listOf(
            create("S1",  "S1",  TransportMode.BUS),
            create("S2",  "S2",  TransportMode.BUS),
            create("S3",  "S3",  TransportMode.BUS),
            create("S4",  "S4",  TransportMode.BUS),
            create("S5",  "S5",  TransportMode.BUS),
            create("S6",  "S6",  TransportMode.BUS),
            create("S7",  "S7",  TransportMode.BUS),
            create("S8",  "S8",  TransportMode.BUS),
            create("S9",  "S9",  TransportMode.BUS),
            create("S10", "S10", TransportMode.BUS),
            create("S11", "S11", TransportMode.BUS),
            create("S12", "S12", TransportMode.BUS),
            create("2",   "2",   TransportMode.BUS),
            create("3",   "3",   TransportMode.BUS),
            create("8",   "8",   TransportMode.BUS),
            create("9",   "9",   TransportMode.BUS),
            create("17",  "17",  TransportMode.BUS),
            create("19",  "19",  TransportMode.BUS),
            create("20",  "20",  TransportMode.BUS),
            create("21",  "21",  TransportMode.BUS),
            create("22",  "22",  TransportMode.BUS),
            create("23",  "23",  TransportMode.BUS),
            create("24",  "24",  TransportMode.BUS),
            create("25",  "25",  TransportMode.BUS),
            create("26",  "26",  TransportMode.BUS),
            create("27",  "27",  TransportMode.BUS),
            create("28",  "28",  TransportMode.BUS),
            create("29",  "29",  TransportMode.BUS),
            create("31",  "31",  TransportMode.BUS),
            create("33",  "33",  TransportMode.BUS),
            create("34",  "34",  TransportMode.BUS),
            create("35",  "35",  TransportMode.BUS),
            create("36",  "36",  TransportMode.BUS),
            create("37",  "37",  TransportMode.BUS),
            create("38",  "38",  TransportMode.BUS),
            create("39",  "39",  TransportMode.BUS),
            create("40",  "40",  TransportMode.BUS),
            create("41",  "41",  TransportMode.BUS),
            create("43",  "43",  TransportMode.BUS),
            create("44",  "44",  TransportMode.BUS),
            create("45",  "45",  TransportMode.BUS),
            create("46",  "46",  TransportMode.BUS),
            create("47",  "47",  TransportMode.BUS),
            create("48",  "48",  TransportMode.BUS),
            create("49",  "49",  TransportMode.BUS),
            create("52",  "52",  TransportMode.BUS),
            create("53",  "53",  TransportMode.BUS),
            create("54",  "54",  TransportMode.BUS),
            create("55",  "55",  TransportMode.BUS),
            create("57",  "57",  TransportMode.BUS),
            create("58",  "58",  TransportMode.BUS),
            create("59",  "59",  TransportMode.BUS),
            create("60",  "60",  TransportMode.BUS),
            create("61",  "61",  TransportMode.BUS),
            create("62",  "62",  TransportMode.BUS),
            create("63",  "63",  TransportMode.BUS),
            create("64",  "64",  TransportMode.BUS),
            create("65",  "65",  TransportMode.BUS),
            create("66",  "66",  TransportMode.BUS),
            create("67",  "67",  TransportMode.BUS),
            create("68",  "68",  TransportMode.BUS),
            create("69",  "69",  TransportMode.BUS),
            create("70",  "70",  TransportMode.BUS),
            create("71",  "71",  TransportMode.BUS),
            create("72",  "72",  TransportMode.BUS),
            create("73",  "73",  TransportMode.BUS),
            create("76",  "76",  TransportMode.BUS),
            create("77",  "77",  TransportMode.BUS),
            create("78",  "78",  TransportMode.BUS),
            create("79",  "79",  TransportMode.BUS),
            create("80",  "80",  TransportMode.BUS),
            create("81",  "81",  TransportMode.BUS),
            create("83",  "83",  TransportMode.BUS),
            create("84",  "84",  TransportMode.BUS),
            create("85",  "85",  TransportMode.BUS),
            create("89",  "89",  TransportMode.BUS),
            create("90",  "90",  TransportMode.BUS),
            create("93",  "93",  TransportMode.BUS),
            create("96",  "96",  TransportMode.BUS),
            create("98",  "98",  TransportMode.BUS),
            create("99",  "99",  TransportMode.BUS),
            // Lignes manquantes — ajout complet depuis le jeu de données Grand Lyon
            // Bus numérotés absents
            create("5",   "5",   TransportMode.BUS),
            create("6",   "6",   TransportMode.BUS),
            create("6E",  "6E",  TransportMode.BUS),
            create("7",   "7",   TransportMode.BUS),
            create("10",  "10",  TransportMode.BUS),
            create("10E", "10E", TransportMode.BUS),
            create("11",  "11",  TransportMode.BUS),
            create("12",  "12",  TransportMode.BUS),
            create("14",  "14",  TransportMode.BUS),
            create("15",  "15",  TransportMode.BUS),
            create("15E", "15E", TransportMode.BUS),
            create("16",  "16",  TransportMode.BUS),
            create("18",  "18",  TransportMode.BUS),
            create("30",  "30",  TransportMode.BUS),
            create("32",  "32",  TransportMode.BUS),
            create("50",  "50",  TransportMode.BUS),
            create("52E", "52E", TransportMode.BUS),
            create("82",  "82",  TransportMode.BUS),
            create("86",  "86",  TransportMode.BUS),
            create("87",  "87",  TransportMode.BUS),
            create("88",  "88",  TransportMode.BUS),
            create("89D", "89D", TransportMode.BUS),
            create("95",  "95",  TransportMode.BUS),
            create("97",  "97",  TransportMode.BUS),
            create("98E", "98E", TransportMode.BUS),
            create("128", "128", TransportMode.BUS),
            // S-bus — variantes et nouvelles lignes
            create("S4A", "S4A", TransportMode.BUS),
            create("S4B", "S4B", TransportMode.BUS),
            create("S14", "S14", TransportMode.BUS),
            create("S15", "S15", TransportMode.BUS),
            // Lignes spéciales urbaines
            create("A32",  "A32",  TransportMode.BUS),
            create("A71",  "A71",  TransportMode.BUS),
            create("BR60", "BR60", TransportMode.BUS),
            create("BRT6", "BRT6", TransportMode.BUS),
            create("GE2",  "GE2",  TransportMode.BUS),
            create("GE4",  "GE4",  TransportMode.BUS),
            create("GE6",  "GE6",  TransportMode.BUS),
            create("PL1",  "PL1",  TransportMode.BUS),
            create("PL2",  "PL2",  TransportMode.BUS),
            create("PL3",  "PL3",  TransportMode.BUS),
            create("PL4",  "PL4",  TransportMode.BUS),
            create("T36",  "T36",  TransportMode.BUS),
            create("ZI1",  "ZI1",  TransportMode.BUS),
            create("ZI2",  "ZI2",  TransportMode.BUS),
            create("ZI3",  "ZI3",  TransportMode.BUS),
            create("ZI4",  "ZI4",  TransportMode.BUS),
            create("ZI5",  "ZI5",  TransportMode.BUS),
            create("ZI8",  "ZI8",  TransportMode.BUS),
            // Noctambus (service de nuit)
            create("N20",  "N20",  TransportMode.BUS),
            create("N80",  "N80",  TransportMode.BUS),
            create("N81",  "N81",  TransportMode.BUS),
            create("N82",  "N82",  TransportMode.BUS),
            create("N83",  "N83",  TransportMode.BUS),
            create("N84",  "N84",  TransportMode.BUS),
            create("N100", "N100", TransportMode.BUS),
            create("N189", "N189", TransportMode.BUS),
        )

        val navigoneLines: List<TransportLine> = listOf(
            create("7601", "NAVI1", TransportMode.NAVIGONE),
        )

        val allPredefinedLines: List<TransportLine> =
            metroLines + funicularLines + tramwayLines + busCLines + regularBusLines + navigoneLines
    }
}
