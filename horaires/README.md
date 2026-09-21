# Fiches horaires théoriques

Ce dossier construit les fiches horaires affichées dans l'application (onglet Transport :
bouton « Horaires » de la carte et « Tous les horaires » depuis la fiche d'un arrêt).

## Chaîne de traitement

1. `build_timetables.py` télécharge le GTFS SYTRAL publié sur data.gouv.fr (ressource
   « GTFS » du jeu de données *Horaires théoriques du réseau TCL*, accessible sans compte)
   et le découpe en fichiers JSON compacts, un par ligne et par sens.
2. `.github/workflows/horaires.yml` exécute ce script chaque nuit et pousse le résultat sur
   la branche orpheline `horaires` (un seul commit, réécrit à chaque publication : la branche
   ne conserve aucun historique et ne pèse pas sur le dépôt).
3. Le proxy Cloudflare (`cloudflare-worker/worker.js`, route `/horaires/...`) relaie ces
   fichiers depuis `raw.githubusercontent.com` avec un cache d'une heure.
4. Les applications lisent `index.json` puis `lignes/<CLÉ>/<A|R>.json` à la demande
   (`TimetableService` du module partagé, utilisé par iOS et Android).

Lancer une publication à la main : onglet *Actions* du dépôt GitHub, workflow « Fiches
horaires », bouton *Run workflow*. En local : `python3 horaires/build_timetables.py --out /tmp/horaires`.

## Format des fichiers (`format: 1`)

`index.json`

```json
{
  "format": 1,
  "generatedAt": "2026-09-16T03:41:12Z",
  "validFrom": "2026-09-16",
  "validTo": "2026-12-12",
  "lines": [
    {"line": "A", "key": "A", "mode": "metro", "color": "#E8308A", "textColor": "#FFFFFF",
     "directions": [{"dir": "A", "headsign": "Vaulx-en-Velin La Soie", "stops": 16, "trips": 1290}]}
  ]
}
```

`lignes/<CLÉ>/<A|R>.json` (clé = nom de ligne en majuscules, lettres et chiffres uniquement ;
sens `A` = aller, `R` = retour, convention identique au champ `desserte` des arrêts GeoServer
et au `DirectionRef` SIRI, `outbound` = aller)

```json
{
  "format": 1,
  "line": "C3", "key": "C3", "dir": "A", "mode": "bus", "color": "#004F9F", "textColor": "#FFFFFF",
  "headsign": "Vaulx-en-Velin La Grappinière",
  "validFrom": "2026-09-16", "validTo": "2026-12-12",
  "stops":    [{"id": 30101, "name": "Perrache"}, {"id": 30102, "name": "Bellecour"}],
  "patterns": [[0, 1], [0]],
  "services": [[0, 1, 2, 3, 4], [5, 6]],
  "trips":    [{"p": 0, "s": 0, "t": [300, 304]}, {"p": 1, "s": 1, "t": [1500]}]
}
```

- `color` / `textColor` : couleurs officielles du pictogramme de la ligne (`route_color` et
  `route_text_color` du GTFS). Les applications les appliquent à tout le réseau (badges, carte)
  dès que l'index est chargé, et les conservent entre deux lancements.
- `stops` : arrêts du sens dans l'ordre de présentation (identifiants GTFS, identiques à ceux
  du GeoServer `tclarret` et du flux SIRI).
- `patterns` : séquences d'arrêts (indices dans `stops`) ; une course partielle a son propre
  motif.
- `services` : pour chaque calendrier, les jours de circulation en nombre de jours depuis
  `validFrom` (`0` = le jour de génération).
- `trips` : les courses, triées par heure de départ ; `p` motif, `s` calendrier, `t` heures de
  passage en minutes depuis minuit pour chaque arrêt du motif. Une valeur ≥ 1440 est un
  passage après minuit rattaché à la journée de service précédente (`1500` = 01:00 le
  lendemain). Le GTFS SYTRAL n'emploie pas cette notation : il date ses courses de nuit du
  lendemain calendaire, à 00:xx (le métro du samedi soir jusqu'à 2 h est dans le calendrier du
  dimanche). Les applications reconstituent la journée de service (`LineTimetable.departures`,
  module partagé) : les courses d'un jour à partir de 4 h, puis celles du lendemain avant 4 h,
  affichées « +1 ».

## Ce qui garantit la mise à jour dans la durée

Les applications ne sont mises à jour que deux fois par an ; la chaîne doit donc tourner seule.

- La source est la ressource « GTFS » du jeu de données SYTRAL sur data.gouv.fr : une adresse
  stable qui redirige vers l'archive courante, sans compte. Si elle ne répond plus, le script
  interroge le jeu de données pour retrouver l'archive GTFS annoncée, puis tente l'adresse
  directe de Grand Lyon. Chaque archive est vérifiée (fichiers indispensables présents) avant
  d'être utilisée.
- La période annoncée (`validTo`) est le dernier jour où l'offre est complète, pas la dernière
  date citée dans le GTFS : SYTRAL planifie ses calendriers environ trois mois à l'avance et
  n'a, au-delà, que des exceptions éparses. Un jour compte comme complet s'il porte au moins
  60 % des courses du même jour de semaine (médiane des quatre premières semaines) ou 80 % d'un
  dimanche (jours fériés) ; on s'arrête au premier jour incomplet. Les courses définies par
  fréquence (`frequencies.txt`, vide aujourd'hui) sont développées en passages individuels.
- Garde-fous : moins de 100 lignes ou moins de 3 jours entièrement couverts, et rien n'est
  publié ; la publication précédente reste en ligne. Un téléchargement ou un traitement en échec
  fait échouer le workflow avant toute publication, et GitHub envoie alors un courriel d'échec à
  l'auteur du dernier commit du workflow.
- GitHub désactive les workflows planifiés d'un dépôt public sans activité depuis soixante
  jours. Le workflow se réarme donc lui-même à chaque exécution (`gh workflow enable`), en plus
  de la publication nocturne qui constitue une activité. Si malgré tout la planification
  s'arrêtait, GitHub le signale par courriel et un clic sur *Run workflow* la relance.
- Le relais Cloudflare garde la dernière réponse d'une heure et la ressert si GitHub ne répond
  pas. Les fichiers sont lus depuis la branche publique `horaires` : rendre le dépôt privé
  casserait ce relais (il faudrait alors un jeton GitHub dans les secrets Cloudflare).
- Si les fiches ne sont pas renouvelées, les applications continuent de fonctionner : elles
  affichent le dernier jour connu et un avertissement « Ces horaires ne sont plus à jour »
  (règle partagée `isStaleOn`), et renvoient vers les prochains passages à l'arrêt, qui viennent
  du temps réel et ne dépendent pas de cette chaîne.
- Le format `1` est un contrat : les applications déjà installées le lisent tel quel. Toute
  évolution incompatible se publie sous un nouveau numéro et de nouveaux chemins, jamais en
  modifiant les fichiers existants.

Les horaires restent théoriques : les applications renvoient vers les alertes trafic pour les
perturbations. Tests du script : `python3 -m unittest discover -s horaires`.
