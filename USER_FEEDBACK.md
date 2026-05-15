# Retours utilisateurs

---

## Android (et iOS)

### 0. Ligne 66 manquante dans la liste des lignes

**Symptôme :** La ligne 66 n'apparaît pas dans la liste des lignes sur Android (et vraisemblablement sur iOS également).

**Localisation :**
- `shared/src/commonMain/kotlin/com/alertetcl/shared/services/LineServices.kt` — `BusLineService`
  - L'URL de fetch filtre **uniquement les lignes commençant par `C`** : `filter=ligne+LIKE+%27C%25%27`
  - La ligne 66 commence par un chiffre → exclue.
- `AlerteTCL/Services/BusLineService.swift` — même filtre : `"ligne LIKE 'C%'"`
- `AlerteTCL/Resources/tcl_transit_lines.json` — contient uniquement Métro / Tram / Funiculaire / RX (lignes tracées), pas les bus numérotés.

**Note :** Les **véhicules** de la ligne 66 sont bien présents sur la carte (le `SiriLiteService` ne filtre pas par ligne), c'est uniquement dans la **liste des lignes** que le 66 est absent.

**Piste :** Élargir le filtre API pour inclure les lignes numériques, ou ajouter un second appel `ligne LIKE '[0-9]%'` à fusionner avec les résultats existants.

---

### Exhaustivité des véhicules SIRI — Analyse de la chaîne complète

**Question : reçoit-on bien TOUS les véhicules de l'API ?**

Chaîne : `API Grand Lyon → Cloudflare Worker → App (iOS / Android)`

**1. Cloudflare Worker** (`cloudflare-worker/worker.js`)
- URL upstream : `siri-lite/2.0/vehicle-monitoring.json?MaximumVehicles=2000`
- Le parc TCL est d'environ ~800 véhicules en heure de pointe → le plafond de 2000 est largement suffisant en conditions normales.
- ✅ Aucun filtrage par ligne dans le worker — tous les véhicules sont transmis.
- ⚠️ TTL du cache stale-while-revalidate : **15 secondes**. Contribue au retard total (voir bug n°5 iOS).

**2. iOS — `SIRILiteService.swift`**
- Aucun filtrage par ligne dans `parseVehicleData`.
- Vérifie le flag `MoreData == true` (indique une troncature côté API Grand Lyon) : logge un warning en debug.
- ✅ Tous les véhicules reçus sont mappés.
- ⚠️ Si Grand Lyon tronquait la réponse malgré `MaximumVehicles=2000`, l'app iOS le détecterait en debug mais **ne le signalerait pas à l'utilisateur**.

**3. Android/KMP — `shared/.../network/dto/Dtos.kt` + `SiriLiteService.kt`**
- Aucun filtrage par ligne.
- ✅ Tous les véhicules reçus sont mappés.
- ✅ **Corrigé** — `MoreData: Boolean? = null` ajouté à `VehicleMonitoringDelivery`. `SiriLiteService.parseVehicles()` logue désormais un warning `AppLogger.warn` si `MoreData == true`.

**Conclusion :** En pratique les véhicules ne sont pas tronqués (2000 >> 800), mais il manque un filet de sécurité côté Android. ✅ **Corrigé** — `MoreData` désormais présent dans le DTO KMP, warning loggé si `true`.

---

## Prochain arrêt au clic sur un véhicule — Affichage d'un arrêt déjà passé

**Symptôme :** En cliquant sur un véhicule, le champ "prochain arrêt" affiche parfois un arrêt qui se trouve derrière le bus (déjà desservi).

### Origine dans la donnée SIRI

Le champ `MonitoredCall` de l'API SIRI-Lite Grand Lyon décrit le **dernier arrêt surveillé** (*most recently monitored call*), pas nécessairement le *prochain* arrêt futur. Concrètement, après que le bus a quitté l'arrêt X et progresse vers Y, Grand Lyon continue de publier X dans `MonitoredCall` jusqu'à ce que le bus soit suffisamment proche de Y pour que le système déclenche une mise à jour. Cette fenêtre peut durer **plusieurs minutes** selon la fréquence de localisation du véhicule et la distance entre deux arrêts.

La norme SIRI prévoit deux champs pour qualifier cet état :

