"""
Entraînement du modèle de prévision Vélo'v, selon la recette de l'étude d'origine (version légère,
celle que les applications évaluent elles-mêmes) : dix-neuf modèles LightGBM qui ne lisent que l'état
présent de la station, le calendrier de l'heure visée, l'habitude de la station et sa position.

Pour chaque sorte de vélos (`velos` tous, `elec` électriques, `meca` mécaniques) :
  <sorte>_q10 … <sorte>_q90   déciles de l'écart entre le nombre à l'heure visée et le nombre présent
  <sorte>_p1                  probabilité d'en trouver au moins un à l'heure visée
et `bornes_p1`, probabilité d'au moins une place libre.
"""
from __future__ import annotations

import lightgbm as lgb
import numpy as np

import reader
from readings import Grid

# Les cinq déciles qu'affichent les applications : fourchettes 10-90 et 30-70 autour de la médiane.
DECILES = (10, 30, 50, 70, 90)
# Horizons de 15 minutes à 24 heures, en quarts d'heure.
MAX_HORIZON = 96
# Horizons notés pendant la semaine de contrôle : 15 et 30 min, 1, 2, 3, 6, 12 et 24 h.
CONTROL_HORIZONS = (1, 2, 4, 8, 12, 24, 48, 96)
# Part des relevés d'entraînement tirés au sort, chacun avec un horizon au hasard.
SAMPLE = 0.5
# Blocs de temps pour l'habitude sans fuite : chaque ligne reçoit celle des trois autres blocs.
HABIT_BLOCKS = 4
# L'arrêt précoce se juge sur les 10 % les plus récents de l'entraînement.
VALIDATION_SHARE = 0.1
MAX_TREES = 300
EARLY_STOPPING = 30
PARAMS = dict(
    learning_rate=0.12, num_leaves=31, min_data_in_leaf=500, feature_fraction=0.8, bagging_fraction=0.8,
    bagging_freq=1, lambda_l2=1.0, num_threads=4, verbose=-1, seed=0, deterministic=True, force_row_wise=True,
)
VARIABLES = (
    "velos0", "elec0", "meca0", "bornes0", "capacite", "part_elec0", "horizon_h", "heure_origine", "heure_cible",
    "jour_sem", "mois", "ferie", "vacances", "type_jour", *reader.HABIT, *reader.GEO,
)
MISSING_TYPES = {"None": 0, "Zero": 1, "NaN": 2}


def pair_rows(grid: Grid, slot: np.ndarray, column: np.ndarray, xq: np.ndarray, last_target: int) -> dict:
    """Lignes (état de départ, état à l'heure visée) pour des départs valides ; ne garde que celles dont
    l'heure visée est relevée, valide et ne dépasse pas le quart d'heure `last_target`."""
    target = slot + xq
    keep = target <= last_target
    keep[keep] = grid.valid[target[keep], column[keep]]
    slot, column, xq, target = slot[keep], column[keep], xq[keep], target[keep]

    def at(values: np.ndarray, when: np.ndarray) -> np.ndarray:
        return values[when, column].astype(np.int64)

    return {
        "station": grid.stations[column], "t0": grid.start + slot * reader.STEP, "xq": xq,
        "elec0": at(grid.elec, slot), "meca0": at(grid.meca, slot), "bornes0": at(grid.bornes, slot),
        "capacite": at(grid.capacite, slot), "y_elec": at(grid.elec, target), "y_meca": at(grid.meca, target),
        "y_bornes": at(grid.bornes, target),
    }


def training_rows(grid: Grid, first_slot: int, cut_slot: int) -> dict:
    """Un relevé valide sur deux avant la coupure, chacun avec un horizon tiré au sort de 15 min à 24 h ;
    l'heure visée reste avant la coupure (la semaine de contrôle n'est jamais vue)."""
    slot, column = np.nonzero(grid.valid[first_slot:cut_slot])
    rng = np.random.default_rng(0)
    keep = rng.random(len(slot)) < SAMPLE
    slot, column = slot[keep] + first_slot, column[keep]
    return pair_rows(grid, slot, column, rng.integers(1, MAX_HORIZON + 1, len(slot)), cut_slot - 1)


