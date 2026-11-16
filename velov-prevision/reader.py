"""
Jumeau Python du lecteur des applications : à partir de l'état d'une station et du fichier
`modele.json`, calcule les mêmes variables et parcourt les mêmes arbres que le module partagé.

C'est par lui que le robot note un modèle : ce qui est contrôlé est exactement ce que
l'application calculera, pas ce que LightGBM a en mémoire. Aucune dépendance hors numpy.
"""
from __future__ import annotations

import datetime as dt
import os
from concurrent.futures import ThreadPoolExecutor
from zoneinfo import ZoneInfo

import numpy as np

# Pas de la grille de relevés : un quart d'heure, en secondes.
STEP = 900
PARIS = ZoneInfo("Europe/Paris")
GEO = ("altitude", "dist_metro_km", "dist_tram_km", "dist_gare_km", "lat", "lon")
HABIT = ("hab_velos", "hab1_velos", "hab1_bornes", "hab_part_elec")
# Types de jour : 0 semaine, 1 samedi, 2 dimanche ou férié.
DAY_TYPES = 3
PROBABILITIES = ("binary", "cross_entropy")


def calendar_columns(t: np.ndarray, calendrier: dict) -> dict[str, np.ndarray]:
    """Calendrier, à l'heure de Lyon, des instants `t` (secondes epoch)."""
    feries = set(calendrier["feries"])
    vacances = np.asarray(calendrier["vacances"], dtype=np.int64).reshape(-1, 2)
    instants, back = np.unique(t, return_inverse=True)
    table = np.empty((len(instants), 6))
    for i, seconds in enumerate(instants.tolist()):
        local = dt.datetime.fromtimestamp(seconds, PARIS)
        weekday = local.isoweekday()
        ferie = local.date().isoformat() in feries
        ms = seconds * 1000
        table[i] = (
            local.hour + local.minute / 60, weekday, local.month, ferie,
            bool(((vacances[:, 0] <= ms) & (ms < vacances[:, 1])).any()),
            2 if ferie or weekday == 7 else 1 if weekday == 6 else 0,
        )
    heure, jour_sem, mois, ferie, vac, type_jour = table[back].T
    return {"heure": heure, "jour_sem": jour_sem, "mois": mois, "ferie": ferie, "vacances": vac, "type_jour": type_jour}


def parse_habit(habitude: dict) -> tuple[np.ndarray, np.ndarray]:
    """Habitude du fichier (`{"station": {"type_heure": [4 moyennes]}}`) en table dense :
    identifiants triés et valeurs [station, type de jour, heure, moyenne], NaN faute de relevés."""
    ids = np.array(sorted(int(k) for k in habitude), dtype=np.int64)
    table = np.full((len(ids), DAY_TYPES, 24, len(HABIT)), np.nan)
    for i, station in enumerate(ids.tolist()):
        for key, values in habitude[str(station)].items():
            day_type, hour = key.split("_")
            table[i, int(day_type), int(hour)] = [np.nan if v is None else v for v in values]
    return ids, table


