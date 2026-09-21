# CLAUDE.md — Règles de développement AlerteTCL

Ce fichier s'applique à toutes les modifications du projet, par tout agent ou développeur.

---

## Architecture cible

### Backend partagé — Kotlin Multiplatform (KMP)

Toute la logique métier **doit vivre dans `:shared`** (module KMP) et être partagée entre iOS et Android :

- Services réseau, parsing, modèles de données, ViewModels
- Aucun code métier dupliqué entre `AlerteTCL/` et `androidApp/`
- Le module `:shared` expose les APIs via `Shared.framework` (iOS) et directement via dépendance Gradle (Android)
- Migration iOS documentée dans `KMP_MIGRATION.md` ; le framework est lié et consommé par iOS

### Frontend natif

- **iOS** : SwiftUI + UIKit là où nécessaire (ex. `MKMapView` pour performance). Aucun cross-platform framework.
- **Android** : Jetpack Compose exclusivement. Aucun cross-platform framework.
- Les vues sont spécifiques à chaque plateforme — seule la logique est partagée.

---

## Règles de code — non négociables

### DRY et factorisation

- Zéro duplication. Toute logique apparaissant 2 fois doit être extraite.
- Extraire uniquement à la 2e occurrence — pas d'abstraction prématurée.
- Zéro code mort : aucune méthode, propriété, import ou variable inutilisée.
- Chaque fichier a une responsabilité unique et claire.
- La structure doit rester cohérente avec l'architecture existante.

### Qualité

- Zéro dette technique introduite intentionnellement.
- Zéro `force_cast` (`as!`), zéro `force_try` (`try!`) sauf cas documenté.
- Les `@Published` sur un `ObservableObject` impliquent `@MainActor` — toujours déclarer la classe `@MainActor`.
- Les mutations d'état passent par des méthodes — pas d'accès direct à des `var` depuis l'extérieur de leur type owner.

---

## Procédure obligatoire après chaque tâche

### 1. Build iOS

```bash
xcodebuild \
  -project AlerteTCL.xcodeproj \
  -scheme AlerteTCL \
  -destination "generic/platform=iOS Simulator" \
  -configuration Debug build \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | grep -v "framework" | head -30
```

Résultat attendu : `** BUILD SUCCEEDED **`

### 2. Build Android

```bash
export JAVA_HOME=~/jdks/jdk-17.0.12.jdk/Contents/Home
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$JAVA_HOME/bin:$PATH

./gradlew :androidApp:assembleDebug 2>&1 | tail -5
```

Résultat attendu : `BUILD SUCCESSFUL`

### 3. Vérification post-tâche

Avant de déclarer une tâche terminée, confirmer :

- [ ] Build iOS réussi
- [ ] Build Android réussi
- [ ] Aucune régression introduite (grep sur symboles modifiés)
- [ ] Aucune duplication créée
- [ ] Aucun code mort laissé

**Une tâche n'est pas terminée si l'un de ces points échoue.**

---

## Données GeoServer Grand Lyon — points d'attention

### Pagination du endpoint `/bus-lines`

Le endpoint GeoServer `/bus-lines` retourne **1727 features** mais avec une limite par défaut de 1000.
Toujours paginer via `startIndex` jusqu'à avoir récupéré `numberMatched` features.

- iOS : `BusLineService.fetchAllPages()` — boucle `repeat/while` avec `startIndex`
- KMP/Android : `BusLineService.fetchBusLines()` — boucle `do-while` avec `lastPageSize`

