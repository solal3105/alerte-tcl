#!/usr/bin/env python3
"""
Robot hebdomadaire de la prévision Vélo'v : réentraîne le modèle sur les deux derniers mois de
relevés, le contrôle sur la dernière semaine, le compare à celui qui est en ligne et écrit ce qui
doit être publié sur la branche `velov-prevision` (voir README.md et .github/workflows).

Entrées : les relevés gardés par le relais Cloudflare, le modèle en ligne (copie de la branche)
          ou, avant la première publication, le modèle d'amorce du dépôt.
Sortie  : `modele.json` et `index.json` dans --out quand un modèle a passé le contrôle ; rien sinon
          (la publication précédente reste en ligne, son contrôle n'est pas rafraîchi).

Le script ne s'arrête sur une erreur que pour ce qui demande un regard humain, et toujours après
avoir écrit ce qui pouvait l'être : une panne du relais ou une semaine trouée se terminent sans bruit.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time

import bundle
import control
import holidays
import readings
import stations
import training
from reader import STEP
from readings import DAY

# Fenêtres de la recette : huit semaines d'entraînement, puis la semaine de contrôle.
TRAIN_DAYS = 56
CONTROL_DAYS = 7
# En dessous de trois semaines d'entraînement (relais tout juste mis en route, longue panne), l'habitude
# de chaque station par type de jour et par heure repose sur trop peu de jours : pas de candidat.
MIN_TRAIN_DAYS = 21
# Trois semaines complètes donnent environ 400 000 lignes ; moins de la moitié, la collecte est trop trouée.
MIN_TRAIN_ROWS = 200_000
# Jours relus avant l'entraînement, pour reconnaître une station figée dès le premier jour utile.
WARMUP_DAYS = 3
# Des relevés qui s'arrêtent plus de deux jours avant maintenant ne décrivent pas « la dernière semaine ».
MAX_READINGS_AGE = 2 * DAY
# Sans contrôle réussi depuis deux semaines, le robot échoue pour prévenir : à trois, les applications
# cessent d'afficher les prévisions.
ALERT_AFTER = 14 * DAY
# Passage de rattrapage (voir le workflow) : il ne fait rien si un contrôle a réussi depuis moins de quatre jours.
RECENT_CHECK = 4 * DAY
# Écart toléré entre le lecteur et LightGBM sur un score brut (les seuils publiés ont neuf chiffres).
READER_TOLERANCE = 1e-6


class TooEarly(Exception):
    """Pas encore assez de relevés pour entraîner : situation normale au démarrage, pas un incident."""


def log(msg: str) -> None:
    print(msg, flush=True)


def iso(seconds: int) -> str:
    return dt.datetime.fromtimestamp(seconds, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def utc_day(seconds: int) -> dt.date:
    return dt.datetime.fromtimestamp(seconds, dt.timezone.utc).date()


def version_of(cut: int) -> str:
    """Identifiant d'un modèle : le premier jour (UTC) de sa semaine de contrôle, où s'arrête son entraînement."""
    return utc_day(cut).isoformat()


def figures_table(title: str, verdict: control.Verdict) -> list[str]:
    """Chiffres d'un contrôle, lisibles dans le journal comme dans le résumé GitHub (Markdown)."""
    names = ("lignes", "err", "err_actuel", "couv80", "couv40", "couv80_places", "couv40_places", "brier", "brier_actuel",
             "brier_place", "brier_place_actuel", "pinball", "err_part_elec")
    lines = [f"**{title}** : " + ("bon" if verdict.good else "écarté (" + " ; ".join(verdict.defects) + ")"), ""]
    if verdict.figures:
        lines += ["| h | " + " | ".join(names) + " |", "|" + "---|" * (len(names) + 1)]
        lines += [f"| {line['h']:g} | " + " | ".join(str(line[name]) for name in names) + " |" for line in verdict.figures]
        lines += ["", f"Note (pinball moyen) : {verdict.score:.4f}", ""]
    return lines


def live_stations(relay: str) -> list[dict]:
    """Stations annoncées aujourd'hui par le relais ; liste vide s'il ne répond pas (les stations
    nouvelles attendront la semaine suivante pour avoir une position)."""
    try:
        return [
            s for s in readings.fetch_json(relay, "/velov")["stations"]
            if isinstance(s.get("id"), int) and isinstance(s.get("name"), str)
            and all(isinstance(s.get(key), (int, float)) for key in ("lat", "lng"))
        ]
    except Exception as exc:
        log(f"  stations du relais indisponibles ({exc})")
        return []


