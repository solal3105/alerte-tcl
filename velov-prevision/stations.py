"""
Stations publiées avec le modèle : nom, capacité, position et repères géographiques (altitude,
distance au métro, au tram, à la gare), ces derniers relevés une fois pour toutes par l'étude d'origine.

Une station apparue depuis n'a pas ces repères. Sa position vient du relais ; son altitude et ses
distances sont reprises de la station connue la plus proche si elle est à moins de 500 m (l'erreur
sur une distance ne peut alors pas dépasser 500 m), sinon laissées inconnues : la clé est omise du
fichier, l'application et LightGBM la traitent comme une valeur manquante.
"""
from __future__ import annotations

import math

import numpy as np

from readings import Grid

SURVEYED = ("altitude", "dist_metro_km", "dist_tram_km", "dist_gare_km")
NEIGHBOUR_KM = 0.5
EARTH_KM = 6371


def distance_km(a: dict, b: dict) -> float:
    """Distance à plat, suffisante à l'échelle de l'agglomération."""
    x = math.radians(a["lon"] - b["lon"]) * math.cos(math.radians(45.76))
    return math.hypot(x, math.radians(a["lat"] - b["lat"])) * EARTH_KM


def display_name(raw: str) -> str:
    """« 10039 - BOUVIER » → « Bouvier », comme les noms du prototype."""
    return raw.split(" - ", 1)[-1].title()


def new_station(live: dict, surveyed: list[dict]) -> dict:
    """Fiche d'une station inconnue de l'étude d'origine, à partir de ce qu'en dit le relais (`/velov`)."""
    entry = {"id": live["id"], "nom": display_name(live["name"]), "commune": "", "lat": live["lat"], "lon": live["lng"]}
    nearest = min(surveyed, key=lambda s: distance_km(s, entry), default=None)
    if nearest and distance_km(nearest, entry) <= NEIGHBOUR_KM:
        entry.update({key: nearest[key] for key in SURVEYED})
    return entry


def describe(grid: Grid, surveyed: list[dict], published: list[dict], live: list[dict]) -> list[dict]:
    """Fiches des stations relevées. Dans l'ordre de confiance : l'étude d'origine (`surveyed`), ce que le
    relais annonce aujourd'hui (`live`), sinon la fiche du modèle en ligne ; une station dont on ne sait
    rien est omise (toutes ses variables géographiques seront manquantes). La capacité est la dernière relevée."""
    known = {s["id"]: s for s in published}
    known.update({s["id"]: new_station(s, surveyed) for s in live})
    known.update({s["id"]: s for s in surveyed})
    last_seen = len(grid.present) - 1 - np.argmax(grid.present[::-1], axis=0)
    capacities = grid.capacite[last_seen, np.arange(len(grid.stations))]
    return [
        {**known[station], "cap": capacity}
        for station, capacity in zip(grid.stations.tolist(), capacities.tolist()) if station in known
    ]
