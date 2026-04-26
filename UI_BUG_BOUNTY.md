# 🐛 Bug Bounty UI — Incohérences Android vs iOS

> **Périmètre** : comparaison écran par écran entre `androidApp/` (branch `kmp-migration`, commit `caf81a8`) et `AlerteTCL/` (iOS natif SwiftUI).  
> **Règle** : aucun code modifié — audit lecture seule.  
> **Hors scope** : différences purement stylistiques (blur/matière, forme exacte des badges, tailles de police, couleurs d'icônes, animations). Le design Material Android est assumé.  
> **Dans le scope** : composants manquants, mauvais positionnement, mauvais comportement UX, fonctionnalités absentes.  
> Priorités : **P0** = visible immédiatement / cassant, **P1** = important mais app fonctionnelle, **P2** = détail de comportement.

---

## Sommaire rapide

| Écran | P0 | P1 | P2 | Total |
|---|---|---|---|---|
| LiveMapScreen | 4 | 5 | 2 | 11 |
| TravauxScreen | 2 | 3 | 3 | 8 |
| ParkingScreen | 2 | 4 | 3 | 9 |
| AlertsScreen | 0 | 3 | 1 | 4 |
| LinesListScreen | 2 | 1 | 1 | 4 |
| SettingsScreen | 0 | 1 | 2 | 3 |
| StopDetailSheet | 0 | 3 | 1 | 4 |
| Navigation / App Shell | 0 | 1 | 3 | 4 |
| **Total** | **10** | **21** | **16** | **47** |

---

## 🗺️ LiveMapScreen

### P0

**L-01 — Jeu de FABs entièrement faux**
- **iOS** : 3 FABs colonne bas-droite — satellite (`globe`), filtres (`line.3.horizontal.decrease.circle`, bleu si actif), localisation (`location.fill`, bleu).
- **Android** : 4 FABs — satellite, alertes (`Warning`), réglages (`Settings`), rafraîchir (`Refresh`).
- Aucun des 3 FABs iOS n'est présent côté Android (filter FAB, location FAB absents). Les alertes doivent être dans le `TrafficBannerView`, pas un FAB. Un FAB settings sur la carte live n'existe pas sur iOS. Refresh inutile sur une carte live (stream continu).

**L-02 — `TrafficBannerView` absent**
- **iOS** : bannière `TrafficBannerView` en haut de la carte, affiche le statut des lignes suivies, le compteur d'alertes actives et l'heure du dernier refresh.
- **Android** : `LinearProgressIndicator` + `TextButton` d'erreur + `Surface` de chips de filtres. Aucune bannière d'information réseau.

**L-03 — `liveIndicator` absent**
- **iOS** : VStack bas-gauche : bouton capsule orange "N source(s) en erreur" si erreur + badge animé `LIVE •` (vert/orange) avec compte à rebours avant le prochain rafraîchissement.
- **Android** : rien en bas-gauche. L'indicateur de rafraîchissement et les erreurs de sources ne sont pas rendus visiblement.

**L-04 — Mécanisme de filtrage des véhicules**
- **iOS** : FAB filtre → `FilterSheet` (basculer les types de véhicule, tracés, arrêts) ; le FAB prend une teinte bleue quand des filtres sont actifs.
- **Android** : chips de filtres en barre horizontale scrollable en haut de la carte — toujours visibles, pas de sheet, pas d'état "actif" sur un bouton dédié.

---

### P1

**L-05 — `MergedStop` vs `TransitStop`**
- **iOS** : utilise `MergedStop` (fusion des arrêts < 30 m). L'annotation affiche les badges des lignes (max 4) sous le disque ; tap → `MergedStopDetailSheet`.
- **Android** : utilise `TransitStop` individuel → disque blanc basique `CircleLayer`, aucun badge de ligne visible sur la carte.

**L-06 — Flèche de cap absente sur les véhicules**
- **iOS** : `VehicleAnnotationView` dessine une flèche 10×7 pt orbitale autour du corps du véhicule, pivotant selon le bearing.
- **Android** : icône bitmap plate, aucune flèche directionnelle.

**L-07 — Gestion du cycle de vie de l'app**
- **iOS** : `scenePhase .background` → stream arrêté ; `.active` → stream redémarré + badge notif effacé.
- **Android** : stream tourne en continu quelle que soit l'état de l'app (foreground/background).

**L-08 — Sheet `DataSourceErrors` rudimentaire**
- **iOS** : sheet `.medium` listant en détail chaque source en erreur (nom de source, message, retry).
- **Android** : `TextButton` "1 source en erreur" qui ouvre `showErrorsSheet = true`, mais la logique de construction de ce sheet est identique pour toutes les erreurs (pas de liste structurée par source).

**L-09 — Detents de la fiche arrêt**
- **iOS** : `TransitStopDetailSheet` présente en `.medium` ajustable jusqu'à `.large`.
- **Android** : `ModalBottomSheet` sans `skipPartiallyExpanded`, s'ouvre en plein écran directement.

---

### P2

**L-10 — Mode simplifié des véhicules (LOD)**
- **iOS** : à `latitudeDelta > 0.05` (dézoom) les véhicules deviennent de simples disques 12 pt, économisant des ressources.
- **Android** : toujours le bitmap complet quelle que soit la distance de zoom.

**L-11 — Compteur de véhicules**
- **iOS** : aucun compteur texte affiché sur la carte.
- **Android** : badge "N véhicules" blanc bas-droite au-dessus des FABs. Élément absent sur iOS.

---

## 🔧 TravauxScreen

### P0

**T-01 — Pas de FAB satellite**
- **iOS** : FAB satellite (colonne droite), même design que LiveMap.
- **Android** : absent. La carte travaux est toujours en mode plan.

**T-02 — Pas de filtre travaux**
- **iOS** : FAB filtre (orange si `hasActiveFilters`) → `TravauxFiltersSheet` (filtrer par type, importance, avancement).
- **Android** : aucun filtre. Tous les travaux sont affichés sans possibilité de tri.

---

### P1

**T-03 — Pas de FAB localisation**
- **iOS** : bouton localisation (colonne droite, 3ème FAB).
- **Android** : absent.

**T-04 — Pas de clustering**
- **iOS** : `TravauxClusterMarker` regroupe les chantiers proches ; tap → zoom sur le cluster.
- **Android** : tous les marqueurs individuels affichés simultanément, peut être visuellement surchargé sur des zones denses.

**T-05 — Icône centrale du marqueur**
- **iOS** : `travaux.type.icon` = SF Symbol correspondant au type de chantier (marteau, pelle, etc.).
- **Android** : lettre "H" codée en dur pour tous les types de travaux (`canvas.drawText("H", ...)`).

---

### P2

**T-06 — Indicateur de chargement**
- **iOS** : overlay centré `.ultraThinMaterial` + `ProgressView`, visible uniquement si `travaux.isEmpty`.
- **Android** : `LinearProgressIndicator` pleine largeur en haut, toujours affiché quand `isLoading == true` (même si des données sont déjà affichées).

**T-07 — Aucun overlay d'erreur**
- **iOS** : carte d'erreur aware jour/nuit avec bouton retry (même pattern que ParkingMapView).
- **Android** : aucun état d'erreur rendu.

**T-08 — Ancre du marqueur**
- **iOS** : `.anchor(.bottom)` → la pointe du marqueur touche la coordonnée.
- **Android** : marqueur centré sur la coordonnée (`iconAnchor` non défini = center).

---

## 🅿️ ParkingScreen

### P0

**P-01 — Pas de FAB satellite**
- **iOS** : FAB satellite en colonne droite.
- **Android** : absent.

**P-02 — Sélecteur de type masque la carte**
- **iOS** : `parkingTypeSelector` positionné en haut avec un fond translucide → la carte reste partiellement visible derrière.
- **Android** : `Surface` blanc opaque en haut + `LinearProgressIndicator` + barre de sélection → le sélecteur occupe une bande opaque notable en haut, masquant une portion de la carte. Envisager un fond semi-transparent ou réduire l'empreinte verticale.

---

### P1

**P-03 — Pas de FAB localisation**
- **iOS** : bouton localisation (colonne droite).
- **Android** : absent.

**P-04 — Pas de clustering**
- **iOS** : `ParkingClusterMarker` regroupe les parkings proches.
- **Android** : tous les marqueurs individuels simultanément.

**P-05 — Pas de lignes TCL sur la carte parking**
- **iOS** : les tracés des lignes TCL sont dessinés en contexte sur la carte parking.
- **Android** : carte vierge (aucune ligne de transport superposée).

**P-06 — `hasActiveFilters` incomplet**
- **iOS** : `!showRealtimeParkings || !showParcRelais` → le badge orange sur le FAB filtre apparaît pour les deux toggles.
- **Android** : `val hasActiveFilters = !showParcRelais` → le filtre `showRealtimeParkings` n'est jamais pris en compte dans l'indicateur.

---

### P2

**P-07 — Toggle `showRealtimeParkings` manquant dans le filter sheet**
- **iOS** : `ParkingFiltersSheet` a deux toggles : "Données temps réel uniquement" + "Parc Relais".
- **Android** : `ParkingFilterSheet` a seulement le toggle ParcRelais.

**P-08 — `refreshCard` sans horodatage**
- **iOS** : carte bas-gauche avec timestamp du dernier refresh + animation pulsante.
- **Android** : `CircleShape IconButton` avec `Icons.Filled.Refresh`, aucun timestamp.

**P-09 — Pas d'annotation utilisateur (GPS)**
- **iOS** : `UserAnnotation()` affiche la position GPS de l'utilisateur sur la carte.
- **Android** : aucun point bleu de position utilisateur.

---

## 🔔 AlertsScreen

### P1

**A-01 — Indicateur de chargement (style différent)**
- **iOS** : overlay `.thickMaterial` centré + `ProgressView()` quand chargement initial.
- **Android** : `CircularProgressIndicator()` centré (comportement proche, mais encapsulé dans `PullToRefreshBox` avec un paradigme pull-to-refresh qui n'existe pas sur iOS).

**A-02 — Badge de comptage sur les chips de mode**
- **iOS** : `ModeFilterChip` affiche un badge capsule avec le nombre d'alertes actives pour ce mode.
- **Android** : `ModeFilterTabs` n'affiche que le nom et l'icône du mode, sans badge.

**A-03 — Empty state "Mes lignes"**
- **iOS** : vue centrée avec grande illustration + titre "Suivez vos lignes" + bouton CTA "S'abonner".
- **Android** : bouton "Ajouter une ligne" simple dans la section, sans illustration ni titre d'état vide différencié.

---

### P2

**A-04 — Page indicator du carrousel "Mes lignes"**
- **iOS** : carrousel avec indicateur de points en dessous.
- **Android** : `HorizontalPager` sans indicateur de page visible → l'utilisateur ne sait pas combien de cartes existent.

---

## 📋 LinesListScreen

### P0

**LL-01 — Barre de recherche absente**
- **iOS** : `.searchable(text: $viewModel.searchText, prompt: "Rechercher une ligne")` intégré à la navigation (champ natif dans la barre de navigation).
- **Android** : aucune recherche, impossible de filtrer par texte.

**LL-02 — Dialog d'abonnement manquant**
- **iOS** : tap sur `LineCard` → `confirmationDialog` natif avec 3 options : "Toutes les alertes" / "Perturbations majeures uniquement" / "Perturbations (sans infos)" + permission notif demandée.
- **Android** : tap sur `LineCard` → `FavoritesStore.toggleFavoriteLine()` directement, sans dialog ni choix de type, sans demande de permission.

---

### P1

**LL-03 — Demande de permission notification**
- **iOS** : `subscribeWithTypes()` appelle `NotificationService.shared.requestPermission()` à chaque abonnement.
- **Android** : aucune demande de permission au moment du suivi d'une ligne.

---

### P2

**LL-04 — `LineCard` ne navigue pas vers une vue détail**
- **iOS** : tap → dialog d'abonnement (voir LL-02). Futur : pourrait ouvrir une fiche ligne.
- **Android** : toggle direct du favori sans feedback visuel intermédiaire.

---

## ⚙️ SettingsScreen

### P1

**S-01 — Section "Notifications" en surnombre (Android only)**
- **iOS** : 2 sections uniquement — "Widget Prochains Passages" + "À propos". Les permissions notifs sont gérées à l'abonnement d'une ligne (LinesListView).
- **Android** : 3 sections — ajout d'une section "NOTIFICATIONS / Permissions" qui ouvre les réglages système. Absente de l'iOS.

---

### P2

**S-02 — "Mes arrêts widget" ouvre le mauvais écran**
- **iOS** : ouvre `SavedWidgetStopsView` (liste des arrêts déjà sauvegardés, gestion seule).
- **Android** : appelle `onOpenWidgetStops` → `WidgetStopSelectionScreen` (même écran que l'ajout depuis la carte), confondant les deux flux.

---

## 🚏 StopDetailSheet

### P1

**SD-01 — En-tête "Prochains passages" sans icône ni couleur**
- **iOS** : `Label("Prochains passages", systemImage: "clock.fill")` en bleu (`.foregroundStyle(.blue)`).
- **Android** : `Text("Prochains passages")` sans icône ni couleur spécifique.

---

### P2

**SD-02 — Texte empty state**
- **iOS** : "Les horaires seront affichés quand des véhicules seront en approche" — explique *pourquoi* il n'y a pas de données.
- **Android** : "Aucun passage à venir" — moins informatif, l'utilisateur peut croire que l'arrêt est fermé.

---

## 🧭 Navigation / App Shell

### P1

**N-01 — Navigation bottom bar : libellés des onglets**
- **iOS** : onglets libellés `Alertes`, `Travaux`, `Parkings`, `Infos`.
- **Android** : les libellés exacts et leur cohérence avec les destinations n'ont pas été vérifiés dans `AlerteTCLApp.kt` — à confirmer que les 4 onglets portent les mêmes labels.

---

### P2

**N-02 — Effacement du badge notification**
- **iOS** : `scenePhase .active` → `NotificationService.shared.clearBadge()`.
- **Android** : non implémenté. Le badge reste même après ouverture de l'app.

**N-03 — Deep-link `selectedParkingId`**
- **iOS** : une notification peut porter un ID de parking ; `ContentView` lit le binding `selectedParkingId` et bascule vers le tab parking avec mise en évidence du parking ciblé.
- **Android** : seul le routing par nom d'écran (`EXTRA_INITIAL_ROUTE`) est implémenté. Aucune gestion de `selectedParkingId`.

**N-04 — Notification interne "OpenAlertDetail"**
- **iOS** : `ContentView` écoute `NSNotification.Name("OpenAlertDetail")` pour basculer sur le tab transport (tab 0).
- **Android** : non implémenté.

---

## Récapitulatif priorisé

### P0 — À traiter en priorité absolue (10 items)
| ID | Écran | Description |
|---|---|---|
| L-01 | LiveMap | Jeu de FABs entièrement faux (mauvais boutons, location FAB manquant) |
| L-02 | LiveMap | `TrafficBanner` absent (composant entier manquant en haut) |
| L-03 | LiveMap | `liveIndicator` absent (composant entier manquant en bas-gauche) |
| L-04 | LiveMap | Filtres en chips inline au lieu d'un sheet avec FAB dédié |
| T-01 | Travaux | FAB satellite absent |
| T-02 | Travaux | Bouton filtres et `TravauxFiltersSheet` absents |
| P-01 | Parking | FAB satellite absent |
| P-02 | Parking | Sélecteur de type masque une bande opaque en haut de la carte |
| LL-01 | Lignes | Barre de recherche absente |
| LL-02 | Lignes | Dialog d'abonnement avec choix de type manquant |

### P1 — À traiter dans la foulée (21 items)
L-05, L-06, L-07, L-08, L-09, T-03, T-04, T-05, P-03, P-04, P-05, P-06, A-01, A-02, A-03, LL-03, S-01, SD-01, N-01

### P2 — Finitions comportement (16 items)
L-10, L-11, T-06, T-07, T-08, P-07, P-08, P-09, A-04, LL-04, S-02, SD-02, N-02, N-03, N-04
