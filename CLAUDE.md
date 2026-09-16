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
aux champs affichés, cache 60 s. Modèle `VelovStation`, service `VelovService`, couche de carte activée
depuis les filtres (réglage persisté), même seuil de zoom que les arrêts.

### Fiches horaires théoriques (GTFS)

Les horaires d'une journée entière (fiches horaires par ligne, sens et date) ne viennent pas
d'une API Grand Lyon mais du GTFS SYTRAL, découpé chaque nuit par `horaires/build_timetables.py`
(GitHub Actions, `.github/workflows/horaires.yml`) et publié sur la branche orpheline `horaires`.
Le proxy les relaie sous `/horaires/index.json` et `/horaires/lignes/<CLÉ>/<A|R>.json`.
Format et conventions (sens A/R, minutes ≥ 1440 après minuit) : `horaires/README.md`.
Logique partagée : `TimetableService` / `LineTimetable` (KMP), consommés directement par iOS
(framework `Shared` lié par la phase Xcode « Module partagé Kotlin », cf. `KMP_MIGRATION.md`).

### Couleurs, textes et règles d'interface

- Toute couleur sémantique vient de `AppColors` (module partagé) : `Color.appAccent`… et les
  extensions de `AppColorTokens.swift` côté iOS, l'objet `Tokens` côté Android. Aucune couleur
  système nommée ni hexadécimale dans une vue. Les lignes utilisent `LineColors` (palette GTFS).
- L'accent Android est fixe (pas de couleur dynamique Material) ; le thème est `AlerteTCLTheme`.
- Abonnements aux notifications : `LineSubscriptions` (règles + JSON), distincts des favoris qui ne
  servent qu'aux filtres. Règle de notification : `AlertNotifications`. Bandeau trafic :
  `TrafficBanner`. Dates des alertes : `AlertDates`. Ces règles ont des tests dans `commonTest`.
- Pas de widgets Android (décision produit du 15 septembre 2026) ; les widgets iOS restent.
- Un véhicule sans nouvelle position depuis `Vehicle.HIDE_AFTER_SECONDS` (90 s, module partagé) quitte
  la carte : filtre à chaque fetch dans les vues modèles et relecture chaque seconde côté carte.
- Les composants communs sont décrits dans `DESIGN.md` : badge de ligne (`LineBadge`), en-tête de
  feuille (`SheetHeader`), états chargement / vide / erreur, textes des alertes.
