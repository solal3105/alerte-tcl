# Prévision Vélo'v

Ce dossier est le robot qui, chaque semaine et sans intervention, réentraîne le modèle de
prévision des stations Vélo'v (vélos et places libres dans les 24 heures) et le publie pour les
applications.

## Chaîne de traitement

1. Le relais Cloudflare relève l'état de toutes les stations toutes les 5 minutes et garde
   75 jours (`/velov-releves`). Le robot ne lit que le relais, jamais Grand Lyon.
2. `.github/workflows/velov-prevision.yml` lance `build_forecast.py` chaque lundi vers 3 h (et
   le mercredi en rattrapage si le lundi n'a rien pu contrôler). Le script :
   - met les relevés sur une grille au quart d'heure et écarte les stations figées
     (`readings.py`, règles de l'étude d'origine) ;
   - entraîne un candidat sur les 8 semaines qui précèdent la dernière semaine (`training.py`,
     recette « légère » de l'étude : 12 modèles LightGBM) ;
   - note le candidat **et** le modèle en ligne sur la dernière semaine, jamais vue à
     l'entraînement (`control.py`), en relisant les fichiers publiés comme le fait l'application
     (`reader.py`) ;
   - décide quoi publier (garde-fous ci-dessous).
3. Le workflow pousse `modele.json` et `index.json` sur la branche orpheline `velov-prevision`
   (un seul commit, réécrit à chaque fois), que le relais sert sous `/velov-prevision/`.

Aucun secret, aucune étape manuelle. Lancer à la main : onglet *Actions*, workflow « Prévision
Vélo'v », *Run workflow*.

## Fichiers publiés (`format: 1`)

`index.json`

```json
{"format": 1, "version": "2026-11-09", "genere": 1794795420, "verifie": 1794795420, "taille": 4416391}
```

- `version` : identifiant du modèle (premier jour de sa semaine de contrôle). L'application ne
  retélécharge `modele.json` que si elle change.
- `genere` : création du modèle ; `taille` : octets de `modele.json`.
- `verifie` : dernière fois que le robot a constaté, sur des relevés frais, que ce modèle est bon
  (secondes epoch). **Il n'avance que lorsqu'un contrôle a réussi.** L'application cache les
  prévisions quand il a plus de 21 jours.

`modele.json`

```json
{
  "format": 1, "version": "2026-11-09", "genere": 1794795420,
  "variables": ["velos0", "elec0", "…"],
  "deciles": [10, 20, 30, 40, 50, 60, 70, 80, 90],
  "modeles": {"velos_q10": {"objectif": "quantile", "arbres": [{"f": [], "s": [], "d": [], "g": [], "r": [], "v": [], "racine": 0}]}},
  "habitude": {"1001": {"0_8": [6.2, 0.97, 0.91, 0.44]}},
  "stations": [{"id": 1001, "nom": "Terreaux", "commune": "Lyon 1er", "cap": 20, "altitude": 170.0,
                "dist_metro_km": 0.1, "dist_tram_km": 0.9, "dist_gare_km": 1.8, "lat": 45.7675, "lon": 4.8335}],
  "calendrier": {"feries": ["2026-11-11"], "vacances": [[1792188000000, 1793574000000]]},
  "controle": {"entrainement": ["2026-09-14T00:00:00Z", "2026-11-09T00:00:00Z"],
               "semaine": ["2026-11-09T00:00:00Z", "2026-11-16T02:15:00Z"],
               "lignes_entrainement": 1199314, "horizons": [{"h": 0.25, "lignes": 81895, "err": 1.29, "…": 0}]}
}
```

- `modeles` : 9 modèles `velos_q<décile>` (écart entre les vélos à l'heure visée et les vélos
  présents), `velos_p1` et `bornes_p1` (probabilité d'au moins un vélo, d'au moins une place),
  `part_elec` (part d'électriques). Arbres aplatis : pour chaque nœud la variable `f`, le seuil
  `s`, les drapeaux LightGBM `d` (bit 1 : manquant à gauche ; bits 2-3 : 0 aucun, 1 zéro, 2 NaN),
  les enfants `g` et `r` ; un enfant négatif `~i` désigne la feuille `v[i]`.
- `habitude` : par station puis `<type de jour>_<heure>` (0 semaine, 1 samedi, 2 dimanche ou
  férié ; heure de Lyon) : moyenne des vélos, fréquence d'au moins un vélo, d'au moins une place,
  part d'électriques (`null` si jamais de vélo). Créneau absent : aucun relevé.
- `stations` : repères géographiques. Une clé absente veut dire « inconnu » (valeur manquante).
- `calendrier` : jours fériés (date de Lyon) et vacances de la zone A, `[début, fin exclue]` en
  millisecondes epoch.
- `controle` : chiffres du modèle sur sa semaine de contrôle, par horizon `h` (heures) :
  `err` erreur moyenne de la médiane en vélos, `err_actuel` celle de « autant que maintenant » ;
  `couv80` / `couv40` part des cas où les vélos tombent dans la fourchette 10-90 / 30-70 ;
  `couv80_places` / `couv40_places` la même chose pour les places que l'application déduit
  (`places + vélos de maintenant − décile de vélos`, bornées entre 0 et la capacité) ;
  `brier`, `brier_place` scores de Brier des deux probabilités, et leurs `_actuel` ;
  `pinball` perte moyenne des neuf déciles ; `err_part_elec` erreur sur la part d'électriques.

Le format `1` est un contrat avec les applications installées : toute évolution incompatible se
publie sous un autre numéro.

## Garde-fous

Semaine de contrôle : les 7 derniers jours de relevés. Elle n'est jugeable que si les relevés
datent de moins de 2 jours et qu'elle compte au moins 120 heures de départ, 300 stations et
20 000 lignes par horizon (une semaine pleine : 168 heures, 450 stations, 75 000 lignes).

Un modèle est **bon** si, sur cette semaine :

- à chacun des huit horizons contrôlés (15 min à 24 h), la fourchette 10-90 contient la réalité
  entre 65 % et 95 % du temps, pour les vélos comme pour les places (étude d'origine : 79 à
  87 % ; rejeu sur 2026 : 71 à 89 % pour un modèle frais, le plus bas à la rentrée) ;
- à partir de 2 h, la médiane et les deux probabilités font mieux que « comme maintenant »
  (erreur moyenne, score de Brier). Avant 2 h l'état présent est presque imbattable, la
  comparaison ne dirait rien de la santé du modèle.

Décision :

| Situation | Ce qui est publié | `verifie` | Workflow |
|---|---|---|---|
| Candidat bon, et pas plus de 3 % moins bien noté que le modèle en ligne (pinball moyen) | le candidat | maintenant | réussi |
| Candidat mauvais ou nettement moins bon, modèle en ligne encore bon | le modèle en ligne, inchangé | maintenant | réussi |
| Pas de candidat possible (moins de 3 semaines de relevés avant la semaine de contrôle), modèle en ligne bon | le modèle en ligne, inchangé | maintenant | réussi |
| Aucun modèle bon | rien | inchangé | **échec** |
| Semaine non jugeable (relais en panne, relevés troués ou trop vieux) | rien | inchangé | réussi ; **échec** si le dernier contrôle a plus de 14 jours |
| Entraînement en erreur, ou lecteur Python en désaccord avec LightGBM | le modèle en ligne s'il est bon | maintenant | **échec** |

À qualité voisine le candidat l'emporte : il connaît mieux le réseau du moment. Un échec envoie
le courriel habituel de GitHub ; la publication précédente reste en ligne et les applications
cachent d'elles-mêmes les prévisions si plus aucun contrôle ne réussit pendant 21 jours.

Avant d'être noté, chaque candidat est relu par `reader.py` (jumeau du lecteur des
applications) et ses scores comparés à ceux de LightGBM sur toute la semaine de contrôle : un
écart supérieur à 10⁻⁶ écarte le candidat. Ce qui est noté est donc ce que l'application calcule.

## Ce qui tient dans la durée

- **Calendrier.** Jours fériés calculés (Pâques compris) de l'année précédente à l'année N+2.
  Vacances scolaires de Lyon lues sur l'API du ministère (data.education.gouv.fr, jeu
  `fr-en-calendrier-scolaire`) ; si elle ne répond pas, répond de travers ou voit moins loin que
  le calendrier en ligne, celui-ci est repris. Une panne de calendrier ne bloque jamais.
- **Stations nouvelles.** L'altitude et les distances au métro, au tram et à la gare ont été
  relevées une fois par l'étude d'origine (elles sont dans l'amorce). Une station apparue depuis
  prend sa position et son nom au relais (`/velov`), et l'altitude et les distances de la station
  connue la plus proche si elle est à moins de 500 m (erreur bornée à 500 m sur une distance) ;
  sinon ces clés sont omises et le modèle les traite comme manquantes.
- **Amorce.** `amorce/modele.json` est le modèle du prototype (entraîné du 25 août au 20 octobre
  2026), assemblé par `build_seed.py`. Tant que la branche n'existe pas, il tient lieu de modèle
  en ligne : il est publié dès qu'il passe le contrôle sur 7 jours de relevés, puis remplacé par
  le premier candidat (4 semaines après le début de la collecte).
- **Dépendances.** `requirements.txt` fixe les versions majeures ; le workflow rejoue les tests
  avant chaque entraînement et se réarme lui-même (`gh workflow enable`), GitHub désactivant les
  workflows planifiés d'un dépôt sans activité depuis 60 jours.
- **Données.** Seuls le modèle, des moyennes par station et le calendrier sont publiés ; aucun
  relevé n'entre dans le dépôt.

## En local

```bash
python3 -m venv /tmp/velov && /tmp/velov/bin/pip install -r velov-prevision/requirements.txt
/tmp/velov/bin/python -m unittest discover -s velov-prevision          # tests
/tmp/velov/bin/python velov-prevision/build_forecast.py --out /tmp/velov-out   # un passage complet
```

`--en-ligne <dossier>` désigne une copie de la branche `velov-prevision` (sans lui, l'amorce est
tenue pour le modèle en ligne), `--relais` un autre relais, `--maintenant 2026-10-27T13:00:00`
rejoue une date. Un passage complet prend une dizaine de minutes et 1,5 Go de mémoire.
