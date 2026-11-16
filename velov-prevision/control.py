"""
Contrôle d'un modèle sur la semaine la plus récente (jamais vue à l'entraînement) et garde-fous :
ce qui fait qu'un modèle est « bon », et lequel publier entre le candidat et celui déjà en ligne.

Les seuils viennent du contrôle de l'étude d'origine (20 au 27 octobre 2026 : fourchette 10-90
juste 79 à 87 fois sur 100, médiane meilleure que « comme maintenant » dès 2 h) et d'un rejeu du
robot à douze dates de 2026 sur les relevés de l'étude, vacances et rentrée comprises.
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
KINDS = (*reader.BIKES, reader.DOCKS)
LABELS = {"velos": "vélos", "elec": "vélos électriques", "meca": "vélos mécaniques", "bornes": "places"}
# Part des cas où la réalité doit tomber dans la fourchette 10-90, par sorte (80 en théorie, davantage
# quand les nombres sont petits : une fourchette en entiers déborde toujours un peu, et une station sans
# électrique en reste souvent là). PROVISOIRE, à régler sur le rejeu.
COVERAGE_RANGE = {"velos": (0.65, 0.95), "elec": (0.65, 0.99), "meca": (0.65, 0.99), "bornes": (0.65, 0.95)}
# Horizon (en heures) à partir duquel la médiane de chaque sorte doit battre « comme maintenant ». Avant,
# l'état présent est presque imbattable : la comparaison ne dirait rien de la santé du modèle. PROVISOIRE.
MEDIAN_BEATS_FROM = {"velos": 2, "elec": 2, "meca": 6, "bornes": 2}
# La probabilité d'en trouver au moins un doit, elle, battre « comme maintenant » dès 2 h pour toutes les sortes.
PROBABILITY_BEATS_FROM = 2
# Le candidat remplace le modèle en ligne tant que sa note n'est pas plus mauvaise de plus de 3 % :
# à qualité voisine, le plus récent connaît mieux le réseau du moment. Au rejeu, deux entraînements sur
# les mêmes semaines diffèrent de 0,5 %, et le modèle de la semaine fait 3 à 6 % de mieux que le précédent.
TOLERANCE = 0.03


def kind_figures(q: np.ndarray, levels: list[int], p1: np.ndarray, now: np.ndarray, actual: np.ndarray, xq: np.ndarray) -> dict:
    """Chiffres d'une sorte (vélos, électriques, mécaniques ou places) : une ligne par horizon, et la part
    moyenne des cas où la fourchette 10-90 a dit vrai, celle que l'application annonce (« N fois sur 10 »).
    `q` : déciles prévus aux niveaux `levels` ; `p1` : probabilité d'au moins un ; `now`, `actual` : nombre
    au départ et à l'heure visée."""
    low, low_mid, median, high_mid, high = (q[:, levels.index(k)] for k in (10, 30, 50, 70, 90))
    share = np.asarray(levels) / 100

    def pinball(forecast: np.ndarray) -> np.ndarray:
        # Perte « pinball » moyenne des déciles : juge à la fois la justesse et la finesse de la fourchette.
        gap = actual[:, None] - forecast
        return np.maximum(share * gap, (share - 1) * gap).mean(axis=1)

    per_row = {
        "err": np.abs(median - actual),
        "err_actuel": np.abs(now - actual),
        "couv80": (actual >= low) & (actual <= high),
        "couv40": (actual >= low_mid) & (actual <= high_mid),
        "brier": (p1 - (actual >= 1)) ** 2,
        "brier_actuel": ((now >= 1).astype(float) - (actual >= 1)) ** 2,
        "pinball": pinball(q),
        "pinball_actuel": pinball(now[:, None]),
    }
    horizons = []
    for quarters in np.unique(xq).tolist():
        at = xq == quarters
        horizons.append({"h": quarters * 0.25, "lignes": int(at.sum()), **{name: round(float(values[at].mean()), 4) for name, values in per_row.items()}})
    return {"couv80": round(float(np.mean([line["couv80"] for line in horizons])), 4), "horizons": horizons}


