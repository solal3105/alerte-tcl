# Audit de cohérence : couleurs, interfaces, parcours et architecture

Audit réalisé le 15 septembre 2026 sur l'état du dépôt à cette date (branche
`fix/prod-readiness-review`, fonctionnalités « bus de cet arrêt », fiches horaires et palette
officielle incluses). Il repose sur trois inventaires complets du code, iOS et Android, dont les
références précises (fichier et ligne) sont reprises ci-dessous. Il décrit ce qui existe, ce qui
diverge, et propose une cible et un ordre de travail.

## 1. Le constat en chiffres

- L'application iOS pèse environ 16 000 lignes de Swift, dont 7 900 de logique (services, modèles,
  ViewModels, utilitaires). Le module Kotlin partagé en pèse 4 100. Environ 84 % de la logique Swift
  possède un jumeau Kotlin, et 99 % du module partagé possède un jumeau Swift : la logique existe deux
  fois, et le projet Xcode ne lie pas le framework Kotlin (aucune référence à `Shared.framework` dans
  `project.pbxproj`, aucun `import Shared`). Le module partagé ne sert qu'à Android.
- Vingt-quatre divergences de comportement réelles ont été relevées entre les deux copies (section 5.2).
  Sur les soixante derniers commits, vingt ont dû modifier les deux plateformes à la fois.
- Les couleurs viennent de quatre tables « par mode de transport » concurrentes, d'une charte de secours
  qui diffère entre Swift et Kotlin, et d'environ 295 littéraux de couleur dans les vues iOS contre 157
  côté Android. Aucune couleur d'état (succès, avertissement, erreur) n'est identique entre les deux
  plateformes.
- Les tests se résument à un fichier Kotlin (dix cas, fiches horaires uniquement). Il n'existe aucun test
  iOS et aucune intégration continue de compilation ou de test.
- La documentation n'est plus à jour : le README décrit des onglets disparus et nomme l'application
  « Alerte TCL » alors qu'elle s'appelle « Lyon Pocket » sur les deux plateformes et sur le site.

## 2. Couleurs

### 2.1 Ce qui existe aujourd'hui

La palette officielle du GTFS (`route_color`, `route_text_color`) est désormais la source des couleurs
de lignes sur les deux plateformes (`LinePalette`, persistée), avec une charte historique en secours.
Cette charte de secours diverge déjà : le texte des badges de bus ordinaires est rouge sur iOS
(`LineColorHelper.swift`) et quasi noir en Kotlin (`LineColors.kt`) ; les trolleybus « TB » ont un texte
blanc sur fond jaune côté iOS, noir côté Android ; un code « TB1 » sort violet tram sur iOS et jaune
trolley sur Android parce que les tests ne sont pas dans le même ordre.

Les couleurs « par mode de transport » existent en quatre tables qui ne se ressemblent pas :
`TransportMode.color` (iOS, filtres et fiche ligne des alertes), `typeColor` dans `LiveMapView.swift`
(filtres de la carte), `VehicleType.clusterColor` (iOS et Kotlin, fiche véhicule) et les `Mode*` du thème
Android. Le même bus est indigo dans les filtres des alertes, violet dans les filtres de la carte et gris
dans la fiche véhicule. Ces couleurs contredisent les couleurs officielles au même endroit : la fiche de
la ligne A des alertes peint son bandeau en orange (couleur « mode métro ») à côté d'un badge rose
officiel. La navette fluviale est cyan sur iOS et grise sur Android.

Les couleurs d'état ne sont pas partagées : iOS utilise les couleurs système (`.red`, `.orange`,
`.green`, adaptatives), Android des valeurs fixes (`StatusError`, `StatusWarning`, `StatusSuccess`), et
le module Kotlin fige pour la fraîcheur des positions les valeurs claires d'iOS. Des écarts internes
existent aussi : les marqueurs de parkings Android utilisent un orange différent de celui de l'écran,
l'importance des travaux est jaune sur iOS et verte sur Android, la nature des chantiers suit une
palette Apple sur iOS et une palette Tailwind en Kotlin. La couleur d'accent déclarée dans les
ressources iOS (magenta) n'est utilisée nulle part : l'accent réel est un `.blue` codé en dur dans une
dizaine de vues, sans jumeau Android où l'accent suit le fond d'écran (couleur dynamique Material).

