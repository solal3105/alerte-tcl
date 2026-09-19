# Lyon Pocket

Les transports lyonnais en direct sur la carte : positions des véhicules TCL en temps réel, prochains
passages à chaque arrêt, fiches horaires théoriques, alertes trafic avec notifications, travaux et
parkings. Une application iOS (SwiftUI) et une application Android (Jetpack Compose) qui partagent la
même logique métier en Kotlin Multiplatform.

Code ouvert, librement auditable et gratuit. Application indépendante, sans affiliation à SYTRAL
Mobilités, Keolis Lyon ou TCL.

## Ce que fait l'application

- **Transport** : carte temps réel des métros, tramways, trolleybus, bus et navette fluviale ; fiche d'un
  véhicule (retard, fraîcheur de la position, prochain arrêt) ; fiche d'un arrêt avec les prochains
  passages estimés et théoriques et, pour chaque ligne, « où est mon bus » (à combien d'arrêts se
  trouve chaque véhicule qui vient, heure d'arrivée estimée, âge de la position) ; filtre « Voir ces bus
  sur la carte » depuis un arrêt ; fiches horaires théoriques (ligne,
  sens, arrêt, date) ; filtres par type de véhicule et par ligne ; bandeau trafic ; stations Vélo'v avec
  les vélos et places disponibles.
- **Alertes** : perturbations du réseau, abonnement à des lignes avec choix des types d'alertes
  notifiées.
- **Autour de moi** : un accueil à tuiles, sur la carte de la ville, vers les parkings voiture et parcs
  relais en temps réel, les stations Vélo'v, les arceaux vélos, les places deux-roues motorisés et les
  chantiers, avec leurs chiffres du moment.
- **Widgets** (iOS seulement) : prochains passages, panneau d'affichage et parking sur l'écran d'accueil.
- **Notifications** : abonnement par ligne, avec le choix des types d'alertes, sur les deux plateformes.

## Architecture

```
shared/            Logique métier Kotlin Multiplatform : modèles, services réseau, ViewModels,
                   couleurs de lignes, fiches horaires, tests (commonTest)
AlerteTCL/         Application iOS (SwiftUI, MapKit) : lie le framework Kotlin `Shared`
AlerteTCLWidget/   Extension widgets iOS (Swift seul, sans le module Kotlin)
androidApp/        Application Android (Jetpack Compose, MapLibre)
cloudflare-worker/ Proxy Cloudflare : détient les identifiants Grand Lyon, met en cache les flux
horaires/          Construction nocturne des fiches horaires à partir du GTFS SYTRAL
.github/workflows/ Intégration continue (tests, compilation iOS et Android) et publication des horaires
website/           Site vitrine (Netlify)
```

Le module `shared` est compilé en bibliothèque Android et en framework Kotlin/Native pour iOS ; le
projet Xcode le construit automatiquement à chaque compilation (phase « Module partagé Kotlin »). Les
règles de développement sont dans `CLAUDE.md`, l'état de la migration iOS dans `KMP_MIGRATION.md`,
l'audit de cohérence dans `AUDIT_COHERENCE.md`, les fiches horaires dans `horaires/README.md`.

## Données

Toutes les données viennent des données ouvertes du Grand Lyon et de SYTRAL Mobilités (licence
ouverte / ODbL) : flux SIRI Lite (positions temps réel), prochains passages, alertes trafic, GeoServer
(arrêts, tracés, parkings), GTFS (horaires théoriques et couleurs officielles des lignes). Les
applications n'appellent jamais ces services directement : le proxy Cloudflare (`cloudflare-worker/`)
porte les identifiants et lisse la charge.

## Compiler

Prérequis : Xcode 15 ou plus récent, un JDK 17 et le SDK Android (chemins dans `local.properties`).
Le projet ne doit pas vivre dans un dossier synchronisé par iCloud Drive : la synchronisation crée des
doublons dans les dossiers de compilation Gradle et fait échouer le dexing.

```bash
# Tests du module partagé et application Android
./gradlew :shared:testDebugUnitTest :androidApp:assembleDebug

# Application iOS (le framework Kotlin est construit par Xcode)
xcodebuild -project AlerteTCL.xcodeproj -scheme AlerteTCL \
  -destination "generic/platform=iOS Simulator" -configuration Debug build
```

Le script `run.sh` lance l'émulateur Android et installe l'application. Le proxy se déploie avec
`bash cloudflare-worker/deploy.sh`.

## Captures d'écran et modes démo

Les deux applications acceptent un mode démo qui provoque un état précis de l'interface, pour les
captures et la revue visuelle : `-demo <cas>` en argument de lancement sur iOS,
`adb shell am start -n com.alertetcl.android/.MainActivity --es demo <cas>` sur Android. Les cas sont
listés dans `DemoShowcase` et les captures de référence dans `captures-tests/`.

## Licence

Code ouvert, usage personnel bienvenu sans restriction (voir `LICENSE`).