def build_candidate(grid: readings.Grid, cut_slot: int, check: dict, calendrier: dict, described: list[dict], now: int) -> tuple[dict, control.Verdict]:
    """Entraîne le modèle de la semaine et le note sur les lignes de contrôle `check`. Lève une erreur
    si l'entraînement est impossible ou si le lecteur ne retrouve pas les scores de LightGBM."""
    first_slot = max(0, cut_slot - TRAIN_DAYS * DAY // STEP)
    if cut_slot - first_slot < MIN_TRAIN_DAYS * DAY // STEP:
        raise TooEarly(f"{(cut_slot - first_slot) * STEP // DAY} jours de relevés avant la semaine de contrôle, il en faut {MIN_TRAIN_DAYS}")
    rows = training.training_rows(grid, first_slot, cut_slot)
    if len(rows["xq"]) < MIN_TRAIN_ROWS:
        raise TooEarly(f"{len(rows['xq'])} lignes d'entraînement, il en faut {MIN_TRAIN_ROWS}")
    log(f"Entraînement : {len(rows['xq'])} lignes du {iso(grid.start + first_slot * STEP)} au {iso(grid.start + cut_slot * STEP)}")
    modeles, habitude, boosters = training.train(rows, described, calendrier, log)
    cut = grid.start + cut_slot * STEP
    candidate = bundle.assemble(version_of(cut), now, modeles, habitude, described, calendrier, {})
    gap = training.reader_gap(candidate, boosters, check)
    if gap > READER_TOLERANCE:
        raise ValueError(f"le lecteur s'écarte de LightGBM de {gap:.3g} : l'export des arbres n'est plus fidèle")
    verdict = control.judge(candidate, check)
    candidate["controle"] = {
        "entrainement": [iso(grid.start + first_slot * STEP), iso(cut)], "semaine": [iso(cut), iso(grid.end)],
        "lignes_entrainement": len(rows["xq"]), "horizons": verdict.figures,
    }
    return candidate, verdict


def run(args: argparse.Namespace, now: int) -> list[str]:
    """Une exécution du robot. Rend les incidents qui doivent faire échouer le workflow (liste vide
    quand tout s'est passé comme prévu, y compris « rien à publier cette semaine »)."""
    with open(args.amorce, "rb") as source:
        seed_bytes = source.read()
    seed = json.loads(seed_bytes)
    index, online_bytes = bundle.read_published(args.en_ligne)
    if online_bytes is None:
        online_bytes, online = seed_bytes, seed
    else:
        try:
            online = json.loads(online_bytes)
        except ValueError:
            online = None
        if not isinstance(online, dict):
            online = {}
    log("Modèle en ligne : " + (f"version {index['version']}, contrôlé le {iso(index['verifie'])}" if index else "aucun, amorce du dépôt"))
    if args.planifie and index is not None and now - index["verifie"] < RECENT_CHECK:
        log("Contrôle réussi il y a moins de quatre jours : rien à faire cette fois")
        return []

    def wait(reason: str) -> list[str]:
        """Rien à contrôler cette semaine : on ne touche à rien, et on ne prévient que si cela dure."""
        log(f"::warning::Contrôle impossible, publication inchangée : {reason}")
        stale = index is not None and now - index["verifie"] > ALERT_AFTER
        return [f"aucun contrôle réussi depuis le {iso(index['verifie'])} : {reason}"] if stale else []

    log("Lecture des relevés auprès du relais")
    try:
        first_day = utc_day(now - (TRAIN_DAYS + CONTROL_DAYS + WARMUP_DAYS) * DAY)
        grid = readings.build_grid(readings.download(args.relais, first_day, now, args.cache, log))
    except Exception as exc:
        return wait(f"relais illisible ({exc})")
    if grid is None:
        return wait("le relais n'a encore aucun relevé")
    if now - grid.end > MAX_READINGS_AGE:
        return wait(f"les relevés s'arrêtent le {iso(grid.end)}")
    cut = grid.end // DAY * DAY - CONTROL_DAYS * DAY
    if cut < grid.start:
        return wait(f"moins de {CONTROL_DAYS} jours de relevés")
    cut_slot = (cut - grid.start) // STEP
    check = training.control_rows(grid, cut_slot)
    log(f"Semaine de contrôle : {len(check['xq'])} lignes du {iso(cut)} au {iso(grid.end)}")
    holes = control.week_defects(check)
    if holes:
        return wait(" ; ".join(holes))

    # Tout fichier publié porte un calendrier à jour, y compris un modèle reconduit tel quel : c'est donc
    # avec lui que le modèle en ligne est noté, et republié.
    calendrier, fallback = holidays.build_calendar(utc_day(now), online.get("calendrier", {}))
    if fallback:
        last = max((end for _, end in calendrier["vacances"]), default=0) // 1000
        log(f"::warning::Vacances scolaires reprises du modèle en ligne ({fallback}) ; dernières connues : jusqu'au {iso(last)}")
    if "calendrier" in online and online["calendrier"] != calendrier:
        online = {**online, "calendrier": calendrier}
        online_bytes = bundle.encode(online)

    incidents = []
    summary = []
    verdict = control.judge(online, check)
    summary += figures_table(f"Modèle en ligne ({online.get('version', 'illisible')})", verdict)
    candidate, candidate_verdict = None, None
    if online.get("version") == version_of(cut):
        log("Le modèle en ligne est déjà celui de cette semaine : pas de nouvel entraînement")
    else:
        try:
            described = stations.describe(grid, seed["stations"], online.get("stations", []), live_stations(args.relais))
            candidate, candidate_verdict = build_candidate(grid, cut_slot, check, calendrier, described, now)
        except TooEarly as exc:
            log(f"Pas de candidat cette semaine : {exc}")
        except Exception as exc:
            incidents.append(f"entraînement en échec ({type(exc).__name__} : {exc})")
    if candidate_verdict:
        summary += figures_table(f"Candidat ({candidate['version']})", candidate_verdict)

    choice = control.choose(candidate_verdict, verdict)
    if choice == "candidat":
        published = bundle.write(args.out, bundle.encode(candidate), now)
        summary.insert(0, f"Nouveau modèle publié : version {published['version']}, {published['taille']} octets.\n")
    elif choice == "en_ligne":
        published = bundle.write(args.out, online_bytes, now)
        summary.insert(0, f"Modèle {published['version']} conservé (calendrier à jour), contrôle rafraîchi.\n")
    else:
        summary.insert(0, "Aucun modèle n'a passé le contrôle : rien n'est publié.\n")
        # Avant toute publication, une amorce qui a vieilli n'est pas un incident tant qu'aucun candidat n'a pu être entraîné.
        if index is not None or candidate_verdict is not None:
            incidents.append("aucun modèle n'a passé le contrôle, rien n'est publié (défauts de chacun dans le résumé)")
    log("\n".join(summary))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as out:
            out.write("\n".join(summary) + "\n")
    return incidents


def main() -> int:
    parser = argparse.ArgumentParser(description="Réentraîne, contrôle et prépare la publication du modèle de prévision Vélo'v.")
    parser.add_argument("--relais", default=readings.RELAY_URL, help="adresse du relais qui garde les relevés")
    parser.add_argument("--en-ligne", help="dossier contenant index.json et modele.json actuellement publiés (absent avant la première publication)")
    parser.add_argument("--amorce", default=bundle.SEED_PATH, help="modèle d'amorce, tenu pour « en ligne » tant que rien n'est publié")
    parser.add_argument("--out", default="velov-prevision-out", help="dossier où écrire les fichiers à publier")
    parser.add_argument("--cache", help="dossier où garder les jours de relevés déjà lus, d'une exécution à l'autre (facultatif)")
    parser.add_argument("--planifie", action="store_true", help="exécution planifiée : ne rien faire si le dernier contrôle réussi est récent")
    parser.add_argument("--maintenant", help="date et heure UTC à tenir pour « maintenant » (essais), ex. 2026-10-27T13:00:00")
    args = parser.parse_args()
    now = int(dt.datetime.fromisoformat(args.maintenant).replace(tzinfo=dt.timezone.utc).timestamp()) if args.maintenant else int(time.time())
    incidents = run(args, now)
    for incident in incidents:
        log(f"::error::{incident}")
    return 1 if incidents else 0


if __name__ == "__main__":
    sys.exit(main())
