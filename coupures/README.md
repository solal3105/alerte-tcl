# Coupures du réseau TCL

Les applications montrent sur la carte ce qui ne circule pas : une ligne arrêtée, un tronçon fermé,
un arrêt non desservi, et à quels moments. TCL ne publie pas cette information sous une forme lisible
par une machine : tout est écrit dans le texte de ses alertes (« la ligne D circule uniquement de Gare
de Vaise à Saxe-Gambetta, les lundis et mardis à partir de 21h20 »). Ce dossier lit ces textes.

La lecture tourne sur GitHub, pas dans les applications : quand TCL écrit une phrase d'une façon
nouvelle, on corrige la lecture ici et la correction arrive sur tous les téléphones dans les minutes
qui suivent, sans nouvelle version des applications.

## Ce qui tourne

`.github/workflows/coupures.yml`, toutes les 5 minutes (GitHub prend souvent quelques minutes de
retard), et à chaque modification de ce dossier sur `main` :

1. les tests de la lecture (`node --test coupures/test/*.test.mjs`) : s'ils échouent, rien n'est publié ;
2. une fois par nuit, `construire-reseau.mjs` prépare le réseau depuis le GeoServer public du Grand
   Lyon (tracés par ligne et par sens, arrêts dans l'ordre du parcours) ; le GeoServer ne rend que
   1 000 objets par réponse, d'où la pagination, sans laquelle des lignes entières manquent ;
3. `construire.mjs` lit les alertes sur le relais (sa copie de `/alerts`, aucune requête de plus chez
   Grand Lyon) et écrit `coupures.json` ;
4. le résultat est poussé sur la branche orpheline `coupures` (un seul commit), que le relais sert sous
   `/coupures` avec un cache partagé de 60 secondes.

## Fichiers

- `lib/analyse.mjs` : lecture des alertes. Ce que dit le texte (`lireTexte` : interruption, tronçon,
  limitation, arrêt non desservi, arrêt reporté…), quand cela s'applique (`lireCalendrier` : jours,
  dates et heures cités dans le titre ou le texte, une fenêtre par jour de service), et où (`analyser` :
  arrêts retrouvés sur le réseau par leur nom, tronçons découpés sur le tracé).
- `lib/geo.mjs` : géométrie des tracés (projection en mètres, découpe, simplification).
- `lib/publication.mjs` : passage du résultat de la lecture au format des applications.
- `test/` : les alertes du 22 novembre 2026 sur un extrait du réseau (lignes B, C, D, T3, T4, C8, 36, 38).

Pour essayer une lecture sur un fichier d'alertes enregistré :

```sh
node coupures/construire-reseau.mjs /tmp/reseau.json
node coupures/construire.mjs /tmp/reseau.json /tmp/coupures.json alertes.json
```

## Format de `coupures.json` (format 1)

Les dates sont à l'heure de Paris, au format des alertes TCL (`2026-11-23 21:20:00`).

```
{
  "format": 1,
  "genere": "2026-11-22T10:22:09.000Z",   // dernière lecture qui a réécrit le fichier (UTC)
  "reseau": "2026-11-22T02:40:00.000Z",   // date du réseau utilisé
  "coupures": [ … ],
  "nonPlacees": [ … ]
}
```

Chaque entrée de `coupures` est une alerte qui coupe quelque chose :

- `id` : identité de l'alerte, la même que `AlertIdentity` dans le module partagé (ligne, titre, début,
  empreinte du message), pour la rattacher à l'alerte que l'application affiche déjà ;
- `ligne`, `mode` (`metro`, `tram`, `trambus`, `bus`…), `couleur`, `titre`, `message`, `gravite`
  (le `typeseverite` de TCL, qui ne dit presque jamais `NO_SERVICE`, même quand rien ne roule) ;
- `debut`, `fin` : la période publiée par TCL ;
- `fenetres` : les moments où l'alerte s'applique vraiment, `[{debut, fin}]` (une par soirée pour des
  travaux du soir). `fin` peut être `null`. Les fenêtres déjà passées ne sont pas publiées ; les
  applications décident seules si une fenêtre est en cours ou à venir ;
- `horairesPartiels` : `true` quand le texte parle de certains moments sans dire lesquels
  (« certains soirs ») ; les fenêtres sont alors toute la période ;
- `datesContradictoires` : `true` quand le titre ou le texte cite des jours dont aucun ne tombe dans
  la période publiée. La période fait foi, l'application signale l'écart ;
- `destinations` : terminus de chaque sens (`A`, `R`) ;
- `effets` : ce que dit le texte, sens par sens (`interruption`, `partiel`, `limitation`, `deviation`
  avec arrêts fermés, `arret-non-desservi`, et leurs arrêts `de`, `a`, `terminus`, `depart`…) ;
- `traits` : tronçons qui ne circulent pas, `[{sens, deuxSens, points: [[lon, lat], …]}]` ;
- `arrets` : arrêts non desservis, `[{nom, sens, lon, lat, dansTroncon}]` (`dansTroncon` : sur un
  tronçon coupé, plutôt qu'un arrêt fermé seul) ;
- `bornes` : derniers arrêts desservis de part et d'autre d'une coupure, `[{nom, sens, lon, lat}]`.

Ne sont pas publiées : les déviations sans arrêt fermé, les arrêts reportés un peu plus loin et les
itinéraires de travaux déjà dans les horaires de la semaine, qui ne coupent rien.

`nonPlacees` liste les alertes `NO_SERVICE` dont le texte n'a pas permis de placer la coupure : les
applications leur gardent une pastille sur la ligne, sans rien griser.

## Fraîcheur

Le fichier n'est réécrit que si son contenu change, et au moins une fois par heure. Les applications
n'utilisent pas un fichier dont `genere` a plus de 6 heures : la lecture ne tourne plus, et mieux vaut
ne rien montrer qu'une coupure peut-être levée depuis.