| Champ                  | Valeur indiquant que l'arrêt est déjà passé |
|------------------------|---------------------------------------------|
| `DepartureStatus`      | `"departed"` |
| `ActualDepartureTime`  | Horodatage ISO8601 dans le passé |
| `ArrivalStatus`        | `"arrived"` (bus est passé mais n'a pas encore de prochain arrêt) |

### Pourquoi l'app n'en est pas consciente

**iOS** (`AlerteTCL/Models/Vehicle.swift` + `AlerteTCL/Services/SIRILiteService.swift`) :
- `MonitoredCall` struct décode correctement `ArrivalStatus`, `DepartureStatus`, `ActualArrivalTime`, `ActualDepartureTime`.
- `parseMonitoredCall()` **ignore complètement ces champs** — il extrait uniquement `StopPointRef`, `AimedArrivalTime`, `AimedDepartureTime`, `DistanceFromStop`, `Order`, et retourne le `StopInfo` tel quel sans vérifier si l'arrêt est déjà passé.
- `StopInfo.timeUntilArrival` (calculé depuis `aimedArrivalTime`) peut retourner une valeur **négative** (arrêt dans le passé), mais ce signal n'est pas exploité côté affichage.

**Android/KMP** (`shared/.../network/dto/Dtos.kt` + `SiriLiteService.kt`) :
- `MonitoredCallDto` ne modélise pas `ArrivalStatus`, `DepartureStatus`, `ActualArrivalTime`, `ActualDepartureTime` — ces champs sont silencieusement ignorés à la désérialisation.
- `parseMonitoredCall()` présente le même problème qu'iOS.

### Scénario exact déclenchant le bug

```
T+0   Bus quitte l'arrêt Bellecour     → API publie MonitoredCall = Bellecour, DepartureStatus = "departed"
T+0   → App affiche "Prochain : Bellecour" ❌  (arrêt déjà quitté)
T+90s Bus s'approche de Place Guichard → API met à jour MonitoredCall = Place Guichard
T+90s → App affiche "Prochain : Place Guichard" ✅
```

Le délai T+0 → T+90s (variable selon les lignes) est la fenêtre durant laquelle l'arrêt affiché est faux.

**Fichiers concernés :**
- `AlerteTCL/Services/SIRILiteService.swift` — `parseMonitoredCall()` : vérifier `DepartureStatus != "departed"` et `aimedDepartureTime > now`
- `AlerteTCL/Models/Vehicle.swift` — `StopInfo.timeUntilArrival` : signal disponible, non utilisé
- `shared/src/commonMain/kotlin/com/alertetcl/shared/network/dto/Dtos.kt` — `MonitoredCallDto` : manque `ArrivalStatus`, `DepartureStatus`, `ActualDepartureTime`
- `shared/src/commonMain/kotlin/com/alertetcl/shared/services/SiriLiteService.kt` — `parseMonitoredCall()` : même lacune qu'iOS — Bouton "Activer la localisation" croppé sur petits écrans

**Symptôme :** Le bouton bleu d'action est coupé en bas de l'écran sur les appareils avec peu de hauteur disponible.

**Localisation :** `androidApp/.../ui/onboarding/LocationPermissionView.kt` — `Column` racine sans `verticalScroll`, Spacers fixes qui débordent sur petits écrans.

**✅ Corrigé** — Ajout de `fillMaxSize()` + `verticalScroll(rememberScrollState())` sur la `Column` racine.

---

### 2. Géolocalisation — Indicateur de position utilisateur absent

**Symptôme :** L'utilisateur ne voit pas sa position sur la carte.

**Localisation :** `androidApp/.../ui/live/LiveMapScreen.kt` — `enableLocationComponent()` non appelé → point bleu MapLibre inactif.

**✅ Corrigé** — Ajout de `enableLocationComponent(context, map, style)` après chaque chargement de style. Fonction activant `RenderMode.COMPASS` + `CameraMode.NONE`.

---

### 2. Alertes — Texte croppé sous l'icône

**Symptôme :** Dans l'écran des alertes, le texte est tronqué sous l'icône d'alerte.

**Localisation :** `androidApp/.../ui/alerts/AlertsScreen.kt` — `LineGridCell` Box avec `height(96.dp)` fixe ; le contenu dépassait ~102 dp, le `clip` coupait le bas.

**✅ Corrigé** — `height(96.dp)` → `heightIn(min = 96.dp)`.

---

### 3. UX/UI — Barre d'état du trafic masquable

**Symptôme :** Le banner trafic en haut de la carte prend de la place et gêne la visibilité.

**Localisation :** `androidApp/.../ui/live/LiveMapScreen.kt` — banner rendu en overlay fixe, sans mécanisme de dismiss.

**✅ Corrigé** — `TrafficBanner` enveloppé dans `AnimatedVisibility` (slide + fade). Swipe vers le haut (delta < -40 px via `detectVerticalDragGestures`) collapse le banner. Pastille `KeyboardArrowDown` permet de le restaurer.

---

## iOS

### 4. Widget — Pas de refresh complet, délais pouvant afficher ~1 heure

**Symptôme :** Le widget affiche des délais faux (jusqu'à 1h) et ne se met pas à jour correctement.

**Localisation :**
- `AlerteTCLWidget/WidgetServices.swift` — `displayTime` sans timezone (risque décalage 1h) ; aucun filtre de délai max → passages fin de service inclus.
- `AlerteTCLWidget/NextDeparturesWidget.swift` — seulement 8 entrées de timeline, refresh 8 min.

**✅ Corrigé :**
- `displayTime.timeZone = Europe/Paris` — affichage correct quelle que soit la timezone device.
- Filtre `passageDate.timeIntervalSince(now) <= 90 * 60` dans `performNetworkFetch` — passages > 90 min exclus.
- Timeline étendue à 15 entrées, refresh toutes les 15 minutes.

---

### 5. Carte iOS — Retard dans le suivi des véhicules

**Symptôme :** Les véhicules sur la carte sont en retard par rapport à leur position réelle.

**Localisation :** `AlerteTCL/Models/AnimatedVehicle.swift` — `gracePeriod = 45.0` maintenait les fantômes 45 s, amplifiant l'impression de décalage.

**✅ Corrigé** — `gracePeriod` réduit à **25 s** (≈ 1 cycle API manqué). Le délai résiduel structurel (0–30 s API + 0–15 s polling) est inhérent à l'infrastructure.

