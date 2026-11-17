package com.alertetcl.shared.models

/**
 * Ce que montre une page d'intro : l'icône de l'application, une capture de l'écran concerné, les
 * vrais widgets, la liste des corrections, ou une illustration animée de la prévision Vélo'v (les
 * `VELOV_FORECAST_*`, dessinées avec les données de [VelovForecastDemo]). Chaque plateforme sait
 * dessiner chacun de ces cas.
 */
enum class IntroVisual {
    APP,
    STOP,
    TIMETABLE,
    MAP,
    CITY,
    VELOV,
    /** Un marqueur de station dont le chiffre devient fourchette, autour d'un cadran qui avance. */
    VELOV_FORECAST_HERO,
    /** La carte de démonstration, son curseur qui avance seul et les fourchettes des stations. */
    VELOV_FORECAST_MAP,
    /** Le graphique des 24 heures qui se dessine, le curseur qui le parcourt et la fourchette écrite. */
    VELOV_FORECAST_RANGE,
    /** La piste de couleur des chances, la chance qui change avec l'heure et la période à risque. */
    VELOV_FORECAST_CHANCE,
    /** Le choix électriques, classiques, places qui défile, et le graphique qui suit. */
    VELOV_FORECAST_KINDS,
    /** La station qui passe au rouge, puis la voisine plus sûre qui s'ajoute dessous. */
    VELOV_FORECAST_NEARBY,
    /** Huit semaines de relevés qui se remplissent, puis le contrôle du lundi. */
    VELOV_FORECAST_FRESH,
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
 * compare par [shouldShow]. Après une mise à jour, il ne montre que ce qui est arrivé depuis la
 * révision vue ([pages]). Il reste consultable en entier depuis l'onglet Info.
 */
object Intro {
    /** Révision du contenu : l'augmenter fait reparaître l'intro une fois après la mise à jour. */
    const val REVISION = 2

    /** Révision enregistrée tant que l'intro n'a jamais été vue. */
    const val NEVER_SEEN = 0

    /** True si l'intro doit s'ouvrir au lancement, d'après la révision déjà vue. */
    fun shouldShow(seenRevision: Int): Boolean = seenRevision < REVISION

