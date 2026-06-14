# CLAUDE.md — Règles de développement AlerteTCL

Ce fichier s'applique à toutes les modifications du projet, par tout agent ou développeur.

---

## Architecture cible

### Backend partagé — Kotlin Multiplatform (KMP)

Toute la logique métier **doit vivre dans `:shared`** (module KMP) et être partagée entre iOS et Android :

- Services réseau, parsing, modèles de données, ViewModels
- Aucun code métier dupliqué entre `AlerteTCL/` et `androidApp/`
- Le module `:shared` expose les APIs via `Shared.framework` (iOS) et directement via dépendance Gradle (Android)
- Migration iOS documentée dans `KMP_MIGRATION.md`

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