def figures(pred: dict, rows: dict, deciles: list[int]) -> dict[str, dict]:
    """Chiffres de qualité de chaque sorte, à partir des prévisions du lecteur et de ce qui s'est passé."""
    now = {**reader.bike_counts(rows["elec0"], rows["meca0"]), reader.DOCKS: rows["bornes0"]}
    actual = {**reader.bike_counts(rows["y_elec"], rows["y_meca"]), reader.DOCKS: rows["y_bornes"]}
    # Les déciles de places viennent de ceux des vélos pris à l'envers : leurs niveaux aussi.
    levels = {**dict.fromkeys(reader.BIKES, deciles), reader.DOCKS: [100 - k for k in reversed(deciles)]}
    return {kind: kind_figures(pred["q"][kind], levels[kind], pred["p1"][kind], now[kind], actual[kind], rows["xq"]) for kind in KINDS}


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


def model_defects(by_kind: dict[str, dict]) -> list[str]:
    """Ce qui fait qu'un modèle n'est pas « bon » sur sa semaine de contrôle ; liste vide s'il l'est."""
    defects = []
    for kind in KINDS:
        low, high = COVERAGE_RANGE[kind]
        for line in by_kind[kind]["horizons"]:
            horizon = f"à {line['h']:g} h"
            if not low <= line["couv80"] <= high:
                defects.append(f"fourchette 10-90 des {LABELS[kind]} juste {line['couv80']:.0%} du temps {horizon}")
            for name, label, first in (("err", "médiane", MEDIAN_BEATS_FROM[kind]), ("brier", "probabilité", PROBABILITY_BEATS_FROM)):
                if line["h"] >= first and line[name] >= line[f"{name}_actuel"]:
                    defects.append(f"{label} des {LABELS[kind]} pas meilleure que « comme maintenant » {horizon} ({line[name]} contre {line[f'{name}_actuel']})")
    return defects


@dataclass
class Verdict:
    """Jugement d'un modèle sur la semaine de contrôle."""
    figures: dict[str, dict]
    defects: list[str]

    @property
    def good(self) -> bool:
        return not self.defects

    @property
    def score(self) -> float:
        """Note unique pour comparer deux modèles sur la même semaine (plus bas = meilleur ; 1 = « comme
        maintenant »). Pour chaque sorte de vélos, la perte pinball du modèle rapportée à celle de « comme
        maintenant », sommées sur les horizons ; puis la moyenne des trois sortes, qui pèsent donc chacune
        un tiers quel que soit le nombre de vélos qu'elles comptent. Les places, déduites des vélos, n'ajoutent rien."""
        def relative(kind: str) -> float:
            horizons = self.figures[kind]["horizons"]
            return sum(line["pinball"] for line in horizons) / sum(line["pinball_actuel"] for line in horizons)

        return float(np.mean([relative(kind) for kind in reader.BIKES]))


def judge(bundle: dict, rows: dict) -> Verdict:
    """Note le fichier publiable `bundle` sur les lignes de contrôle, par le même chemin que les
    applications. Un fichier que le lecteur ne sait pas lire est un modèle défectueux, pas une panne."""
    try:
        by_kind = figures(reader.predict(bundle, rows), rows, list(bundle["deciles"]))
    except Exception as exc:
        return Verdict({}, [f"fichier illisible ({type(exc).__name__} : {exc})"])
    return Verdict(by_kind, model_defects(by_kind))


def choose(candidate: Verdict | None, published: Verdict | None) -> str | None:
    """Modèle à mettre en ligne : "candidat", "en_ligne" (inchangé, contrôle rafraîchi) ou None quand
    aucun n'est bon. Le candidat l'emporte s'il est bon et pas nettement moins bien noté."""
    if candidate and candidate.good and not (published and published.good and candidate.score > published.score * (1 + TOLERANCE)):
        return "candidat"
    return "en_ligne" if published and published.good else None
