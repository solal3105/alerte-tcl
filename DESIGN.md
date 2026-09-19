# Charte d'interface de Lyon Pocket

Ce document fixe ce que les deux applications, iOS et Android, ont en commun à l'écran. Chaque
plateforme l'implémente avec ses composants natifs (SwiftUI d'un côté, Jetpack Compose de l'autre),
mais une seule fois : un composant par usage, réutilisé partout. Les valeurs elles-mêmes (couleurs,
textes, règles d'état) vivent dans le module partagé Kotlin et ne sont jamais recopiées dans une vue.

## Couleurs

Toutes les couleurs sémantiques viennent de `AppColors` (module partagé, `shared/.../design/AppColors.kt`).
Une vue n'emploie jamais une couleur système nommée (`.blue`, `Color.Red`, `0xFF43A047`…). Côté
iOS, les jetons se lisent par `Color.appAccent`, `.appSuccess`, `.appWarning`, `.appError`,
`.appFavorite` et par les extensions `TransportMode.color`, `VehicleType.clusterColor`,
`AlertSeverity.color`, `TravauxImportance.color`, `Parking.availabilityColor`. Côté Android, par
l'objet `Tokens` (`ui/theme/Tokens.kt`) qui expose les mêmes noms à Compose.

| Jeton | Clair | Sombre | Usage |
|---|---|---|---|
| accent | `#1565C0` | `#0A84FF` | boutons principaux, liens, sélection, icônes actives |
| success | `#2E7D32` | `#66BB6A` | service normal, position récente, parking libre, ouvert |
| warning | `#EF6C00` | `#FFA726` | perturbation, position vieillissante, parking presque plein |
| error | `#D32F2F` | `#EF5350` | perturbation majeure, position obsolète, parking complet, fermé |
| favorite | `#F9A825` | `#FFD54F` | étoile des lignes favorites |

L'accent est fixe sur les deux plateformes : Android n'emprunte pas la couleur du fond d'écran
(couleur dynamique Material désactivée) pour que l'interface soit la même que sur iOS.

Les lignes ont leurs couleurs officielles (palette `route_color` du GTFS, via `LineColors`) ; tant
qu'une ligne n'y figure pas, elle est neutre (fond discret, liseré, texte foncé), aucune charte n'est
écrite en dur. Cette palette s'applique partout où une ligne apparaît, filtres compris. Une couleur de ligne ne sert qu'à désigner cette ligne. Les modes
de transport ont une couleur d'iconographie (`AppColors.mode`), réservée aux filtres et aux onglets,
jamais utilisée pour représenter une ligne.

Les tracés des lignes sur la carte prennent la couleur officielle de la ligne, avec une épaisseur par
mode définie une fois (`MapStyle` : métro 4, tramway 3,5, funiculaire 3, bus C 2,5, bus 2), une légère
transparence et, sur Android, un liseré clair qui les détache du fond. Toucher un véhicule isole sa
ligne : seuls ses véhicules et son tracé restent visibles, quels que soient les réglages de tracés, le
bandeau trafic s'efface et un bandeau décrit le véhicule (ligne, direction, fraîcheur de la position,
retard, dernier arrêt) avec deux boutons, « Voir plus » pour sa fiche et « Fermer » pour tout
réafficher (bouton rond en haut à droite). Le véhicule touché porte un halo à la couleur de sa ligne
sur la carte. Le même bandeau, sans « Voir plus », sert au filtre lancé depuis la fiche d'un arrêt.
Chaque véhicule est un disque à la couleur de sa ligne portant le pictogramme de son type (bus, tram,
trolley, navigone…), son numéro de ligne dans une capsule juste en dessous, et sa flèche de cap ; à
partir du zoom `MapStyle.ZOOM_FRESHNESS_RING`, un arc sur le bord intérieur du disque s'assombrit avec
le délai depuis la dernière position transmise (0 à 90 s). L'arc est une ombre translucide, donc dans
la teinte de la ligne : rien d'autre que la couleur de la ligne sur un véhicule. La grille de zoom est
partagée (`MapStyle` : points sous 13,5, arrêts à 14,5, arc à 15, badges de lignes sur les arrêts à
16), convertie sur iPhone depuis la largeur visible.