Sans pagination, les lignes 15, 52, 89, C5, C7, C12, S4A (et d'autres) sont silencieusement absentes.

### Codes SIRI opérationnels (mapping dynamique)

Grand Lyon envoie dans le flux SIRI des codes internes (`code_ligne`) au lieu des noms commerciaux affichés aux voyageurs.
Le mapping est chargé dynamiquement depuis `/line-mapping` (proxy), construit à partir de l'attribut `code_ligne` des datasets GeoServer.

Note : SYTRAL n'implémente pas LinesDiscovery. Les seuls services SIRI disponibles sont :
- VehicleMonitoring (positions temps réel)
- EstimatedTimetables (horaires estimés)
- SituationExchange (alertes)

La topologie du réseau (noms de lignes, correspondances) est disponible dans les fichiers GTFS/NeTEx.

### Numérotation des alertes trafic

Le champ `n` du flux `/alerts` n'est pas un identifiant : c'est le rang de l'alerte dans la réponse
(1, 2, 3…, renuméroté à chaque génération). S'en servir comme identifiant faisait repartir les
notifications tous les jours, puisque la disparition d'une alerte en tête décale toutes les autres.
L'identité vient de `AlertIdentity` (module partagé) : ligne, titre, début et empreinte du message.
Les entrées que TCL publie en double pour une même perturbation (une par objet concerné) sont
fusionnées à la lecture. Tout changement de cette règle doit s'accompagner d'une nouvelle base
silencieuse (`notifBaselineDone.v…` côté iOS, `baseline_done_v…` côté Android), sinon toutes les
alertes en cours repartent d'un coup en notification.

### Ligne RX

La ligne RX est présente dans le flux SIRI (véhicules actifs) mais **absente du GeoServer** `/bus-lines`.
Son tracé ne peut pas être affiché sur la carte. Problème côté données Grand Lyon.

### Où est mon bus et suivi d'un bus

`StopApproach` (module partagé) croise les positions SIRI (prochain arrêt, heure prévue, retard) avec
la fiche horaire du sens pour donner, à un arrêt, le nombre d'arrêts restants et une arrivée estimée
(horaire prévu de la course corrigé du retard). L'âge de la position reste affiché. Le suivi d'un bus
en arrière-plan (activité en direct, notification) a été retiré à la demande de Solal le 16 septembre
2026 : ne pas le réintroduire.

### Stations Vélo'v

Route `/velov` du proxy : `jcd_jcdecaux.jcdvelov/all.json` (données publiques, sans identifiant) allégé
aux champs affichés, cache 60 s. Modèle `VelovStation`, service `VelovService`. Les stations sont le
type `ParkingType.VELOV` de l'onglet « Autour de moi » (décision du 19 septembre 2026 : plus rien d'autre que le
réseau TCL sur la carte Transport, ne pas les y remettre) : chargées par les vues modèles parkings
(`ParkingViewModel` partagé pour Android, `ParkingViewModel.swift` pour iOS), rafraîchies toutes les
minutes, point coloré de loin et carré avec le nombre de vélos dès `MapStyle.ZOOM_STOPS`, filtre
« seulement les vélos électriques » persisté (`FavoritesStore.velovElectricOnly`, `UserDefaults`
`parking.velovElectricOnly`).

### Onglet « Autour de moi »

Trois onglets : Transport, Autour de moi, Info (route Android `ville`, `CityView` / `CityScreen`).
Accueil = carte immobile en fond + tuiles de verre (`CityTile`, module partagé : quatre types de
stationnement et les chantiers, textes `title`/`subtitle`, couleur `AppColors.cityTile`) avec les
chiffres du moment (`CityOverviewService` → `CityOverview.liveLine`, testé). Puis la carte choisie
(`ParkingMapView(parkingType:)` / `TravauxMapView` ; `ParkingScreen(type)` / `TravauxScreen`) : iOS la
pousse dans une `NavigationStack` (retour système), Android pose une capsule de retour et un
`BackHandler`. Style verre partagé : `glassSurface` + `MapGlassButton` (iOS, `GlassStyle.swift`),
`Modifier.glass` (Android, `ui/components/Glass.kt`) ; jamais de verre dans du verre. La fiche d'un
parking n'affiche que des données réelles (pas de « type d'usagers » ni de « type d'ouvrage »).

### Écran d'intro

