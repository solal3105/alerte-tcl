# Module partagé Kotlin Multiplatform : état et intégration iOS

## Ce qui est partagé aujourd'hui

Le module `:shared` contient les modèles, les services réseau (Ktor), les règles métier et les
ViewModels. Android le consomme par dépendance Gradle. iOS le consomme comme framework
`Shared.framework`, produit à chaque compilation Xcode par la phase « Module partagé Kotlin »
(première phase de la cible `AlerteTCL`) qui lance `:shared:embedAndSignAppleFrameworkForXcode`.
Le framework est cherché dans `shared/build/xcode-frameworks/$(CONFIGURATION)/$(SDK_NAME)` et lié
statiquement (`-framework Shared`). Le widget iOS reste en Swift seul (il lit la palette des lignes
depuis le conteneur partagé, clé `linePalette`).

Logique que Swift ne duplique plus (les fichiers Swift correspondants ont été supprimés) :

- fiches horaires : `TimetableService`, `LineTimetable`, `TimetableTime`, `TimetableIndex` ;
- couleurs : `LinePalette`, `LineColors`, `AppColors` (jetons, voir `DESIGN.md`) ;
- sens et rapprochement des noms : `DirectionMatching`, `LineTermini`, `StopLineFocus` ;
- abonnements aux notifications : `LineSubscription`, `LineSubscriptions` (règles et format JSON,
  clé `lineSubscriptions` sur iOS, `line_subscriptions` sur Android) ;
- notifications : `AlertNotifications` (premier passage silencieux, une notification par phase,
  purge des clés vues, titres) ;
- bandeau trafic : `TrafficBanner` ; dates des alertes : `AlertDates`.

Ces règles sont couvertes par les tests de `shared/src/commonTest` (`./gradlew :shared:testDebugUnitTest`).

## Ce qui reste en Swift

Les modèles réseau et services iOS historiques (`TCLAlert`, `TransportLine`, `Vehicle`, `Parking`,
`Travaux` et leurs services) existent encore en Swift, avec des passerelles vers leurs jumeaux Kotlin
(`AppColorTokens.swift` : `.shared` sur chaque énumération, `TCLAlert.shared`, `TransportLine.shared`).
Ordre de migration conseillé : services réseau (un seul client, un seul jeu de DTO), puis
ViewModels (un mince `ObservableObject` par écran qui observe les `StateFlow`), puis persistance
par `expect/actual`. Chaque migration supprime le fichier Swift correspondant et s'appuie sur un test
Kotlin.

## Conventions d'interopérabilité

- Les fonctions `suspend` exposées à Swift portent `@Throws(Exception::class)` pour devenir
  `async throws` ; sans cette annotation, une exception Kotlin fait planter l'application.
- Les surcharges par type ne passent pas en Objective-C : donner des noms distincts
  (`stopIndexesForIds`, `findForStopIds`).
- `List<Int>` devient `[KotlinInt]` ; `Int` Kotlin devient `Int32` ; `Long?` devient `KotlinLong?`.
- Les objets Kotlin se lisent par `.shared` (`LineColors.shared`), les compagnons par
  `.companion.shared`, les classes imbriquées avec le nom du parent en préfixe
  (`TrafficBanner.State` devient `TrafficBannerState`).
- Quand Swift et Kotlin ont un type du même nom, le type Swift l'emporte dans l'application ;
  écrire `Shared.TransportMode` pour le type Kotlin.

## Environnement de compilation

```bash
export JAVA_HOME=~/jdks/jdk-17.0.12.jdk/Contents/Home
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$JAVA_HOME/bin:$PATH
```

Le dépôt vit dans un dossier synchronisé iCloud : la synchronisation dépose des doublons
(`fichier 2.dex`) dans `androidApp/build` et `shared/build` qui font échouer le dexing. Avant de
compiler Android, supprimer ces doublons (`find androidApp/build shared/build -name "* [0-9].*" -delete`)
ou, mieux, sortir le projet d'iCloud.

## Clé Maps Android

L'application Android lit `MAPS_API_KEY` depuis une propriété Gradle (`-PMAPS_API_KEY=...`) ou une
variable d'environnement ; sans clé, la carte n'est pas rendue.

## Xcode Cloud

Les machines Xcode Cloud n'ont ni JDK ni SDK Android, et `local.properties` n'est pas versionné :
la phase de build « Module partagé Kotlin » échouait donc sur `PhaseScriptExecution`. Le script
`ci_scripts/ci_post_clone.sh`, exécuté par Xcode Cloud juste après le clone, installe le JDK 17.0.12
dans `~/jdks` (le chemin que la phase essaie en premier), les outils en ligne de commande Android
avec la plateforme 35 et les build-tools 35.0.0, puis écrit `local.properties`.

Chaque build télécharge ces outils, le distributable Gradle et le compilateur Kotlin/Native, ce qui
ajoute plusieurs minutes avant la première ligne compilée : Xcode Cloud ne conserve pas de cache
entre deux builds pour `~/.gradle` et `~/.konan`.
