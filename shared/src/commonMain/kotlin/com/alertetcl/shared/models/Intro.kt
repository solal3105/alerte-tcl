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
                title = "Lyon Pocket, version 2",
                body = "Voici ce qui change pour vous, écran par écran."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.STOP,
                title = "L'heure d'arrivée de votre bus",
                body = "Ouvrez un arrêt : vous voyez à quelle heure le prochain bus y arrive et combien " +
                    "d'arrêts il lui reste. Son retard est déjà compté dans l'heure annoncée."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.TIMETABLE,
                title = "Les horaires de toute la journée",
                body = "Chaque ligne a sa fiche complète, sens par sens et arrêt par arrêt, pour aujourd'hui, " +
                    "demain ou une date plus lointaine. Elle vient du SYTRAL et se recharge chaque nuit."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.MAP,
                title = "Une ligne à la fois sur la carte",
                body = "Touchez un véhicule : la carte ne garde que sa ligne, à ses couleurs officielles, avec " +
                    "son retard et l'âge de sa position."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.CITY,
                title = "Autour de moi",
                body = "Un onglet réunit les parkings et leurs places libres, les stations Vélo'v, les arceaux " +
                    "vélos, les places deux-roues et les chantiers. Les chiffres du moment s'affichent dès " +
                    "l'accueil."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.VELOV,
                title = "Les vélos libres, station par station",
                body = "Chaque station montre ses vélos et ses places, et change de couleur quand elle se vide. " +
                    "Un filtre ne garde que celles où il reste un vélo électrique."
            )
        )
        add(
            IntroPage(
                visual = IntroVisual.ALERTS,
                title = "Des notifications sur vos lignes",
                body = "Abonnez-vous aux lignes que vous prenez et choisissez les perturbations qui méritent de " +
                    "vous déranger. Une ligne renumérotée est suivie sans mise à jour."
            )
        )
        if (includeWidgets) {
            add(
                IntroPage(
                    visual = IntroVisual.WIDGETS,
                    title = "Six widgets sur l'écran d'accueil",
                    body = "Ils affichent vos prochains départs, l'état de vos lignes, un parking, une station " +
                        "Vélo'v ou les chantiers autour de vous, sans ouvrir l'application."
                )
            )
        }
        add(
            IntroPage(
                visual = IntroVisual.FIXES,
                title = "Soixante-douze défauts corrigés",
                body = "Le code a été relu de bout en bout cet été. Certains de ces défauts vous montraient des " +
                    "chiffres faux sans jamais le dire.",
                points = listOf(
                    "Tous les stationnements vélo sont chargés : au-delà du millième, les suivants manquaient.",
                    "Un parking dont le temps réel tombe le dit, au lieu d'annoncer qu'il est complet.",
                    "La localisation et les alertes s'arrêtent quand vous quittez l'application."
                )
            )
        )
    }

    /**
     * Libellé du bouton principal. Sur la dernière page il dit où l'on arrive : la carte au premier
     * lancement ([atLaunch]), l'onglet Info quand l'intro a été rouverte depuis là.
     */
    fun buttonTitle(pageIndex: Int, pageCount: Int, atLaunch: Boolean): String = when {
        pageIndex < pageCount - 1 -> "Suivant"
        atLaunch -> "Voir la carte"
        else -> "Fermer"
    }
}
