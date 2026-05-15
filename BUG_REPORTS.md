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

**4. Données SIRI / passages**
- Tramways : position non mise à jour en temps réel → horaires "prochain passage" incorrects
- Métro B (Debourg) : aucun passage affiché direction Charpennes
- Métro D (Vieux Lyon) : aucun passage affiché direction Gare de Vaise
- Funiculaires : les données d'arrivées (terminus) s'affichent au lieu des seuls départs (Vieux Lyon, Fourvière, Saint-Just)

---

## Bugs mineurs

**5. Favoris info trafic**
- Impossible d'ajouter une ligne de bus classique en favoris depuis l'onglet "Info trafic"

**6. Parking**
- Temps de chargement long entre les onglets Vélo et 2 roues

**7. Erreurs de chargement occasionnelles** (non reproductibles précisément)

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

**12. Horaires théoriques tramway**
- Au clic sur "prochain arrêt", afficher les horaires théoriques pour tous les arrêts suivants de la ligne

**13. Regroupement des arrêts (ex: Debourg)**
- Un seul point cliquable par station ouvrant un menu à deux colonnes (une par direction)

**14. Funiculaire F1 (Minimes – Théâtres Romains)**
- Fusionner les départs en un seul point (direction alternée, non critique pour l'usager)
