package com.alertetcl.shared.models

/** Pictogramme d'une page d'intro ; chaque plateforme le traduit dans sa bibliothèque d'icônes. */
enum class IntroIcon {
    APP,
    BUS_ARRIVAL,
    TIMETABLE,
    MAP,
    CITY,
    ALERTS,
    WIDGETS
}

/** Une page de l'écran d'intro : un pictogramme, un titre et le texte qui l'explique. */
data class IntroPage(
    val icon: IntroIcon,
    val title: String,
    val body: String
)

/**
 * L'écran d'intro des deux applications : la même suite de pages, les mêmes textes.
 *
 * Il s'ouvre à la première utilisation et après chaque mise à jour qui change [REVISION] ; chaque
 * plateforme retient la révision déjà vue (iOS `UserDefaults`, Android `FavoritesStore`) et la
 * compare par [shouldShow]. Il reste consultable depuis l'onglet Info.
 */
object Intro {
    /** Révision du contenu : l'augmenter fait reparaître l'intro une fois après la mise à jour. */
    const val REVISION = 1

    /** Révision enregistrée tant que l'intro n'a jamais été vue. */
    const val NEVER_SEEN = 0

    /** True si l'intro doit s'ouvrir au lancement, d'après la révision déjà vue. */
    fun shouldShow(seenRevision: Int): Boolean = seenRevision < REVISION

    /**
     * Les pages dans l'ordre d'affichage. [includeWidgets] n'est vrai que sur iOS : Android n'a pas
     * de widgets.
     */
    fun pages(includeWidgets: Boolean): List<IntroPage> = buildList {
        add(
            IntroPage(
                icon = IntroIcon.APP,
                title = "Lyon Pocket",
                body = "Les transports lyonnais en direct, les horaires de toute la journée et ce qui vous " +
                    "attend dans la rue. Voici l'essentiel avant de commencer."
            )
        )
        add(
            IntroPage(
                icon = IntroIcon.BUS_ARRIVAL,
                title = "Où en est votre bus",
                body = "Ouvrez un arrêt et vous voyez l'heure à laquelle le prochain bus y arrive, le nombre " +
                    "d'arrêts qu'il lui reste à parcourir et depuis combien de temps sa position a été " +
                    "transmise. L'heure annoncée tient compte du retard en cours."
            )
        )
        add(
            IntroPage(
                icon = IntroIcon.TIMETABLE,
                title = "Les horaires de toute la journée",
                body = "Chaque ligne a sa fiche horaire complète, sens par sens et arrêt par arrêt, pour " +
                    "aujourd'hui, demain ou une date plus lointaine. Les horaires viennent du SYTRAL et sont " +
                    "republiés chaque nuit."
            )
        )
        add(
            IntroPage(
                icon = IntroIcon.MAP,
                title = "Une carte qui se lit d'un coup d'œil",
                body = "Touchez un véhicule et la carte ne garde que sa ligne, tracée aux couleurs officielles " +
                    "du réseau. Un bus qui n'a plus donné signe de vie depuis une minute et demie quitte la " +
                    "carte au lieu de vous faire attendre."
            )
        )
        add(
            IntroPage(
                icon = IntroIcon.CITY,
                title = "Autour de moi",
                body = "Un onglet réunit les parkings et leurs places libres, les stations Vélo'v, les arceaux " +
                    "vélos, les emplacements pour les deux-roues et les chantiers en cours. Les chiffres du " +
                    "moment s'affichent avant même d'ouvrir une carte."
            )
        )
        add(
            IntroPage(
                icon = IntroIcon.ALERTS,
                title = "Vos lignes vous préviennent",
                body = "Abonnez-vous aux lignes que vous prenez et choisissez les perturbations qui méritent " +
                    "une notification. L'état du trafic reste visible sur la carte."
            )
        )
        if (includeWidgets) {
            add(
                IntroPage(
                    icon = IntroIcon.WIDGETS,
                    title = "Vos passages sur l'écran d'accueil",
                    body = "Six widgets y posent les prochains départs de vos arrêts, l'état de vos lignes, les " +
                        "places d'un parking, une station Vélo'v ou les chantiers autour de vous."
                )
            )
        }
    }

    /** Libellé du bouton principal : il avance, puis il ouvre l'application. */
    fun buttonTitle(pageIndex: Int, pageCount: Int): String =
        if (pageIndex >= pageCount - 1) "Commencer" else "Suivant"
}
