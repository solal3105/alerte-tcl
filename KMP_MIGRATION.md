# Migration Kotlin Multiplatform — état & intégration iOS

## Statut Android

✅ Build APK : `./gradlew :androidApp:assembleDebug`
- Sortie : `androidApp/build/outputs/apk/debug/androidApp-debug.apk`
- Logique métier 100 % partagée via `:shared`
- Écrans Compose :
  - **LiveMap** : carte temps réel avec filtres, clustering, animation 100 ms,
    boutons d'action (alertes, réglages, refresh) en overlay
  - **Travaux** : carte polygones colorés
  - **Parkings** : carte avec viewport reload + ParkingViewModel
  - **À propos** : Hero, Manifesto, OpenData, Sources (5 lignes), Créateur,
    Contact LinkedIn, Liens, Version (réplique d'`AboutView.swift`)
  - **Alertes** (modale depuis LiveMap) : StatusBanner contextuel,
    section "Mes lignes" (favoris), "Toutes les alertes",
    grille "Toutes les lignes" — réplique de `NewAlertsView.swift`
  - **Lignes** (`LinesListScreen`) : grille 2 colonnes, recherche, filtre par
    mode de transport, toggle favori
  - **Sélection arrêts widget** : recherche d'arrêts + sélection multiple
  - **Settings** : permissions notif, premium, widget, données, confidentialité
- Persistance : DataStore (`FavoritesStore`) — lignes favorites, arrêts widget,
  flag premium
- Notifications : WorkManager (`AlertWorker` toutes les 30 min) +
  channel `tcl_alerts`
- Widget : Glance `NextDeparturesGlanceWidget` (prochains passages aux 2 arrêts
  favoris)
- Navigation : 4 onglets (Transport, Travaux, Parkings, Info) identiques à iOS

## Statut iOS

✅ Framework Kotlin/Native : `./gradlew :shared:linkDebugFrameworkIosSimulatorArm64`
- Sortie : `shared/build/bin/iosSimulatorArm64/debugFramework/Shared.framework`
- Tous les services (`TclApiService`, `TransitStopService`, `ParkingService`,
  `TravauxService`, `BusLineService`, `MetroLineService`, etc.) sont
  multiplateformes et exposés au binaire iOS

### Intégration dans l'Xcode existant

Pour basculer progressivement les services Swift vers le binaire partagé :

1. Ajouter une *Run Script Phase* (avant *Compile Sources*) à la cible
   `AlerteTCL` dans `AlerteTCL.xcodeproj` :
   ```bash
   cd "$SRCROOT/.."
   ./gradlew :shared:embedAndSignAppleFrameworkForXcode
   ```
2. Ajouter `${BUILT_PRODUCTS_DIR}/Shared.framework` dans
   *Frameworks, Libraries, and Embedded Content*
3. Côté Swift :
   ```swift
   import Shared

   let alerts = try await TclApiService.shared.fetchAlerts()
   ```
4. Migrer les fichiers Swift correspondants (les services peuvent être
   supprimés au fur et à mesure : `AlerteTCL/Services/AlertService.swift`,
   `TCLAPIService.swift`, `ParkingService.swift`, etc.).

## Variables d'environnement requises pour build

```bash
export JAVA_HOME=~/jdks/jdk-17.0.12.jdk/Contents/Home
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$JAVA_HOME/bin:$PATH
```

## Clé API Maps

L'app Android lit `MAPS_API_KEY` depuis :
- propriété Gradle (`-PMAPS_API_KEY=...`)
- variable d'environnement (`MAPS_API_KEY=...`)
- (sinon valeur vide → pas de carte rendue)

## Branche

`kmp-migration` (à fusionner dans `main` après tests sur device).
