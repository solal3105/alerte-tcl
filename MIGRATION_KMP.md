# Migration Kotlin Multiplatform — État d'avancement

Branche : `kmp-migration`

## Vue d'ensemble

Ce document décrit la migration du code de l'app iOS Swift `AlerteTCL` vers
Kotlin Multiplatform pour permettre un déploiement Android natif via Jetpack
Compose tout en partageant la totalité de la logique métier avec iOS.

```
alerte-tcl/
├── shared/              ← module Kotlin Multiplatform (commonMain + androidMain + iosMain)
├── androidApp/          ← app Android Compose
├── AlerteTCL/           ← app iOS Swift (existante, intacte)
├── AlerteTCL.xcodeproj/ ← projet Xcode (existant, intact)
└── cloudflare-worker/   ← proxy déjà déployé (intact)
```

## Phases de migration

### ✅ Phase 0 — Scaffolding Gradle/KMP

- `build.gradle.kts` racine
- `settings.gradle.kts` avec inclusion `:shared` + `:androidApp`
- `gradle.properties` (parallel + caching + configuration-cache)
- `gradle/libs.versions.toml` (catalog des versions)
- `shared/build.gradle.kts` configuré (Android + iosX64 + iosArm64 + iosSimulatorArm64)
- Gradle wrapper 8.10.2 (`gradlew`, `gradlew.bat`, jar)

### ✅ Phase 1 — Modèles & services partagés (shared/commonMain)

Tous les modèles Swift sont portés en Kotlin avec `@Serializable` :

**Modèles** :
- `geo.LatLng` (équivalent CLLocationCoordinate2D + GeoRegion)
- `models.Alert` (TCLAlert + AlertSeverity)
- `models.Vehicle` (Vehicle, StopInfo, VehicleType)
- `models.Parking` (Parking unifié + ParkingState + ParkingType + AvailabilityColor)
- `models.Travaux` (+ TravauxNatureChantier, TravauxType, TravauxAvancement, TravauxImportance, TravauxPerturbation)
- `models.TransitStop` (+ Passage + MergedStop)
- `models.BusLine` / `models.TransitLine`
- `models.TransportMode` / `models.TransportLine` / `models.LineColors`
- `models.AnimatedVehicle` (interpolation easeOutQuad pure logic, indépendante UI)
- `models.UnifiedCluster` (Clusterable + MapCluster + ClusteringEngine)

**Services Ktor** :
- `services.TclApiService` — alertes (proxy `/alerts`)
- `services.SiriLiteService` — véhicules SIRI Lite (proxy `/vehicles`)
- `services.ParkingService` — parkings (cars/bikes/moto) avec cache spatial
- `services.ParcRelaisService` — P+R (statique 24h + temps réel 60s)
- `services.TravauxService` — chantiers GeoServer
- `services.TransitStopService` — arrêts + passages
- `services.BusLineService` / `services.TransitLineService` — tracés

**Utilitaires** :
- `util.AppLogger`
- `util.SpatialTileCache` (mutex + Clock kotlinx-datetime)
- `util.ViewportFilter` + `easeOutQuad`
- `util.DateParsing` (ISO 8601, `yyyy-MM-dd HH:mm:ss`, durées ISO)
- `util.parseDurationSeconds` (PT5M30S → secondes)

**Réseau** :
- `network.HttpClientProvider` (Ktor singleton avec engines OkHttp/Darwin)
- `network.NetworkConfiguration` (proxyBaseURL, timeouts)
- `network.ApiError` (sealed)

**ViewModels** (StateFlow) :
- `viewmodels.AlertsViewModel` (polling 60s)
- `viewmodels.LiveVehiclesViewModel` (polling 15s + animation)
- `viewmodels.ParkingViewModel`
- `viewmodels.TravauxViewModel`
- `viewmodels.TransitStopsViewModel`

**Bundle resources** :
- `platform.BundledResources.loader` (registry, configuré au démarrage)
- `platform.AndroidBundleSetup` (assets/ Android)
- `platform.IosBundleSetup` (NSBundle iOS)

### 🟡 Phase 2 — App Android Compose (squelette en place)

`androidApp/` contient :
- `AlerteTCLApplication.kt` (init bundle resources)
- `MainActivity.kt`
- `ui.AlerteTCLApp` — Scaffold avec NavigationBar 5 onglets
- `ui.alerts.AlertsScreen` — liste des alertes (✅ fonctionnel, polling automatique)
- `ui.live.LiveMapScreen` — Google Maps + markers véhicules (✅ basique)
- `ui.parking.ParkingScreen` — placeholder
- `ui.travaux.TravauxScreen` — placeholder
- `ui.settings.SettingsScreen` — placeholder
- `ui.colorFromHex` (conversion hex → Compose Color)