Les nouveautés sont présentées au premier lancement et une fois après chaque mise à jour qui change
`Intro.REVISION` (module partagé : pictogramme, titre et texte de chaque page, libellé du bouton,
règle d'affichage, testés). `IntroView.swift` sur iOS, `IntroScreen.kt` sur Android ; la page des
widgets n'existe que sur iOS. La révision vue est gardée par chaque plateforme et l'écran reste
consultable depuis l'onglet Info. Changer les textes d'une version se fait dans le module partagé,
jamais dans les vues, et augmenter la révision suffit à faire reparaître l'intro.

### Fiches horaires théoriques (GTFS)

Les horaires d'une journée entière (fiches horaires par ligne, sens et date) ne viennent pas
d'une API Grand Lyon mais du GTFS SYTRAL, découpé chaque nuit par `horaires/build_timetables.py`
(GitHub Actions, `.github/workflows/horaires.yml`) et publié sur la branche orpheline `horaires`.
Le proxy les relaie sous `/horaires/index.json` et `/horaires/lignes/<CLÉ>/<A|R>.json`.
Format et conventions (sens A/R, minutes ≥ 1440 après minuit) : `horaires/README.md`.
Logique partagée : `TimetableService` / `LineTimetable` (KMP), consommés directement par iOS
(framework `Shared` lié par la phase Xcode « Module partagé Kotlin », cf. `KMP_MIGRATION.md`).

### Lignes du réseau et renumérotations

Aucune liste de lignes embarquée : `LineRegistry` (module partagé) est rempli depuis l'index des
fiches horaires à chaque chargement (régénéré chaque nuit), et sert aux écrans d'alertes comme à la
détection du mode d'une ligne, donc à jour après une renumérotation (la 21 devenue 121 en septembre
2026) sans mise à jour de l'application. La règle sur le nom ne sert que pour une ligne inconnue de l'index.
Les filtres de lignes enregistrés sont purgés des numéros disparus (`MapFilterTexts.keepKnownLines`)
et un bandeau « Tout afficher » apparaît quand les filtres masquent tous les véhicules.

### Couleurs, textes et règles d'interface

- Toute couleur sémantique vient de `AppColors` (module partagé) : `Color.appAccent`… et les
  extensions de `AppColorTokens.swift` côté iOS, l'objet `Tokens` côté Android. Aucune couleur
  système nommée ni hexadécimale dans une vue. Les lignes utilisent `LineColors` (palette GTFS).
- L'accent Android est fixe (pas de couleur dynamique Material) ; le thème est `AlerteTCLTheme`.
- Abonnements aux notifications : `LineSubscriptions` (règles + JSON), distincts des favoris qui ne
  servent qu'aux filtres. Règle de notification : `AlertNotifications`. Bandeau trafic :
  `TrafficBanner`. Dates des alertes : `AlertDates`. Ces règles ont des tests dans `commonTest`.
- Pas de widgets Android (décision produit du 15 septembre 2026) ; les widgets iOS restent (voir « Widgets iOS »).
- Un véhicule sans nouvelle position depuis `Vehicle.HIDE_AFTER_SECONDS` (90 s, module partagé) quitte
  la carte : filtre à chaque fetch dans les vues modèles et relecture chaque seconde côté carte.
- Grille de zoom partagée `MapStyle.ZOOM_*` (niveaux MapLibre ; iOS convertit via `MapStyle.zoomLevel`) :
  tout seuil de visibilité sur la carte s'y réfère, aucune valeur de zoom en dur dans les vues.
- Marqueur véhicule : pictogramme du type dans le disque, numéro de ligne en capsule juste dessous, aucun
  indicateur de délai sur la carte (décision du 20 septembre 2026, le délai reste dans la fiche) ; état du
  trafic sur le bouton « Trafic et horaires » (`TrafficBanner.State.count`), qui ouvre une feuille à deux
  onglets (alertes, fiches horaires : `NetworkSheet` iOS, `TimetableFlow` hébergé dans la feuille Android).
  Boutons de carte en deux couleurs seulement (`MapGlassButton(active:)` / `MapCircleFab(active)`), vue
  satellite dans les filtres sur Transport, pas de capsule « LIVE ». Lignes scolaires JD exclues des
  arrêts et des passages (`TransitStop.isDisplayedLine`).
