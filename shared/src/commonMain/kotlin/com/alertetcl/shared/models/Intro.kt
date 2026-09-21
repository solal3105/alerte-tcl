package com.alertetcl.shared.models

/**
 * Ce que montre une page d'intro : l'icône de l'application, une capture de l'écran concerné, les
 * vrais widgets ou la liste des corrections. Chaque plateforme sait dessiner chacun de ces cas.
 */
enum class IntroVisual {
    APP,
    STOP,
    TIMETABLE,
    MAP,
    CITY,
    VELOV,
    ALERTS,
    WIDGETS,
    FIXES
}

/** Une page de l'écran d'intro : son illustration, son titre, son texte et, à la fin, des exemples. */
data class IntroPage(
    val visual: IntroVisual,
    val title: String,
    val body: String,
    val points: List<String> = emptyList()
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

    /** Version annoncée par la première page. */
    const val VERSION_LABEL = "Version 2"

    /** True si l'intro doit s'ouvrir au lancement, d'après la révision déjà vue. */
    fun shouldShow(seenRevision: Int): Boolean = seenRevision < REVISION

    /**
     * Les pages dans l'ordre d'affichage. [includeWidgets] n'est vrai que sur iOS : Android n'a pas
     * de widgets.
     */
    fun pages(includeWidgets: Boolean): List<IntroPage> = buildList {
        add(
            IntroPage(
                visual = IntroVisual.APP,
                title = "Lyon Pocket",
                body = "Cette version change la façon de préparer un trajet : vous savez quand votre bus " +
                    "arrive, vous lisez les horaires de toute la journée et vous voyez ce qui vous attend " +
                    "dans la rue."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.STOP,
                title = "Vous savez où en est votre bus",
                body = "Ouvrez un arrêt : vous voyez l'heure à laquelle le prochain bus y arrive, le nombre " +
                    "d'arrêts qu'il lui reste et depuis combien de temps sa position a été transmise. " +
                    "L'heure annoncée tient compte du retard en cours."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.TIMETABLE,
                title = "Les horaires de toute la journée",
                body = "Chaque ligne a sa fiche horaire complète, sens par sens et arrêt par arrêt, pour " +
                    "aujourd'hui, demain ou une date plus lointaine. Les horaires du SYTRAL sont republiés " +
                    "chaque nuit, courses de fin de service comprises."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.MAP,
                title = "Une carte qui se lit d'un coup d'œil",
                body = "Touchez un véhicule et la carte ne garde que sa ligne, tracée aux couleurs " +
                    "officielles du réseau, avec son retard et l'âge de sa position. Un bus qui n'a plus " +
                    "donné signe de vie depuis une minute et demie quitte la carte."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.CITY,
                title = "Autour de moi",
                body = "Un onglet réunit les parkings et leurs places libres, les stations Vélo'v, les " +
                    "arceaux vélos, les emplacements pour les deux-roues et les chantiers en cours. Les " +
                    "chiffres du moment s'affichent avant même d'ouvrir une carte."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.VELOV,
                title = "Les Vélo'v, station par station",
                body = "Chaque station montre ses vélos et ses places libres, et change de couleur selon " +
                    "qu'elle est pleine, vide ou entre les deux. Un filtre ne garde que les stations où il " +
                    "reste un vélo électrique."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.ALERTS,
                title = "Vos lignes vous préviennent",
                body = "Abonnez-vous aux lignes que vous prenez et choisissez les perturbations qui méritent " +
                    "une notification. Quand le réseau renumérote une ligne, comme la 21 devenue 121, " +
                    "l'application suit sans mise à jour."
            )
        )
        if (includeWidgets) {
            add(
                IntroPage(
                    visual = IntroVisual.WIDGETS,
                    title = "Six widgets sur l'écran d'accueil",
                    body = "Vos prochains départs, l'état de vos lignes, les places d'un parking, une station " +
                        "Vélo'v ou les chantiers autour de vous, sans ouvrir l'application."
                )
            )
        }
        add(
            IntroPage(
                visual = IntroVisual.FIXES,
                title = "Et beaucoup de choses réparées",
                body = "Une relecture complète du code a corrigé soixante-douze défauts, dont quelques-uns " +
                    "affichaient des chiffres faux sans jamais le dire.",
                points = listOf(
                    "Tous les stationnements vélo sont chargés : au-delà du millième, les suivants manquaient.",
                    "Un parking dont le temps réel tombe le dit, au lieu d'annoncer qu'il est complet.",
                    "La localisation et les alertes s'arrêtent quand vous quittez l'application."
                )
            )
        )
    }

    /** Libellé du bouton principal : il avance, puis il ouvre l'application. */
    fun buttonTitle(pageIndex: Int, pageCount: Int): String =
        if (pageIndex >= pageCount - 1) "Commencer" else "Suivant"
}
