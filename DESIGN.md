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
l'instant » ; le métro, sans positions en direct, n'a pas cette section. Le suivi d'un bus en
arrière-plan (activité en direct) a été essayé puis retiré le 16 septembre 2026.

## Vélo'v

Les stations Vélo'v (relais `/velov`, données ouvertes du Grand Lyon, rafraîchies toutes les minutes)
s'activent depuis les filtres de la carte, disparaissent tant qu'une ligne est isolée sur la carte, et
apparaissent au même zoom que les arrêts : un carré arrondi à la couleur de disponibilité (vert dès 3
vélos, orange à 1 ou 2, rouge sans vélo, gris fermé, barème de `VelovStation.availabilityFor` sur les
jetons des parkings) avec un vélo et le nombre de vélos disponibles. Le filtre « Seulement les vélos
électriques » ne compte que ceux-là, avec un éclair à la place du vélo. Sur la carte, l'ordre du bas
vers le haut est fixe : tracés des lignes, arrêts, stations Vélo'v, véhicules. La fiche donne le nom
lisible de la station, l'adresse, les vélos (électriques et mécaniques) et les places libres, l'heure
de la dernière mise à jour et un itinéraire à pied.

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