def control_rows(grid: Grid, cut_slot: int) -> dict:
    """Chaque heure pleine valide depuis la coupure, aux huit horizons de contrôle."""
    slot, column = np.nonzero(grid.valid[cut_slot:])
    slot += cut_slot
    on_the_hour = (grid.start + slot * reader.STEP) % 3600 == 0
    slot, column = slot[on_the_hour], column[on_the_hour]
    xq = np.tile(CONTROL_HORIZONS, len(slot))
    return pair_rows(grid, np.repeat(slot, len(CONTROL_HORIZONS)), np.repeat(column, len(CONTROL_HORIZONS)), xq, len(grid.valid) - 1)


def take(rows: dict, keep: np.ndarray) -> dict:
    return {name: values[keep] for name, values in rows.items()}


def habit_table(rows: dict, type_jour: np.ndarray, hour: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Habitude par station, type de jour et heure visée : moyenne des vélos, fréquence d'au moins un vélo,
    d'au moins une place, part d'électriques. Arrondie comme dans le fichier publié, pour que l'entraînement
    voie les mêmes valeurs que les applications."""
    ids, rank = np.unique(rows["station"], return_inverse=True)
    size = len(ids) * reader.DAY_TYPES * 24
    cell = (rank * reader.DAY_TYPES + type_jour.astype(np.int64)) * 24 + hour.astype(np.int64)
    velos = reader.bike_counts(rows["y_elec"], rows["y_meca"])["velos"]
    with_bikes = velos > 0

    def mean(values: np.ndarray, among: np.ndarray | None = None) -> np.ndarray:
        cells = cell if among is None else cell[among]
        count = np.bincount(cells, minlength=size)
        with np.errstate(invalid="ignore"):
            return np.bincount(cells, weights=values, minlength=size) / np.where(count > 0, count, np.nan)

    table = np.stack([
        mean(velos), mean(velos >= 1), mean(rows["y_bornes"] >= 1),
        mean(rows["y_elec"][with_bikes] / velos[with_bikes], with_bikes),
    ], axis=1)
    return ids, np.round(table, 4).reshape(len(ids), reader.DAY_TYPES, 24, len(reader.HABIT))


def habit_json(habit: tuple[np.ndarray, np.ndarray]) -> dict:
    """Table d'habitude au format du fichier publié ; un créneau sans aucun relevé est omis."""
    ids, table = habit
    out = {}
    for station, by_day in zip(ids.tolist(), table):
        out[str(station)] = {
            f"{day_type}_{hour}": [None if np.isnan(v) else float(v) for v in values]
            for day_type, by_hour in enumerate(by_day) for hour, values in enumerate(by_hour)
            if not np.isnan(values[0])
        }
    return out


def significant(value: float) -> float:
    """Neuf chiffres significatifs : assez pour ne déplacer aucun seuil, trois fois moins de texte."""
    return float(f"{value:.9g}")


def tree_arrays(tree: dict) -> dict:
    """Arbre LightGBM aplati : pour chaque nœud la variable, le seuil, les drapeaux (bit 1 : valeur manquante
    à gauche, bits 2-3 : type de manquant 0 aucun, 1 zéro, 2 NaN) et les deux enfants ; un enfant négatif ~i
    désigne la feuille i."""
    f, s, d, g, r, leaves = [], [], [], [], [], []

    def visit(node: dict) -> int:
        if "leaf_value" in node:
            leaves.append(significant(node["leaf_value"]))
            return ~(len(leaves) - 1)
        if node["decision_type"] != "<=":
            raise ValueError("arbre à variable catégorielle : le lecteur ne sait pas l'évaluer")
        i = len(f)
        f.append(node["split_feature"])
        s.append(significant(node["threshold"]))
        d.append((2 if node["default_left"] else 0) | (MISSING_TYPES[node["missing_type"]] << 2))
        g.append(None)
        r.append(None)
        g[i] = visit(node["left_child"])
        r[i] = visit(node["right_child"])
        return i

    root = visit(tree["tree_structure"])
    return {"f": f, "s": s, "d": d, "g": g, "r": r, "v": leaves, "racine": root}


def forest_json(booster: lgb.Booster) -> dict:
    """Modèle LightGBM (arrêté à sa meilleure itération) au format du fichier publié."""
    dump = booster.dump_model(num_iteration=booster.best_iteration)
    return {"objectif": dump["objective"].split()[0], "arbres": [tree_arrays(tree) for tree in dump["tree_info"]]}


def train(rows: dict, stations: list[dict], calendrier: dict, log) -> tuple[dict, dict, dict[str, lgb.Booster]]:
    """Entraîne les dix-neuf modèles sur `rows` (lignes de `training_rows`). Rend les modèles et l'habitude au
    format publié, ainsi que les modèles LightGBM eux-mêmes pour la contre-vérification du lecteur."""
    cols = reader.variables(rows, stations, calendrier, None)
    type_jour, hour = reader.habit_slot(cols)
    target_time = rows["t0"] + rows["xq"] * reader.STEP
    # Habitude sans fuite : celle de chaque bloc de temps est calculée sur les autres blocs.
    block = np.empty(len(target_time), dtype=np.int64)
    block[np.argsort(target_time, kind="stable")] = np.arange(len(target_time)) * HABIT_BLOCKS // len(target_time)
    habits = np.empty((len(target_time), len(reader.HABIT)))
    for b in range(HABIT_BLOCKS):
        others = block != b
        table = habit_table(take(rows, others), type_jour[others], hour[others])
        habits[~others] = reader.habit_columns(table, rows["station"][~others], type_jour[~others], hour[~others])
    cols.update(zip(reader.HABIT, habits.T))
    x = np.column_stack([cols[name] for name in VARIABLES])
    validation = target_time >= np.quantile(target_time, 1 - VALIDATION_SHARE)

    def fit(name: str, target: np.ndarray, **params) -> lgb.Booster:
        def dataset(keep: np.ndarray) -> lgb.Dataset:
            return lgb.Dataset(x[keep], target[keep], feature_name=list(VARIABLES))

        booster = lgb.train(
            {**PARAMS, **params}, dataset(~validation), MAX_TREES, valid_sets=[dataset(validation)],
            callbacks=[lgb.early_stopping(EARLY_STOPPING, verbose=False)],
        )
        log(f"  {name} : {booster.best_iteration} arbres")
        return booster

    now, later = reader.bike_counts(rows["elec0"], rows["meca0"]), reader.bike_counts(rows["y_elec"], rows["y_meca"])
    boosters = {}
    for kind in reader.BIKES:
        # Quantiles appris sur l'écart à l'état actuel : à court terme la fourchette reste serrée autour du stock présent.
        delta = (later[kind] - now[kind]).astype(float)
        boosters.update({f"{kind}_q{k}": fit(f"{kind}_q{k}", delta, objective="quantile", alpha=k / 100) for k in DECILES})
        boosters[f"{kind}_p1"] = fit(f"{kind}_p1", (later[kind] >= 1).astype(float), objective="binary")
    boosters[f"{reader.DOCKS}_p1"] = fit(f"{reader.DOCKS}_p1", (rows["y_bornes"] >= 1).astype(float), objective="binary")
    modeles = {"variables": list(VARIABLES), "deciles": list(DECILES), "modeles": {name: forest_json(b) for name, b in boosters.items()}}
    return modeles, habit_json(habit_table(rows, type_jour, hour)), boosters


def reader_gap(bundle: dict, boosters: dict[str, lgb.Booster], rows: dict) -> float:
    """Plus grand écart, sur `rows`, entre le score brut que le lecteur tire du fichier publié et celui
    de LightGBM pour le même modèle : la preuve que l'export et le lecteur disent la même chose."""
    cols = reader.columns(bundle, rows)
    scores = reader.raw_scores(bundle, cols)
    x = np.column_stack(cols)
    return max(float(np.abs(scores[name] - booster.predict(x, raw_score=True)).max()) for name, booster in boosters.items())