def station_rank(ids: np.ndarray, station: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Rang de chaque station dans `ids` (triés) et masque de celles qui s'y trouvent."""
    if not len(ids):
        return np.zeros(len(station), dtype=np.int64), np.zeros(len(station), dtype=bool)
    rank = np.minimum(np.searchsorted(ids, station), len(ids) - 1)
    return rank, ids[rank] == station


def habit_slot(cols: dict[str, np.ndarray]) -> tuple[np.ndarray, np.ndarray]:
    """Créneau d'habitude que lit chaque ligne : type de jour et heure (de Lyon) de l'heure visée."""
    return cols["type_jour"], np.floor(cols["heure_cible"])


def habit_columns(habit: tuple[np.ndarray, np.ndarray], station: np.ndarray, type_jour: np.ndarray, hour: np.ndarray) -> np.ndarray:
    """Les quatre moyennes habituelles de chaque ligne, NaN pour une station ou un créneau inconnu."""
    ids, table = habit
    rank, known = station_rank(ids, station)
    out = np.full((len(station), len(HABIT)), np.nan)
    out[known] = table[rank[known], type_jour[known].astype(np.int64), hour[known].astype(np.int64)]
    return out


def geo_columns(stations: list[dict], station: np.ndarray) -> np.ndarray:
    """Repères géographiques de chaque ligne ; NaN pour une station absente ou un repère inconnu."""
    by_id = sorted(stations, key=lambda s: s["id"])
    ids = np.array([s["id"] for s in by_id], dtype=np.int64)
    table = np.array([[np.nan if s.get(g) is None else s[g] for g in GEO] for s in by_id], dtype=float).reshape(-1, len(GEO))
    rank, known = station_rank(ids, station)
    out = np.full((len(station), len(GEO)), np.nan)
    out[known] = table[rank[known]]
    return out


def variables(rows: dict, stations: list[dict], calendrier: dict, habit: tuple[np.ndarray, np.ndarray] | None) -> dict[str, np.ndarray]:
    """Variables du modèle pour chaque ligne (station, t0, xq, elec0, meca0, bornes0, capacite).
    Sans `habit`, les colonnes d'habitude restent à remplir (entraînement, voir training.py)."""
    velos0 = rows["elec0"] + rows["meca0"]
    origine = calendar_columns(rows["t0"], calendrier)
    cible = calendar_columns(rows["t0"] + rows["xq"] * STEP, calendrier)
    with np.errstate(invalid="ignore", divide="ignore"):
        part_elec0 = np.where(velos0 > 0, rows["elec0"] / velos0, np.nan)
    cols = {
        "velos0": velos0, "elec0": rows["elec0"], "meca0": rows["meca0"], "bornes0": rows["bornes0"],
        "capacite": rows["capacite"], "part_elec0": part_elec0, "horizon_h": rows["xq"] * 0.25,
        "heure_origine": origine["heure"], "heure_cible": cible["heure"], "jour_sem": cible["jour_sem"],
        "mois": cible["mois"], "ferie": cible["ferie"], "vacances": cible["vacances"], "type_jour": cible["type_jour"],
    }
    if habit is not None:
        cols.update(zip(HABIT, habit_columns(habit, rows["station"], *habit_slot(cols)).T))
    cols.update(zip(GEO, geo_columns(stations, rows["station"]).T))
    return {name: np.ascontiguousarray(col, dtype=float) for name, col in cols.items()}


def tree_values(tree: dict, cols: list[np.ndarray], has_nan: list[bool], out: np.ndarray) -> None:
    """Ajoute à `out` la feuille atteinte par chaque ligne, en suivant les règles de LightGBM
    pour les valeurs manquantes (drapeaux `d` : bit 1 manquant à gauche, bits 2-3 nature du manquant)."""
    pending = [(tree["racine"], None)]
    while pending:
        node, rows = pending.pop()
        if node < 0:
            if rows is None:
                out += tree["v"][~node]
            else:
                out[rows] += tree["v"][~node]
            continue
        feature, threshold, flags = tree["f"][node], tree["s"][node], tree["d"][node]
        x = cols[feature] if rows is None else cols[feature][rows]
        missing, default_left = (flags >> 2) & 3, bool(flags & 2)
        left = x <= threshold
        if missing == 1:
            # Zéro (ou NaN, ramené à zéro) tient lieu de valeur manquante.
            left = np.where(np.isnan(x) | (np.abs(x) <= 1e-35), default_left, left)
        elif has_nan[feature] and (default_left if missing == 2 else 0 <= threshold):
            # NaN : côté par défaut si l'arbre a appris avec des NaN, sinon traité comme zéro.
            left |= np.isnan(x)
        index = np.flatnonzero(left) if rows is None else rows[left]
        other = np.flatnonzero(~left) if rows is None else rows[~left]
        pending.append((tree["g"][node], index))
        pending.append((tree["r"][node], other))


def forest_values(forest: dict, cols: list[np.ndarray], has_nan: list[bool]) -> np.ndarray:
    """Somme des feuilles de tous les arbres d'un modèle (score brut, avant sigmoïde)."""
    out = np.zeros(len(cols[0]))
    for tree in forest["arbres"]:
        tree_values(tree, cols, has_nan, out)
    return out


def columns(bundle: dict, rows: dict) -> list[np.ndarray]:
    """Variables de chaque ligne, dans l'ordre où les arbres du fichier les numérotent."""
    by_name = variables(rows, bundle["stations"], bundle["calendrier"], parse_habit(bundle["habitude"]))
    return [by_name[name] for name in bundle["variables"]]


def raw_scores(bundle: dict, cols: list[np.ndarray]) -> dict[str, np.ndarray]:
    """Score brut de chaque modèle du fichier pour chaque ligne ; les modèles sont évalués en parallèle
    (numpy relâche le verrou de l'interpréteur sur les grands tableaux)."""
    has_nan = [bool(np.isnan(col).any()) for col in cols]
    names = list(bundle["modeles"])
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 1) as pool:
        scores = pool.map(lambda name: forest_values(bundle["modeles"][name], cols, has_nan), names)
        return dict(zip(names, scores))


def predict(bundle: dict, rows: dict) -> dict[str, np.ndarray]:
    """Prévision de chaque ligne, comme l'application : déciles de vélos triés et bornés à la capacité
    (`q`, une colonne par décile), probabilité d'au moins un vélo, d'au moins une place, part d'électriques."""
    scores = raw_scores(bundle, columns(bundle, rows))

    def value(name: str) -> np.ndarray:
        raw = scores[name]
        return 1 / (1 + np.exp(-raw)) if bundle["modeles"][name]["objectif"] in PROBABILITIES else raw

    velos0 = rows["elec0"] + rows["meca0"]
    q = np.sort(np.column_stack([value(f"velos_q{k}") + velos0 for k in bundle["deciles"]]), axis=1)
    return {
        "q": np.clip(q, 0, np.maximum(1, rows["capacite"])[:, None]),
        "p_velo": value("velos_p1"), "p_place": value("bornes_p1"), "part_elec": value("part_elec"),
    }