Le mode sombre tient sur iOS grâce aux couleurs système, sauf l'écran Info et le fond satellite ; il
tient sur Android sauf le widget « Prochains passages », entièrement figé en clair.

### 2.2 Cible

Un seul jeu de jetons de couleur, défini une fois dans le module partagé et consommé par les deux
plateformes à travers deux adaptateurs minces (`Color(hex:)` côté Swift, `colorFromHex` côté Compose) :

- les couleurs de lignes : la palette officielle, puis la charte de secours, en une seule implémentation
  Kotlin (celle de Swift disparaît quand iOS consomme le module) ;
- une seule table de couleurs par mode, réservée à l'iconographie (icône d'un mode dans un filtre), jamais
  utilisée pour représenter une ligne précise ;
- les couleurs d'état (succès, avertissement, erreur, information) et de fraîcheur, en variantes claire et
  sombre, identiques sur les deux plateformes ;
- les barèmes métier (avancement et importance des travaux, disponibilité des parkings) au même endroit ;
- un accent unique et fixe (le bleu actuel), appliqué par le thème sur les deux plateformes, ce qui
  suppose de désactiver la couleur dynamique Material sur Android au profit du thème de marque.

Toutes les couleurs nommées ou en hexadécimal disséminées dans les vues sont remplacées par ces jetons.
Le widget Android passe au thème dynamique de Glance pour suivre le mode sombre.

## 3. Interfaces et composants

### 3.1 Ce qui existe aujourd'hui

Les deux plateformes ont chacune construit leurs composants sans spécification commune :

- Le badge de ligne est une capsule à largeur adaptative avec bordure sur fond clair côté iOS, un carré
  fixe sans bordure ni réduction de police côté Android : les lignes à fond blanc y deviennent invisibles
  et les noms longs sont tronqués.
- Les feuilles s'ouvrent à mi-hauteur puis se déploient sur iOS ; elles sont plafonnées à 560 dp sur
  Android, souvent sans titre ni bouton de fermeture (fiche véhicule, alertes).
- Les fiches horaires sont une pile de navigation à l'intérieur de la feuille sur iOS et un dialogue
  plein écran sur Android : deux modèles mentaux pour le même parcours.
- Les états vides, de chargement et d'erreur sont réinventés écran par écran ; Android affiche souvent le
  message technique brut là où iOS traduit en langage utilisateur (avec la variante « les serveurs se
  reposent la nuit »).
- Les textes divergent pour la même notion : « horaires sans pastille verte » contre « horaires en gris »,
  « Réseau TCL normal » contre « Réseau fluide », ponctuation « ... » contre « … », lien de
  confidentialité différent, mention d'indépendance présente sur iOS seulement.

### 3.2 Cible

Un document de conception court (`DESIGN.md`) qui fixe, pour les deux plateformes : les surfaces (carte,
feuille, capsule), la hiérarchie typographique, le badge de ligne (une forme, trois tailles, bordure
automatique sur fond clair), les boutons (principal, secondaire, action de carte), les champs de recherche,
les puces, et les trois états génériques (chargement, vide, erreur) avec leurs messages. Chaque
plateforme implémente ce document avec ses composants natifs, mais une fois : un `LineBadge`, un
`StateView`, un `SheetHeader` réutilisés partout.

Les textes affichés vivent dans le module partagé (`Strings`), y compris les messages d'erreur traduits,
pour que les deux plateformes disent exactement la même chose. Les feuilles ont toutes un titre et un
bouton « Fermer », et la même hauteur de départ. Les parcours à plusieurs étapes (fiches horaires) gardent
les mêmes étapes, titres et retours sur les deux plateformes, quel que soit le conteneur natif.

## 4. Parcours utilisateur

