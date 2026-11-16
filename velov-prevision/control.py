"""
Contrôle d'un modèle sur la semaine la plus récente (jamais vue à l'entraînement) et garde-fous :
ce qui fait qu'un modèle est « bon », et lequel publier entre le candidat et celui déjà en ligne.

Les seuils viennent du contrôle de l'étude d'origine (20 au 27 octobre 2026 : fourchette 10-90
juste 79 à 87 fois sur 100, médiane meilleure que « comme maintenant » dès 2 h) et d'un rejeu du
robot à treize dates de 2026 sur les relevés de l'étude, vacances et rentrée comprises.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

import reader

# Semaine de contrôle exploitable : assez d'heures de départ, de stations et de lignes par horizon.
# Une semaine complète donne 168 heures, environ 450 stations et 75 000 lignes par horizon.
MIN_HOURS = 120
MIN_STATIONS = 300
MIN_ROWS = 20_000
# Part des cas où la réalité doit tomber dans la fourchette 10-90, pour les vélos comme pour les places
# (80 en théorie, un peu plus à court terme parce que les vélos se comptent en entiers). Au rejeu, un
# modèle frais reste entre 71 et 89 % toute l'année ; le plus bas est la semaine de la rentrée, quand il
# n'a vu que l'été. Plus étroit, le seuil ferait échouer cette semaine-là le meilleur modèle disponible.
COVERAGE_RANGE = (0.65, 0.95)
# À partir de cet horizon (en heures), la médiane et les deux probabilités doivent battre « comme
# maintenant ». Avant, l'état présent est presque imbattable (à 15 min la médiane de l'étude fait
# 1,29 vélo d'erreur contre 0,88) : la comparaison ne dirait rien de la santé du modèle.
BEATS_PERSISTENCE_FROM = 2
# Le candidat remplace le modèle en ligne tant que sa note n'est pas plus mauvaise de plus de 3 % :
# à qualité voisine, le plus récent connaît mieux le réseau du moment. Au rejeu, deux entraînements sur
# les mêmes semaines diffèrent de 0,5 %, et le modèle de la semaine fait 3 à 6 % de mieux que le précédent.
TOLERANCE = 0.03


def horizon_figures(pred: dict, rows: dict, deciles: list[int]) -> list[dict]:
    """Chiffres de qualité par horizon, à partir des prévisions du lecteur et de ce qui s'est passé."""
    q = pred["q"]
    low, low_mid, median, high_mid, high = (q[:, deciles.index(k)] for k in (10, 30, 50, 70, 90))
    velos0 = rows["elec0"] + rows["meca0"]
    velos, places = rows["y_velos"], rows["y_bornes"]
    capacite = np.maximum(1, rows["capacite"])
    levels = np.asarray(deciles) / 100

    def free_docks(bikes: np.ndarray) -> np.ndarray:
        # Places libres que l'application déduit d'un décile de vélos : ce qui n'est pas vélo est place.
        return np.clip(rows["bornes0"] + velos0 - bikes, 0, capacite)

    gap = velos[:, None] - q
    per_row = {
        "err": np.abs(median - velos),
        "err_actuel": np.abs(velos0 - velos),
        "couv80": (velos >= low) & (velos <= high),
        "couv40": (velos >= low_mid) & (velos <= high_mid),
        "couv80_places": (places >= free_docks(high)) & (places <= free_docks(low)),
        "couv40_places": (places >= free_docks(high_mid)) & (places <= free_docks(low_mid)),
        "brier": (pred["p_velo"] - (velos >= 1)) ** 2,
        "brier_actuel": ((velos0 >= 1).astype(float) - (velos >= 1)) ** 2,
        "brier_place": (pred["p_place"] - (places >= 1)) ** 2,
        "brier_place_actuel": ((rows["bornes0"] >= 1).astype(float) - (places >= 1)) ** 2,
        # Perte « pinball » moyenne des neuf déciles : juge à la fois la justesse et la finesse de la fourchette.
        "pinball": np.maximum(levels * gap, (levels - 1) * gap).mean(axis=1),
    }
    part = np.abs(pred["part_elec"] - rows["y_elec"] / np.maximum(velos, 1))
    figures = []
    for xq in np.unique(rows["xq"]).tolist():
        at = rows["xq"] == xq
        line = {"h": xq * 0.25, "lignes": int(at.sum())}
        line.update({name: round(float(values[at].mean()), 4) for name, values in per_row.items()})
        # Part d'électriques : erreur pondérée par les vélos présents (sans vélo, la part n'a pas de sens).
        line["err_part_elec"] = round(float(np.average(part[at], weights=velos[at])), 4) if velos[at].any() else None
        figures.append(line)
    return figures


