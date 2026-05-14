# Android — Backlog

---

## 1. Filtres véhicules — non iso iOS

**Cause racine :** Le `FilterSheet` Android (`LiveMapScreen.kt`) ne contient qu'une rangée de `FilterChip` par `VehicleType` et un `Switch` pour les tracés. Il manque toute la section "lignes".

**Ce qu'a iOS en plus :**
- Section "Toutes les lignes" : multi-sélect par ligne avec barre de recherche et section favoris (étoilées en haut via `FavoriteLinesService`)
- Sélection de type de véhicule en mode radio (un seul type OU "tous") avec badge de comptage
- Persistance dans `UserDefaults` (`PersistenceKey.selectedVehicleType` + `PersistenceKey.selectedLines`)

**Important :** iOS gère tout ça dans son propre `LiveVehiclesViewModel.swift` (indépendant du KMP). **Aucun changement dans le module KMP partagé** — tout se fait côté Android uniquement.

**Ce qu'il faut faire :**
- Créer un Android-only `LiveMapFilterState` (ou thin ViewModel Android) qui gère `selectedLines: Set<String>` et `availableLines: List<String>` en dehors du KMP VM
- Construire la section "lignes" dans `FilterSheet` avec search + section favoris
- Intégrer `FavoriteLinesService.shared` (KMP, déjà existant) pour la persistance des favoris de lignes
- Persister `selectedTypes` et `selectedLines` via DataStore (Android-only) — comme iOS le fait avec `UserDefaults`

---

## 2. Flèche de direction désalignée du marker véhicule

**Cause racine :** `LiveMapScreen.kt`, layer `vehicles-arrow-layer` :
```kotlin
PropertyFactory.iconOffset(arrayOf(0f, -28f))
```
`iconOffset` est appliqué en espace écran **avant** `iconRotate`. L'offset `[0, -28]` déplace toujours la flèche de 28dp vers le nord, quelle que soit la direction du véhicule. La rotation fait ensuite tourner la flèche sur place, mais elle reste perpétuellement décalée nord.

**Ce qu'il faut faire :**
- Injecter un vecteur d'offset dynamique `(r·sin θ, −r·cos θ)` en propriété GeoJSON de chaque feature véhicule
- Lire cet offset via `PropertyFactory.iconOffset(Expression.get("arrowOffset"))` dans le layer
- Calculer ce vecteur dans `LiveVehiclesViewModel` ou lors de la construction du GeoJSON source, avec un rayon ≈ 19–20dp (comme sur iOS : `orbit = 19pt`)

---

## 3. Filtre "Métro" affiché sans marker métro

**Cause racine (double) :**

**a) Donnée :** L'API SIRI TCL ne publie pas les positions des métros (automatiques/sans conducteur). Aucun véhicule `METRO` ne sera jamais retourné par `/vehicles`. Le filtre est fonctionnellement mort.

**b) Code :** `LiveMapScreen.kt`, `FilterSheet` itère `VehicleType.entries` sans condition :
```kotlin
VehicleType.entries.sortedBy { it.sortOrder }.forEach { type ->
    FilterChip(selected = type in selectedTypes, ...)
}
```
Aucun badge de comptage, aucune garde de visibilité → chip active mais retournant toujours zéro résultat.

**Ce qu'il faut faire :**
- Masquer les `FilterChip` dont le count de véhicules correspondants est 0 (ou griser avec badge "0" explicite comme iOS)
- En pratique : supprimer `METRO` de l'enum ou exclure les types sans véhicules du rendu des chips

---

## 4. Clic sur marker véhicule — ID d'arrêt affiché au lieu du nom

**Cause racine :** Dans `SiriLiteService.kt` le callback de résolution de nom est déclaré mais jamais branché côté Android :
```kotlin
var stopNameLookup: (String) -> String? = { null }  // jamais assigné sur Android
```
`extractStopName()` tombe donc toujours sur le fallback `numericId` (ex. `"39975"`). `StopInfo.stopName` reçoit l'ID brut, non null, et `LiveMapScreen.kt` affiche `ns.stopName ?: ns.stopRef` — l'ID est affiché.

**iOS** charge `tcl_stops.json` à l'initialisation du type et résout l'ID directement dans un `Dictionary<String, String>`.

