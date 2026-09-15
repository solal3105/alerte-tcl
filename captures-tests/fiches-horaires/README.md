# Captures d'écran : filtre « bus de cet arrêt » et fiches horaires

Captures prises le 15 septembre 2026 sur le simulateur iPhone 15 Pro (iOS 17) et sur
l'émulateur Pixel 8, avec les vraies fiches horaires produites par `horaires/build_timetables.py`
à partir du GTFS SYTRAL du jour. Les couleurs des lignes sont celles du jeu de données
(`route_color` / `route_text_color`).

Même numérotation dans les dossiers `ios/` et `android/` :

| Fichier | Ce qu'on voit |
| --- | --- |
| `00-carte-couleurs-officielles` | La carte avec les couleurs officielles des lignes (T1 bleu, C12 turquoise, C25 jaune). Mode démo `ages`. |
| `01-fiche-arret-boutons` | La fiche d'un arrêt avec, sous chaque ligne, « Voir ces bus sur la carte » et « Tous les horaires ». Mode démo `arret`. |
| `02-carte-filtre-bus-arret` | La carte filtrée sur les bus d'une ligne dans un sens, avec le bandeau et son bouton « Tout afficher ». Mode démo `bus-arret`. |
| `03-recherche-ligne` | La recherche d'une ligne, favoris en tête puis lignes groupées par mode. Mode démo `horaires`. |
| `04-choix-du-sens` | Le choix du sens d'une ligne. Mode démo `horaires-ligne`. |
| `05-choix-de-larret` | Les arrêts d'un sens, dans l'ordre du parcours. Mode démo `horaires-arrets`. |
| `06-horaires-a-larret` | Les passages d'une journée à un arrêt : date, raccourcis « Aujourd'hui » / « Demain » / « Autre jour », prochain passage mis en avant. Mode démo `horaires-arret`. |
| `07-detail-course` | Le détail d'une course, tous ses arrêts avec leurs heures. Mode démo `horaires-course`. |

Pour reproduire : iOS, lancer l'app avec l'argument `-demo <cas>` ; Android,
`adb shell am start -n com.alertetcl.android/.MainActivity --es demo <cas>`.