### 4.1 Ce qui existe aujourd'hui

Les quatre onglets et les parcours principaux sont les mêmes, mais chaque écran a dérivé :

- Filtres de la carte : un seul type de véhicule à la fois sur iOS (avec « Tous les types »), plusieurs sur
  Android où le métro et le funiculaire ne peuvent pas être masqués ; iOS cumule deux mécanismes de
  sélection de lignes ; les types sont persistés sur iOS, pas sur Android.
- Bandeau trafic : deux machines à états, deux vocabulaires, des badges de lignes abonnées avec pastille sur
  iOS seulement, un état « Données partielles » sur Android seulement.
- Alertes : options de notification par ligne sur iOS seulement, alors que l'accueil Android promet de
  « choisir les types d'alertes » ; détail d'alerte sans cause ni dates sur Android ; corpus de lignes
  différent (iOS enrichit depuis l'API, Android n'utilise que la liste prédéfinie).
- Travaux : dates de début et de fin, jours restants et bouton « S'y rendre » sur iOS seulement ; badge
  d'importance et carte « Perturbation » sur Android seulement ; clustering sur iOS seulement.
- Parkings : lignes de transport sur la carte, clustering, info-bulle « N places », panneau LIVE et
  « Mis à jour » sur iOS seulement ; tarifs sur une seule rangée qui déborde sur Android.
- Widgets : trois widgets opérationnels sur iOS, code présent mais désactivé dans le manifeste Android, et
  bouton « Ajouter au widget » retiré de la fiche d'arrêt Android.
- Notifications : iOS notifie les lignes d'un abonnement distinct des favoris ; Android notifie les
  favoris. Mettre une ligne en favori déclenche des notifications sur une plateforme et pas sur l'autre.

### 4.2 Cible

Une carte des parcours canonique, écran par écran, qui devient la liste de parité : Transport (carte,
fiche véhicule, fiche arrêt, filtres, bandeau trafic, alertes, fiches horaires), Travaux, Parkings, Info,
accueil des permissions, widgets. Pour chaque écran, le contenu de référence est celui de la plateforme
la plus complète aujourd'hui (le plus souvent iOS), et l'autre plateforme le rejoint. Les états et
règles (filtres, bandeau, abonnements) sont calculés une seule fois dans le module partagé, ce qui rend
la parité mécanique plutôt que surveillée.

Trois décisions produit sont à prendre avant ce chantier : réactiver les widgets Android ou retirer leur
code ; adopter un modèle unique d'abonnement aux notifications (abonnements distincts des favoris, comme
iOS, ou favoris, comme Android) ; conserver ou non la couleur dynamique Material sur Android.

## 5. Architecture

### 5.1 Ce qui existe aujourd'hui

L'intention documentée (`CLAUDE.md`, `KMP_MIGRATION.md`) est que toute la logique vive dans le module
Kotlin partagé. En réalité le module est un second back-end complet écrit pour Android, maintenu en
parallèle d'un back-end Swift complet, sans lien ni test croisé. Les commentaires « miroir Swift » et
« parité iOS » décrivent des recopies manuelles.

Trois architectures de présentation se superposent : des `ObservableObject` iOS qui portent filtrage,
viewport et persistance ; des ViewModels partagés réduits aux données brutes ; des Composables Android qui
refont le filtrage et lisent leurs préférences directement dans le stockage. La persistance n'a ni les mêmes
clés ni la même sémantique (abonnements, sévérités sérialisées différemment). Les DTO réseau existent en
trois exemplaires (modèles Swift, `Dtos.kt`, widget iOS). Le réseau n'a pas la même tolérance (codes HTTP,
retry, décodage permissif). La clé de ligne des fiches horaires est définie quatre fois (Python, worker,
Swift, Kotlin).

### 5.2 Les divergences de comportement qui en découlent

Elles donnent un résultat différent à l'utilisateur selon sa plateforme. Les plus lourdes :