Sur la carte Transport, trois boutons ronds seulement : « Trafic et horaires » (une horloge au repos ;
plein, avec le nombre de lignes touchées, dès qu'il y a des perturbations sur les lignes suivies ; il
ouvre une feuille à deux onglets, Trafic et Horaires), les filtres et la position. La vue satellite se
règle dans les filtres. Les boutons ronds des cartes (et ceux des cartes de l'onglet « Autour de moi »)
n'ont que deux couleurs : l'accent sur verre au repos, disque d'accent
plein avec pictogramme blanc quand le bouton est actif (satellite affiché, filtres en cours,
perturbations sur les lignes suivies, avec leur nombre en badge). Il n'y a plus de capsule « LIVE » en
bas à gauche : le rafraîchissement est automatique et silencieux ; seuls restent les messages d'état
(flux vide, données figées, sources en erreur). L'état du trafic ouvre les alertes ; il n'y a plus de
bandeau en haut de la carte.

Un véhicule dont TCL n'a pas retransmis la position depuis 90 s (règle partagée
`Vehicle.HIDE_AFTER_SECONDS`, relue chaque seconde sur la carte) disparaît de la carte ; sa fiche,
si elle est ouverte, garde la dernière position connue et signale qu'elle est obsolète.

Quand les filtres enregistrés (type de véhicule, lignes) ne laissent aucun véhicule sur la carte, un
bandeau « Vos filtres masquent tous les véhicules » avec « Tout afficher » remplace le silence ; les
numéros de lignes qui ont disparu du réseau sont retirés des filtres au chargement.

## Où est mon bus

Dans la fiche d'un arrêt, chaque carte de ligne et de sens montre, sous les prochains passages, les
véhicules qui n'ont pas encore atteint l'arrêt (`StopApproach`, module partagé), dans une carte teintée
à la couleur de la ligne : deux grands chiffres, le nombre d'arrêts avant le vôtre (« Arrive » quand
c'est le prochain) et l'heure d'arrivée estimée avec « dans 4 min » ou « imminent », puis une ligne
« Position transmise par TCL il y a 12 s » avec le point de fraîcheur. L'estimation est l'horaire
prévu de la course, reconnue par l'heure prévue au prochain arrêt, corrigé du retard constaté par
TCL ; sans course reconnue, seul le nombre d'arrêts est affiché, avec « heure inconnue ». Rien n'est
extrapolé depuis la position elle-même. Toucher la carte cadre la carte sur ce véhicule et l'arrêt.
Sans bus en approche, la section reste visible avec « Aucun bus en route vers cet arrêt pour
l'instant » ; le métro, sans positions en direct, n'a pas cette section. Les passages d'un arrêt sont
groupés par ligne et par sens réel : chaque destination du flux est ramenée au terminus officiel quand il
est reconnu (`DirectionMatching.canonicalDestination`, testé), donc deux cartes pour le métro B et non
une par graphie. Chaque passage est une puce avec le délai en grand (vert quand le véhicule est suivi en
direct) et l'heure en dessous ; les actions « Voir sur la carte » et « Tous les horaires » sont des liens
à l'accent, sans fond. Dans les fiches horaires, toute la largeur d'une ligne de liste est tactile. Le suivi d'un bus en
arrière-plan (activité en direct) a été essayé puis retiré le 16 septembre 2026.

## Autour de moi

L'onglet « Autour de moi » (Transport, Autour de moi, Info : trois onglets) s'ouvre sur la carte de la
ville, immobile et centrée sur la position, sous un voile qui s'épaissit vers le bas ; par-dessus, des
tuiles de verre neutre, avec un pictogramme à l'accent sur un disque bleuté (une seule couleur pour
tout l'accueil), une par entrée de `CityTile` (module partagé, dans l'ordre de l'énumération) :
« Parkings voiture », « Stations Vélo'v », « Arceaux vélos », « Places deux-roues motorisés » sur deux
colonnes, puis « Travaux » en pleine largeur. Chaque tuile porte son titre, une ligne descriptive
(`CityTile.title` / `subtitle`, couleur `AppColors.cityTile`) et, quand la donnée est là, le chiffre du
moment en couleur : places libres, vélos disponibles, chantiers en cours (`CityOverview.liveLine`,
chargé par `CityOverviewService`, chaque source indépendante).