- Les composants communs sont décrits dans `DESIGN.md` : badge de ligne (`LineBadge`), en-tête de
  feuille (`SheetHeader`), états chargement / vide / erreur, textes des alertes.

### Widgets iOS

Six widgets, refaits le 20 septembre 2026 (les trois premiers gardent leurs identifiants WidgetKit, noms d'intents et de paramètres d'avant, et `WidgetStore` relit les anciens enregistrements `widgetStops` / `widgetStopsIndex` : les widgets déjà posés survivent à la mise à jour) : « Prochains passages », « Tableau de départs », « Trafic sur
mes lignes », « Places de parking », « Station Vélo'v », « Travaux autour de moi ». Le dossier
`WidgetCommon/` (dossier synchronisé Xcode, membre de l'app et de l'extension) porte le catalogue
(`WidgetKind`, `WidgetLink` pour les liens `alertetcl://`), le stockage partagé (`WidgetStore`, JSON dans
l'app group), le thème (`WidgetTheme`, jetons `AppColors` publiés par l'app ; `WidgetLinePalette` relit
la palette officielle), les entrées et les vues de chaque widget, la capture de carte des chantiers
(`WorksMapSnapshot`) et les exemples (`WidgetSamples`). L'extension `AlerteTCLWidget/` ne lie pas le
module Kotlin : ses services (`Services/`) lisent le relais et le GeoServer, ses réglages et
chronologies sont dans `Widgets/`. Règles d'affichage (21 septembre 2026) : chaque widget est un panneau, pas une fiche. Aucun titre, son
contenu dit ce qu'il montre ; un seul chiffre domine, en très gros ; la couleur vient des badges de
ligne, des bandeaux d'état et des jauges, jamais d'un voile de fond ; les tailles moyennes et grandes
remplissent leur hauteur (rangées étirées, séparateurs `WidgetRule`) plutôt que de laisser du vide ;
un temps d'attente s'écrit toujours avec la couleur du texte, jamais celle d'une ligne (une ligne
claire ne se lit pas), et un `Link` porte `.tint(.primary)` pour ne pas teindre son contenu en bleu ;
une information n'est écrite qu'une fois (pas de nombre repris dans une phrase, pas d'adresse de
station) ; les unités sont les plus courtes qui restent justes (« 702 places », « 3 élec », « 12
chantiers à 1 km », « Tout roule ») ; l'heure des données n'apparaît que si elles datent de plus d'un
quart d'heure ou que le réseau n'a pas répondu (`WidgetStamp`). Les briques communes sont
`WidgetStat` (pictogramme et chiffre), `WidgetChip`, `WidgetSegmentedBar`, `WidgetRule`, `WidgetLabel`
et `WidgetStamp`. Pour juger une mise en page sans poser les widgets : `xcrun simctl launch <simulateur>
com.solal.AlerteTCL -render-widgets` écrit `widgets-clair.png` et `widgets-sombre.png` dans les documents
de l'application (`WidgetBoardRender`, en debug seulement), avec les six widgets dans toutes leurs tailles.
Côté app, `WidgetBridge` publie arrêts, abonnements et couleurs
puis recharge les chronologies ; `WidgetViews.swift` porte la feuille « Ajouter au widget » (multi-sens),
la galerie (onglet Info, aperçus rendus avec les vraies vues) et la liste des arrêts enregistrés. Les
liens des widgets ouvrent la fiche de l'arrêt, du parking, de la station, du chantier, le trafic ou la
galerie (`WidgetLink`, routé par `ContentView`). La position des widgets exige `NSWidgetWantsLocation`
dans l'Info.plist de l'extension. L'adresse du relais est `ProxyEndpoint.baseURL` (mise à jour par
`deploy.sh`). Quand le direct annonce moins de deux passages (fin de service, nuit), `PassagesService` complète avec les fiches horaires théoriques (`TimetableService` de l'extension, lecture minimale du format 1 sur trois journées de service, quai reconnu par identifiant puis par nom) : le widget affiche alors « demain 05:12 » et « horaires prévus », et se recharge une heure avant le premier passage.