1. Le mode de TB11, TB12, TS, TGS et N1 diffère (bus sur iOS, tramway ou navette sur Android).
2. La liste « Toutes les lignes » d'iOS oublie une quinzaine de lignes (C4, S4, S12, 28, 29, 36, 41, 44,
   48, 53, 58, 73, 83, 99, TS) que la liste Android connaît.
3. Une date d'alerte sans fuseau horaire est lue sur iOS et rejetée sur Android, qui considère alors
   l'alerte comme active et déjà commencée.
4. Le prochain arrêt d'un véhicule déjà parti reste affiché sur iOS et disparaît sur Android.
5. Le premier chargement se retente deux fois sur iOS et jamais sur Android ; l'erreur du flux temps réel
   apparaît après trois échecs sur iOS et dès le premier sur Android.
6. Si le serveur cartographique est en panne, iOS retombe sur les tracés embarqués, Android affiche une
   carte sans tracés ; si la table des noms de lignes est en panne, iOS garde un repli, Android affiche le
   code brut et retente toutes les quinze secondes.
7. iOS filtre les véhicules à la fenêtre visible, Android rend tous les véhicules du réseau.
8. Les fantômes de terminus sont dédoublonnés sur iOS seulement.
9. L'accessibilité « réduire les animations » est respectée sur iOS seulement.
10. Les notifications reposent sur des abonnements sur iOS et sur les favoris sur Android ; les
    préférences de sévérité sont lues sur un seul des deux libellés de ligne côté Android.
11. Le widget prochains passages couvre 90 minutes sur iOS et 120 sur Android.

La liste complète compte vingt-quatre entrées ; aucune n'est un choix de plateforme, toutes sont des
copies désynchronisées.

### 5.3 Cible

Le module partagé devient la seule source de vérité, consommé par les deux applications :

1. Lier le framework Kotlin dans Xcode (les étapes sont écrites dans `KMP_MIGRATION.md`), en produisant
   un `XCFramework` par une tâche Gradle pour ne pas alourdir chaque compilation Xcode, et en exposant
   des API agréables à Swift (bibliothèque SKIE ou passerelles `async` pour les fonctions `suspend` et les
   `StateFlow`).
2. Migrer d'abord la logique pure, sans réseau, où le gain est immédiat et le risque faible : fiches
   horaires, palette et couleurs, rapprochement des noms, dates, détection de mode et de type de véhicule,
   fusion des arrêts, filtrage viewport, animation des véhicules, lecture des alertes. Chaque migration
   supprime le fichier Swift correspondant.
3. Migrer ensuite les services (un seul client réseau Ktor, un seul jeu de DTO, une seule politique de
   codes HTTP, de retry et de délais), puis les ViewModels (état des filtres, du bandeau, du focus
   d'arrêt, de la palette dans le module partagé ; côté iOS un mince `ObservableObject` par écran qui
   observe les `StateFlow`).
4. Unifier la persistance par une interface `expect/actual` dans le module partagé, avec les mêmes clés
   et la même sémantique sur les deux plateformes, à commencer par abonnements et sévérités.
5. Mettre les messages destinés à l'utilisateur (erreurs traduites, textes d'interface) dans le module
   partagé.
6. Garder l'interface native de chaque côté, écrite une fois par plateforme à partir de `DESIGN.md`.

À cela s'ajoute l'outillage : une intégration continue sur GitHub qui compile Android et lance les tests
Kotlin à chaque commit, et compile iOS sur un exécuteur macOS (gratuit pour un dépôt public) ; les cas de
démo existants servent de base à des captures de référence automatisées. L'hygiène du dépôt : sortir le
projet du dossier iCloud (les doublons « fichier 2.dex » créés par la synchronisation cassent une
compilation Android sur deux), retirer du suivi git la trace Instruments et `nohup.out`, ignorer
l'environnement Python, supprimer les copies orphelines `commonMain/` et `androidMain/` à la racine,
mettre à jour le README et le nom de l'application.

## 6. Ordre de travail proposé

1. Fondations, un à deux jours : jetons de couleur partagés et suppression des quatre tables
   concurrentes ; textes partagés ; hygiène du dépôt ; intégration continue minimale.