Une tuile ouvre la carte correspondante (parkings ou chantiers). Sur iOS elle est poussée dans une
`NavigationStack` : bouton de retour système, geste de balayage, titre de la tuile en ligne, barre
transparente. Sur Android, une capsule de verre en haut rappelle la tuile et ramène à l'accueil, et le
geste retour du système fait de même.

Tout l'onglet est en verre : tuiles et capsule de retour Android reposent sur `glassSurface` (iOS,
Liquid Glass dès iOS 26 et matériau translucide avec liseré clair avant) ou `Modifier.glass` (Android,
fond translucide et liseré en dégradé). Les boutons ronds des cartes sont, sur iOS 26, les styles de
bouton en verre du système (`.glass` au repos, `.glassProminent` actif), qui répondent au toucher sans
délai ; jamais un effet de verre posé par-dessus un bouton. Jamais de verre dans du verre : l'icône
d'une tuile est sur un disque uni. L'accent de l'application est la teinte de toute l'interface
(interrupteurs compris), pas la couleur « primaire » du système. La fiche d'un parking ne montre que ce
que la donnée contient (plus de « type d'usagers » ni de « type d'ouvrage » inventés).

## Onglet Info

L'application d'abord : son icône, « Lyon Pocket » en très grand, une accroche en corps 19 sur ce
qu'elle fait, puis quatre cases d'un mot chacune (gratuite, sans publicité, sans compte, sans traçage)
avec leur pictogramme, sans phrase d'explication ni chiffres. Ensuite, sous des titres en gras (jamais
de petites capitales) : « Qui est derrière » (une carte : « Solal Gendrin », puis la ligne verte « Conseiller métropolitain
écologiste · Villeurbanne », quatre phrases à la première personne qui finissent par un merci, puis
LinkedIn, Bluesky et X), « Ses autres projets » (TCL 2040, Open Projets née Grands Projets, Nadir : le vrai logo de chacun :
TCL 2040 en blanc sur tuile bleue, Open Projets en couleur sur tuile blanche (logo carré officiel),
l'icône de l'app pour Nadir ; images `LogoTCL2040`,
`LogoOpenProjets`, `LogoNadir` et `drawable-nodpi/logo_*`), « D'où viennent les données » (deux
lignes : la Métropole de Lyon pour les positions, alertes, chantiers, parkings et Vélo'v via
data.grandlyon.com ; SYTRAL Mobilités pour les arrêts, tracés et horaires GTFS ; puis le merci et la
mention d'indépendance), et un pied de page sur une ligne. Faits vérifiés sur le web. Une seule
teinte, l'accent.

## Filtres de la carte Transport