**Ce qu'il faut faire :**
- Dans `AlerteTCLApplication.onCreate()`, assigner :
  ```kotlin
  SiriLiteService.shared.stopNameLookup = { id -> /* parse tcl_stops.json une fois via BundledResources, lookup par id */ }
  ```
- Vérifier que `tcl_stops.json` est bien présent dans `androidApp/src/main/assets/` (sinon le copier depuis `AlerteTCL/Resources/`)

---

## 5. Markers parking non fidèles au design iOS

**Cause racine principale :** taille hardcodée en pixels sans tenir compte de la densité d'écran :
```kotlin
// ParkingScreen.kt
val s = 36  // px bruts — au lieu de (36 * density).toInt()
val s = 60  // px bruts — au lieu de (60 * density).toInt()
```
Sur un écran 3× (ex. Pixel 7 Pro) les markers font ≈ 17–20dp au lieu de 44pt comme sur iOS.

**Autres divergences vs iOS `ParkingMarker`:**

| Élément | iOS | Android |
|---|---|---|
| Diamètre full marker | 44pt | ~17–20dp (densité ignorée) |
| Icône voiture | SF Symbol `car.fill` | Texte `"P"` |
| Ombre | `shadow(radius:6, opacity:0.4)` | Absente |
| Badge dispo (position) | `offset(x:16, y:-16)` en pt | `(s-10f, 10f)` en px bruts |
| Taille du texte | 9–10pt auto-scaled | 13–14f px hardcodés |

**Ce qu'il faut faire :**
- Multiplier toutes les dimensions par `context.resources.displayMetrics.density`
- Ajouter une ombre via `Paint.setShadowLayer`
- Remplacer le texte `"P"` par une icône vectorielle de voiture
- Recalculer la position du badge de disponibilité en dp

---

## 6. Données live TCL parkings manquantes (Parc-Relais)

**Cause racine :** Le KMP `ParkingViewModel` merge les P+R dans la même liste plate `_parkings` sans déduplication :
```kotlin
val all = listOfNotNull(carsAsync?.await(), ..., prAsync?.await()).flatten()
_parkings.value = all
```
Un P+R présent à la fois dans l'API standard parkings et dans l'API P+R génère **deux markers superposés**, le marker standard (sans donnée temps réel) masquant le marker P+R (avec occupancy live).

**iOS** maintient deux propriétés séparées (`parkings` + `parcRelais`) et filtre les P+R par déduplication sur le nom avant de les afficher sur une `ForEach` distincte.

**Important :** iOS gère `parcRelais` dans son propre `ParkingViewModel.swift` (indépendant du KMP). Le KMP `ParkingViewModel` ne sera pas modifié.

**Ce qu'il faut faire (Android-only) :**
- Dans `ParkingScreen.kt`, appeler `ParcRelaisService.shared.fetchParcRelais()` directement en parallèle du KMP VM (via `LaunchedEffect`)
- Maintenir un état local `parcRelais: List<Parking>` dans le composable, séparé du `parkings` du KMP VM
- Appliquer la déduplication par nom contre `parkings` avant d'afficher (même logique que iOS)
- Rendre les P+R depuis cet état local sur un layer/source GeoJSON dédié

---

## 7. Page Info — non iso iOS et ordre des sections incorrect

**Cause racine :** Deux divergences dans `AboutScreen.kt` vs `AboutView.swift` :

**a) Carte manquante — `openProjetsCard`**
Sur iOS, une carte promotionnelle "Open Projets by Vazy" (dégradé bleu→violet, logo, pitch, 2 liens CTA) est insérée entre `creatorCard` et `openDataTribute`. Cette carte est absente d'Android.

**b) Ordre des sections incorrect**

| Position | iOS | Android actuel |
|---|---|---|
| 1 | Hero | Hero |
| 2 | Manifesto | Manifesto |
| 3 | Creator | **OpenDataTribute** ← décalé |
| 4 | **OpenProjets** ← manquant | **SourcesCard** ← décalé |
| 5 | OpenDataTribute | Creator |
| 6 | Sources | Contact |
| 7 | Contact | Links footer |
| 8 | Links footer | Version footer |
| 9 | Version footer | |

**Ce qu'il faut faire :**
- Ajouter la `OpenProjetsCard` (Material You : `Card` avec `Brush` dégradé + `AsyncImage` via Coil, deux `TextButton`)
- Réordonner les sections pour matcher iOS : Hero → Manifesto → Creator → OpenProjets → OpenDataTribute → Sources → Contact → Links → Version