### ⏳ Phase 3 — Reste à implémenter pour parité fonctionnelle iOS

À faire en priorité :

1. **Carte temps réel avancée** (`LiveMapScreen`) :
   - Filtrage par mode (métro / tram / bus / trolley / funi)
   - Marqueurs custom par mode (icônes + couleurs ligne)
   - Animation des véhicules : `AnimatedVehicle` côté shared est prêt — il faut
     un composable `MapEffect` qui à chaque frame interroge `currentInterpolatedCoordinate`
   - Tap sur véhicule → bottom sheet avec ligne / destination / délai / prochain arrêt
   - Affichage des tracés (lignes via `BusLineService` / `TransitLineService`)
   - Affichage des arrêts (depuis `TransitStopService`) avec clustering

2. **Carte parkings** (`ParkingScreen`) :
   - Toggle CAR/BIKE/MOTORIZED_2W/Parc Relais
   - Marqueurs colorés selon `Parking.availabilityColor`
   - Détail bottom sheet (capacité, places dispo, horaires P+R)

3. **Carte travaux** (`TravauxScreen`) :
   - Polygones colorés selon `TravauxImportance`
   - Détail bottom sheet (nature, intervenant, dates, % complétion)

4. **Liste lignes** (équivalent `LinesListView`) :
   - Filtrage par mode
   - Détail ligne → carte + arrêts + alertes

5. **Détail arrêt** (équivalent `TransitStopDetailView`) :
   - Liste des passages temps réel
   - Favori (boutons + persistence DataStore)

6. **Réglages** (`SettingsScreen`) :
   - Notifications (FCM token enregistrement)
   - Permission localisation
   - Souscription premium
   - À propos

7. **Widgets Glance** (équivalent `AlerteTCLWidget`) :
   - `NextDeparturesWidget` : 1 arrêt favori → prochains passages
   - `ConfigureWidgetActivity` (sélection arrêt depuis stops du shared)

8. **Notifications** :
   - WorkManager job qui appelle `AlertsViewModel.refresh()` toutes les 30 min
   - Notification pour alerte concernant ligne favorite
   - FCM fallback (push depuis backend si jamais on en ajoute)

9. **In-App Purchases** :
   - Google Play Billing (équivalent du `SubscriptionService` StoreKit)
   - Produit `premium_monthly` / `premium_yearly`

### ⏳ Phase 4 — Intégration iOS du framework Kotlin

L'app iOS Swift peut consommer `shared` comme XCFramework :

```bash
./gradlew :shared:embedAndSignAppleFrameworkForXcode
```

Étapes Xcode :
1. Project → Build Phases → ajouter un Run Script :
   ```
   cd "$SRCROOT/.."
   ./gradlew :shared:embedAndSignAppleFrameworkForXcode
   ```
2. Linker `Shared.framework`
3. Remplacer progressivement les services Swift par le binding `Shared.SiriLiteService.shared.fetchVehicles { ... }` etc.

Ceci est **optionnel** : Phase 4 peut être différée — l'app iOS continue à fonctionner avec son code Swift d'origine sans modification.

## Pré-requis pour build local

L'environnement local n'a pas de JDK ni Android SDK installé. Pour compiler :

```bash
# 1. JDK 17 (requis par Gradle 8 + AGP 8.5)
brew install --cask temurin@17

# 2. Android Studio (inclut le SDK Android + emulator + Java embarqué)
brew install --cask android-studio

# Ou Android command-line tools seules :
brew install --cask android-commandlinetools
sdkmanager "platforms;android-34" "build-tools;34.0.0" "platform-tools"

# 3. Variable d'environnement
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools

# 4. Compiler le module shared
./gradlew :shared:assemble

# 5. Installer l'app Android sur un device/emulator
./gradlew :androidApp:installDebug
```

Pour Google Maps, il faut une clé API Android dans `~/.gradle/gradle.properties` :
```
MAPS_API_KEY=AIza...
```

## Branchement Cloudflare Worker

Le proxy `https://tcl-proxy.solalgendrin.workers.dev` est commun aux deux apps.
Aucune configuration supplémentaire requise — la constante `NetworkConfiguration.PROXY_BASE_URL`
côté Kotlin pointe au même endpoint que `NetworkConfiguration.proxyBaseURL` côté Swift.

## Checklist commit

- [x] Modèles communs portés (10 fichiers)
- [x] Services Ktor (8 services)
- [x] ViewModels avec StateFlow (5)
- [x] Squelette d'app Android Compose (5 onglets)
- [x] Gradle wrapper 8.10.2
- [ ] Compilation testée (nécessite JDK 17 + Android SDK)
- [ ] Phase 3 : écrans détail / carte avancée / widgets / notifications / IAP
- [ ] Phase 4 : intégration `Shared.framework` dans Xcode (optionnel)