    /**
     * Les pages dans l'ordre d'affichage. [includeWidgets] n'est vrai que sur iOS : Android n'a pas
     * de widgets.
     *
     * [seenRevision] est la révision déjà vue. Jamais vue ([NEVER_SEEN], et toujours depuis l'onglet
     * Info) : toutes les pages, la page d'ouverture d'abord. Vue avant la dernière mise à jour :
     * seulement ce qui est arrivé depuis, derrière une page qui annonce la mise à jour. Déjà à jour :
     * toutes les pages, comme depuis l'onglet Info.
     */
    fun pages(includeWidgets: Boolean, seenRevision: Int): List<IntroPage> {
        val shown = SECTIONS.filter { includeWidgets || it.page.visual != IntroVisual.WIDGETS }
        val news = shown.filter { it.revision > seenRevision }
        return if (seenRevision == NEVER_SEEN || news.isEmpty()) listOf(OPENING) + shown.map { it.page }
        else listOf(UPDATE) + news.map { it.page }
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

    /** Une page et la révision qui l'a ajoutée. */
    private class Section(val revision: Int, val page: IntroPage)

    /** Première page de l'intro complète. */
    private val OPENING = IntroPage(
        visual = IntroVisual.APP,
        title = "Lyon Pocket, version 2",
        body = "Voici ce qui change pour vous, écran par écran."
    )

    /** Première page après une mise à jour : elle annonce ce qu'apporte la dernière révision. */
    private val UPDATE = IntroPage(
        visual = IntroVisual.VELOV_FORECAST_HERO,
        title = "Les Vélo'v, 24 heures à l'avance",
        body = "Avant de partir, sachez s'il restera un vélo ou une place à votre station."
    )

    /** Les pages qui suivent la première, dans l'ordre de l'intro complète. */
    private val SECTIONS = listOf(
        Section(
            1,
            IntroPage(
                visual = IntroVisual.STOP,
                title = "L'heure d'arrivée de votre bus",
                body = "Ouvrez un arrêt : vous voyez à quelle heure le prochain bus y arrive et combien " +
                    "d'arrêts il lui reste. Son retard est déjà compté dans l'heure annoncée."
            )
        ),
        Section(
            1,
            IntroPage(
                visual = IntroVisual.TIMETABLE,
                title = "Les horaires de toute la journée",
                body = "Chaque ligne a sa fiche complète, sens par sens et arrêt par arrêt, pour aujourd'hui, " +
                    "demain ou une date plus lointaine. Elle vient du SYTRAL et se recharge chaque nuit."
            )
        ),
        Section(
            1,
            IntroPage(
                visual = IntroVisual.MAP,
                title = "Une ligne à la fois sur la carte",
                body = "Touchez un véhicule : la carte ne garde que sa ligne, à ses couleurs officielles, avec " +
                    "son retard et l'âge de sa position."
            )
        ),
        Section(
            1,
            IntroPage(
                visual = IntroVisual.CITY,
                title = "Autour de moi",
                body = "Un onglet réunit les parkings et leurs places libres, les stations Vélo'v, les arceaux " +
                    "vélos, les places deux-roues et les chantiers. Les chiffres du moment s'affichent dès " +
                    "l'accueil."
            )
        ),
        Section(
            1,
            IntroPage(
                visual = IntroVisual.VELOV,
                title = "Les vélos libres, station par station",
                body = "Chaque station montre ses vélos et ses places, et change de couleur quand elle se vide. " +
                    "Un filtre ne garde que celles où il reste un vélo électrique."
            )
        ),
        Section(
            2,
            IntroPage(
                visual = IntroVisual.VELOV_FORECAST_MAP,
                title = "Avancez l'heure sur la carte",
                body = "Faites glisser le curseur : chaque station affiche les vélos à prévoir à l'heure choisie."
            )
        ),
        Section(
            2,
            IntroPage(
                visual = IntroVisual.VELOV_FORECAST_RANGE,
                title = "Une fourchette, pas un pari",
                body = "« 3 à 8 vélos » : 8 fois sur 10, la réalité tombe dedans. Plus l'heure est lointaine, plus elle s'élargit."
            )
        ),
        Section(
            2,
            IntroPage(
                visual = IntroVisual.VELOV_FORECAST_CHANCE,
                title = "Vos chances, d'un coup d'œil",
                body = "Vert, orange ou rouge : la fiche dit si vous trouverez un vélo, et quand la station risque d'être vide."
            )
        ),
        Section(
            2,
            IntroPage(
                visual = IntroVisual.VELOV_FORECAST_KINDS,
                title = "Électriques, classiques et places",
                body = "Chacun a sa propre prévision, y compris les places pour rendre votre vélo."
            )
        ),
        Section(
            2,
            IntroPage(
                visual = IntroVisual.VELOV_FORECAST_NEARBY,
                title = "Un plan B à deux pas",
                body = "Quand votre station risque d'être vide, la fiche propose une voisine plus sûre, avec le temps à pied."
            )
        ),
        Section(
            2,
            IntroPage(
                visual = IntroVisual.VELOV_FORECAST_FRESH,
                title = "Elle apprend chaque semaine",
                body = "Chaque lundi, elle réapprend sur les huit dernières semaines. Si elle n'est plus vérifiée, elle disparaît : mieux vaut rien que du faux."
            )
        ),
        Section(
            1,
            IntroPage(
                visual = IntroVisual.ALERTS,
                title = "Des notifications sur vos lignes",
                body = "Abonnez-vous aux lignes que vous prenez et choisissez les perturbations qui méritent de " +
                    "vous déranger. Une ligne renumérotée est suivie sans mise à jour."
            )
        ),
        Section(
            1,
            IntroPage(
                visual = IntroVisual.WIDGETS,
                title = "Six widgets sur l'écran d'accueil",
                body = "Ils affichent vos prochains départs, l'état de vos lignes, un parking, une station " +
                    "Vélo'v ou les chantiers autour de vous, sans ouvrir l'application."
            )
        ),
        Section(
            1,
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
    )
}
