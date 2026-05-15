# Retours utilisateurs — 15 mai 2026

## Bugs critiques

**1. Géolocalisation** ✅ *Corrigé le 15/05 (Android)*
- ~~Le point bleu de localisation est absent sur la carte~~ — `enableLocationComponent` n'était pas appelé quand la permission était accordée en cours d'exécution (seulement au chargement du style)
- ~~L'activation de la géo pendant que l'appli tourne ne prend pas effet~~ — même cause ; fix : appel de `enableLocationComponent` dans le callback `locationPermLauncher`
- iOS : `showsUserLocation = true` géré automatiquement par MapKit, pas de bug côté iOS

**2. Filtres véhicules** ✅ *Corrigé le 15/05 (Android)*
- ~~Sélectionner un type ne met pas à jour la carte immédiatement (nécessite un redémarrage)~~ — `LaunchedEffect` sur `filteredVehicles` (liste) était opaque pour Compose ; remplacé par clés explicites `(mapStyle, vehicles, selectedTypes, selectedLines)` + filtre calculé directement dans l'effet
- ~~Au redémarrage, tous les types sont cochés mais n'apparaissent pas non plus~~ — même cause

**3. Tracés de lignes** ✅ *Corrigé le 15/05 (Android)*
- ~~Toutes les lignes sont tracées même quand une seule est sélectionnée dans les filtres~~ — `LaunchedEffect` des tracés ne dépendait pas de `selectedLines` ; ajout de `selectedLines` comme clé + filtre `line.name !in selectedLines` quand non vide

**4. Données SIRI / passages** *(problème côté API TCL — non corrigeable)*
- Tramways : position non mise à jour en temps réel → horaires "prochain passage" incorrects — même comportement sur iOS, données TCL
- Métro B (Debourg) : aucun passage affiché direction Charpennes — données absentes dans l'API SIRI
- Métro D (Vieux Lyon) : aucun passage affiché direction Gare de Vaise — même cause
- Funiculaires : les données d'arrivées (terminus) s'affichent au lieu des seuls départs — même cause

---

## Bugs mineurs

**5. Favoris info trafic** ✅ *Corrigé (Android)*
- ~~Impossible d'ajouter une ligne de bus classique en favoris depuis l'onglet "Info trafic"~~ — `allLines` était construite depuis l'API (metro/funi/tram + Bus C seulement) ; remplacée par `TransportLine.allPredefinedLines` (liste statique complète, parité iOS)

**6. Parking** ✅ *Corrigé (Android)*
- ~~Temps de chargement long entre les onglets Vélo et 2 roues~~ — aucun `LaunchedEffect` ne déclenchait `loadInRegion` lors du changement de type ; ajout d'un `LaunchedEffect(selectedTypes, showParcRelais, showRealtimeParkings)` pour recharger immédiatement

**7. Erreurs de chargement occasionnelles** *(non reproductible — skip)*

---

## UI / Ergonomie

**8. Taille des arrêts** ✅ *Corrigé le 15/05*
- ~~Les boutons d'arrêts sont trop petits, difficiles à taper au doigt~~ — dots et badges agrandis ~27% sur iOS et Android

**9. Couleurs des bus**
- Couleur générique utilisée au lieu des couleurs officielles TCL (ex : rouge/jaune Bus Relais 60, vert S1)

**10. Lisibilité direction/sens** ✅ *Partiellement corrigé le 15/05*
- ~~Manque de clarté sur le sens d'une ligne depuis la carte~~ — la destination (ex: "Perrache") s'affiche maintenant correctement dans la fiche véhicule sur iOS et Android (fix `extractDestination` SIRI-Lite)

**11. Tracés imprécis**
- Tracés et points de stations de certaines lignes métro/funiculaire pas assez précis géographiquement

---

## Suggestions d'amélioration

**12. Horaires théoriques tramway** *(pas de données — skip)*
- Nécessiterait les IDs d'arrêt par séquence dans `TransitLine` ; le modèle actuel ne contient que la géométrie

**13. Regroupement des arrêts (ex: Debourg)** ✅ *Corrigé (Android)*
- ~~Un seul point cliquable par station ouvrant un menu à deux colonnes (une par direction)~~ — `StopMergingEngine` porté en KMP shared (grille 55m + Union-Find, fusion à < 30m si mêmes lignes, parité iOS). `ClusteringEngine` consomme désormais des `MergedStop`. Fiche arrêt agrège les passages de tous les sous-arrêts fusionnés.

**14. Funiculaire F1 (Minimes – Théâtres Romains)** ✅ *Corrigé (Android)*
- ~~Fusionner les départs en un seul point (direction alternée, non critique pour l'usager)~~ — même fix que #13 ; les deux quais du funiculaire sont fusionnés par `StopMergingEngine`