Une feuille en quatre parties, dans cet ordre : « Bus d'un arrêt » quand une ligne est isolée ;
« Carte » (vue satellite, tracés des bus, des trams, du métro et du funiculaire, chaque ligne avec son
pictogramme sur carré teinté) ; « Véhicules affichés »
(un interrupteur par type présent sur la carte, avec le nombre de véhicules) ; « Lignes » (recherche,
favoris, toutes les lignes, dix d'abord). « Tout réafficher » dans la barre quand un filtre est actif.
Les lignes scolaires « Junior Direct » (JD…) n'apparaissent ni sur les arrêts ni dans les prochains
passages (`TransitStop.isDisplayedLine`, module partagé, testé).

## Vélo'v

Les stations Vélo'v (relais `/velov`, données ouvertes du Grand Lyon, rafraîchies toutes les minutes)
sont une tuile de l'onglet « Autour de moi », à côté des parkings voiture, des arceaux vélos, des places
deux-roues (décision du 19 septembre 2026 : la carte Transport ne montre que le réseau TCL). De loin, chaque
station est un point à la couleur de disponibilité (vert dès 3 vélos, orange à 1 ou 2, rouge sans vélo,
gris fermé, barème de `VelovStation.availabilityFor` sur les jetons des parkings) ; dès le zoom des arrêts
(`MapStyle.ZOOM_STOPS`), un carré arrondi avec un vélo et le nombre de vélos disponibles. Le filtre
« Seulement les vélos électriques », dans les filtres de l'onglet, ne compte que ceux-là, avec un éclair
à la place du vélo. La capsule « LIVE » et son compte à rebours valent pour ce type comme pour les
voitures. La fiche donne le nom lisible de la station, l'adresse, les vélos (électriques et mécaniques)
et les places libres, l'heure de la dernière mise à jour et un itinéraire à pied. Le rouge du type
dans le sélecteur est le jeton `AppColors.velov`.

Les barèmes métier sont au même endroit : importance et avancement d'un chantier, progression d'un
chantier (du rouge au vert en onze paliers), disponibilité et type d'un parking, nature d'un chantier
(`TravauxNatureChantier.colorHex`).

## Badge de ligne

Une seule forme : un carré aux coins arrondis à 20 % de sa taille, fond et texte de la palette
officielle, texte en graisse maximale, et une bordure discrète quand le fond est clair
(`LineColors.needsBorder`). Trois tailles d'usage : petite (28 à 32 pt, listes et bandeaux), moyenne
(44 à 56 pt, fiches), grande (72 pt, feuille d'options). La taille du texte se déduit de la taille
du badge et de la longueur du nom. iOS : `AlertLineBadgeView` ; Android : `LineBadge`
(`ui/components/LineBadge.kt`).

## Feuilles

Toute feuille commence par le même en-tête : un titre, un sous-titre facultatif, éventuellement un
badge ou une icône à gauche, et un bouton « Fermer » à droite. Android : `SheetHeader`
(`ui/components/SheetHeader.kt`) ; iOS : barre de navigation avec le titre et un bouton « Fermer »
ou « Annuler ». Les feuilles à choix (options de notification, filtres) s'ouvrent à leur pleine
hauteur ; les fiches (véhicule, arrêt, parking, chantier) s'ouvrent à mi-hauteur et se déploient.
Aucune feuille ne porte de bandeau décoratif (dégradé, halo) : la couleur d'un mode ne sert qu'à
l'icône ou au libellé du mode, jamais de fond.

## Boutons et textes

Un bouton dit ce qui va se passer : « S'abonner à cette ligne », « Enregistrer », « Se désabonner »,
« Voir ces bus sur la carte », « Tout afficher », « Réessayer ». Le bouton principal d'un écran est
plein, à l'accent ; une action destructrice (se désabonner) est à la couleur d'erreur. Les titres
nomment ce qu'on fait sur l'écran (« Horaires », « Options de notification »), pas ce qu'on va
ressentir. Le vocabulaire est celui du voyageur : ligne, arrêt, sens, passage, perturbation.

## États génériques

Chaque écran qui charge des données a trois états et un message pour chacun :

- chargement : un indicateur et « Chargement… » (ou un texte plus précis, « Chargement des horaires… ») ;
- vide : une icône, une phrase qui dit ce qui manque et, si possible, l'action pour y remédier
  (« Suivez vos lignes » et « S'abonner à une ligne ») ;
- erreur : la phrase traduite du module partagé (`ApiError`), jamais un message technique brut,
  et un bouton « Réessayer ».

## Alertes et notifications

Les trois types d'alertes portent partout les mêmes libellés et descriptions
(`AlertSeverity.displayName` et `.description`) : « Perturbation majeure » (interruptions totales
de service), « Perturbation » (retards et déviations importantes), « Information » (informations et
travaux prévus). Le bandeau trafic de la carte est calculé par `TrafficBanner` : mêmes textes, même
ton (normal, avertissement, majeur) sur les deux plateformes. Les abonnements
(`LineSubscriptions`) sont distincts des lignes favorites : un favori sert aux filtres de la carte
et à la liste des fiches horaires, un abonnement déclenche des notifications, avec le choix des types
d'alertes dans la feuille « Options de notification ». Les dates des alertes s'écrivent par
`AlertDates` (« Il y a 12 min », « 14:30 », « 15 sept. », « Jusqu'au 16 sept. à 06:00 »).

## Parcours de référence

Les captures des parcours servent de référence de parité : `captures-tests/fiches-horaires/{ios,android}`
pour les fiches horaires et le filtre d'arrêt, `captures-tests/alertes/{ios,android}` pour les
abonnements et les options de notification, `captures-tests/ou-est-mon-bus-velov/{ios,android}` pour
« où est mon bus » et les stations Vélo'v. Elles se produisent avec les modes démo
décrits dans le README ; tout changement d'interface se vérifie en les refaisant sur les deux plateformes.