def week_defects(rows: dict) -> list[str]:
    """Ce qui empêche de juger un modèle sur ces lignes de contrôle (relais en panne, semaine trouée)."""
    defects = []
    hours = len(np.unique(rows["t0"]))
    stations = len(np.unique(rows["station"]))
    if hours < MIN_HOURS:
        defects.append(f"{hours} heures de départ relevées, il en faut {MIN_HOURS}")
    if stations < MIN_STATIONS:
        defects.append(f"{stations} stations relevées, il en faut {MIN_STATIONS}")
    thinnest = min((int((rows["xq"] == xq).sum()) for xq in np.unique(rows["xq"])), default=0)
    if thinnest < MIN_ROWS:
        defects.append(f"{thinnest} lignes pour l'horizon le moins fourni, il en faut {MIN_ROWS}")
    return defects


def model_defects(figures: list[dict]) -> list[str]:
    """Ce qui fait qu'un modèle n'est pas « bon » sur sa semaine de contrôle ; liste vide s'il l'est."""
    defects = []
    for line in figures:
        horizon = f"à {line['h']:g} h"
        for name, label in (("couv80", "vélos"), ("couv80_places", "places")):
            if not COVERAGE_RANGE[0] <= line[name] <= COVERAGE_RANGE[1]:
                defects.append(f"fourchette 10-90 des {label} juste {line[name]:.0%} du temps {horizon}")
        if line["h"] >= BEATS_PERSISTENCE_FROM:
            for name, label in (("err", "médiane"), ("brier", "probabilité d'un vélo"), ("brier_place", "probabilité d'une place")):
                if line[name] >= line[f"{name}_actuel"]:
                    defects.append(f"{label} pas meilleure que « comme maintenant » {horizon} ({line[name]} contre {line[f'{name}_actuel']})")
    return defects


@dataclass
class Verdict:
    """Jugement d'un modèle sur la semaine de contrôle."""
    figures: list[dict]
    defects: list[str]

    @property
    def good(self) -> bool:
        return not self.defects

    @property
    def score(self) -> float:
        """Note unique pour comparer deux modèles sur la même semaine (plus bas = meilleur)."""
        return float(np.mean([line["pinball"] for line in self.figures]))


def judge(bundle: dict, rows: dict) -> Verdict:
    """Note le fichier publiable `bundle` sur les lignes de contrôle, par le même chemin que les
    applications. Un fichier que le lecteur ne sait pas lire est un modèle défectueux, pas une panne."""
    try:
        figures = horizon_figures(reader.predict(bundle, rows), rows, list(bundle["deciles"]))
    except Exception as exc:
        return Verdict([], [f"fichier illisible ({type(exc).__name__} : {exc})"])
    return Verdict(figures, model_defects(figures))


def choose(candidate: Verdict | None, published: Verdict | None) -> str | None:
    """Modèle à mettre en ligne : "candidat", "en_ligne" (inchangé, contrôle rafraîchi) ou None quand
    aucun n'est bon. Le candidat l'emporte s'il est bon et pas nettement moins bien noté."""
    if candidate and candidate.good and not (published and published.good and candidate.score > published.score * (1 + TOLERANCE)):
        return "candidat"
    return "en_ligne" if published and published.good else None