2. Parité produit rapide, deux à trois jours : filtres (multi-sélection persistée sur les deux
   plateformes, métro masquable), bandeau trafic (une machine à états partagée), feuilles avec titre,
   fermeture et hauteur communes, messages d'erreur traduits sur Android, détail des alertes, badge de
   ligne conforme à la spécification, écran Info aligné.
3. Brancher le module partagé dans Xcode et migrer la logique pure, trois à cinq jours, puis les services
   et ViewModels, cinq à huit jours, en supprimant le Swift au fur et à mesure et en couvrant chaque règle
   migrée par un test Kotlin.
4. Décisions produit puis parité fonctionnelle : widgets Android, modèle d'abonnement, Travaux (dates,
   itinéraire, importance), Parkings (lignes, clustering, info-bulles, panneau LIVE).
5. `DESIGN.md` et captures de référence par écran, pour que la cohérence se vérifie à chaque changement
   plutôt qu'à l'audit suivant.

Le gain attendu est double : chaque règle métier n'est plus écrite qu'une fois (environ 6 600 lignes de
Swift disparaissent), et les vingt-quatre divergences se corrigent d'elles-mêmes, puisqu'elles ne sont
que le prix de la copie.


## 7. État d'avancement au 15 septembre 2026

Décisions prises : pas de widgets sur Android (code retiré), abonnements distincts des favoris avec
choix des types d'alertes sur les deux plateformes, accent fixe (le bleu de l'application) sans
couleur dynamique Material.

Fait :

- le module Kotlin est lié à la cible iOS et consommé par l'application ; les fiches horaires, la
  palette, le rapprochement des sens, le focus d'arrêt, les abonnements, la règle de notification,
  le bandeau trafic, les dates des alertes, la liste des lignes du réseau et la détection du mode
  d'une ligne n'existent plus qu'en Kotlin, avec des tests (les divergences 1, 2 et 10 de la
  section 5.2 sont ainsi résolues) ;
- un seul jeu de jetons de couleur (`AppColors`) consommé par les deux plateformes, les quatre
  tables de couleurs par mode et les couleurs système nommées des vues ont disparu, l'accent iOS
  et Android est le même bleu ;
- Android : thème fixe, abonnements avec feuille d'options identique à iOS, détail des alertes avec
  cause et dates, badge de ligne unique avec bordure automatique, en-tête commun des feuilles,
  bandeau trafic partagé, messages d'erreur sans texte technique, canal de notification renommé ;
- `DESIGN.md`, `KMP_MIGRATION.md`, `CLAUDE.md` et le README décrivent l'état réel ; l'intégration
  continue compile Android, lance les tests Kotlin et compile iOS.

Corrigé en production le 15 septembre 2026 au soir, après constat sur téléphone : le relais servait
au premier affichage d'un arrêt une réponse en cache vieille de plusieurs dizaines de minutes, que les
applications écartaient comme passée (« Aucun passage prévu » sur beaucoup d'arrêts). Il rafraîchit
désormais avant de répondre quand l'entrée a dépassé quatre fois sa durée de vie, avec une attente
bornée à quatre secondes. Même soir : le bouton « Voir ces bus sur la carte » n'est plus proposé pour
le métro et les funiculaires, absents du flux de positions, et se nomme selon le mode.

Reste à faire, dans l'ordre : sur la carte, dire explicitement quand des filtres cachent tous les
véhicules, avec un bouton « Tout afficher » (constaté sur téléphone après mise à jour, un filtre
mémorisé par l'ancienne version restait actif) ; filtres de la carte alignés (multi-sélection persistée sur iOS,
métro masquable), services et ViewModels iOS migrés sur le module partagé (les modèles Swift
`TCLAlert`, `Parking`, `Travaux`, `Vehicle` disparaissent alors), Travaux (dates, itinéraire,
importance) et Parkings (lignes, regroupements, info-bulles) au même niveau sur Android, captures
de référence de chaque écran.
