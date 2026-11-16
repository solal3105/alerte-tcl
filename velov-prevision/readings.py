"""
Relevés des stations Vélo'v : lecture auprès du relais (jamais chez Grand Lyon directement),
mise sur une grille au quart d'heure et repérage des périodes où une station est figée.

Les règles sont celles de l'étude d'origine : dans chaque quart d'heure (UTC) on garde le dernier
relevé de la station, sa plus grande capacité, et elle n'est ouverte que si elle l'est à chaque relevé.
"""
from __future__ import annotations

import datetime as dt
import gzip
import json
import os
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass

import numpy as np

from reader import STEP

RELAY_URL = "https://tcl-proxy.solalgendrin.workers.dev"
# Le relais refuse tout appelant dont le User-Agent ne commence pas par « AlerteTCL/ ».
USER_AGENT = "AlerteTCL/velov-prevision"
FIELDS = ("id", "elec", "meca", "places", "capacite", "ouvert")
# Attentes entre deux essais d'une même requête (secondes) : le relais a le temps de se remettre.
RETRY_DELAYS = (2, 8, 30, 90)
# Jours illisibles de suite au-delà desquels la lecture s'arrête (chaque jour a déjà eu tous ses essais).
MAX_FAILED_DAYS = 3
HOUR = 3600
DAY = 86_400
# Délai après minuit UTC au bout duquel un jour passé ne change plus (le relais le fige après dix minutes).
DAY_SETTLED_AFTER = HOUR
CACHE_SUFFIX = ".json.gz"
# Une station dont le nombre de vélos ne bouge pas pendant autant d'heures ouvertes d'affilée est
# figée (capteur en panne, station hors service non déclarée) : ses relevés n'apprennent rien.
FROZEN_HOURS = 48


def fetch(base_url: str, path: str, wait=time.sleep) -> bytes:
    """GET sur le relais, avec quelques essais espacés ; la réponse peut être compressée."""
    request = urllib.request.Request(base_url.rstrip("/") + path, headers={"User-Agent": USER_AGENT, "Accept-Encoding": "gzip"})
    for delay in (*RETRY_DELAYS, None):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                body = response.read()
                return gzip.decompress(body) if response.headers.get("Content-Encoding") == "gzip" else body
        except Exception:
            if delay is None:
                raise
            wait(delay)


def fetch_json(base_url: str, path: str, wait=time.sleep):
    return json.loads(fetch(base_url, path, wait))


def stack(blocks: list[np.ndarray]) -> np.ndarray:
    """Réunit des blocs de lignes [t, id, elec, meca, places, capacite, ouvert] ; aucun bloc, aucune ligne."""
    return np.concatenate(blocks) if blocks else np.empty((0, 1 + len(FIELDS)), dtype=np.int64)


def day_table(document: dict) -> np.ndarray:
    """Relevés d'un jour (réponse de `/velov-releves?jour=`) en lignes [t, id, elec, meca, places, capacite, ouvert].
    Les colonnes sont retrouvées par leur nom ; un relevé mal formé est ignoré."""
    order = [document["champs"].index(field) for field in FIELDS]
    blocks = []
    for snapshot in document["releves"]:
        try:
            stations = np.asarray(snapshot["stations"], dtype=np.int64)[:, order]
            blocks.append(np.column_stack([np.full(len(stations), int(snapshot["t"])), stations]))
        except (IndexError, KeyError, TypeError, ValueError):
            continue
    return stack(blocks)


def day_readings(base_url: str, day: str, now: int, cache: str | None) -> np.ndarray:
    """Relevés d'un jour UTC. Un jour terminé ne change plus : s'il est déjà dans le dossier `cache`, le
    relais n'est pas sollicité ; sinon il y est rangé tel que le relais l'a rendu, pour les fois suivantes.
    Une copie abîmée est simplement relue au relais."""
    copy = os.path.join(cache, day + CACHE_SUFFIX) if cache else None
    if copy and os.path.exists(copy):
        try:
            with gzip.open(copy) as source:
                return day_table(json.load(source))
        except Exception:
            pass
    body = fetch(base_url, "/velov-releves?" + urllib.parse.urlencode({"jour": day}))
    table = day_table(json.loads(body))
    settled = dt.datetime.fromisoformat(day).replace(tzinfo=dt.timezone.utc).timestamp() + DAY + DAY_SETTLED_AFTER
    if copy and len(table) and now >= settled:
        os.makedirs(cache, exist_ok=True)
        with gzip.open(copy + ".tmp", "wb") as out:
            out.write(body)
        os.replace(copy + ".tmp", copy)
    return table


def download(base_url: str, first_day: dt.date, now: int, cache: str | None, log) -> np.ndarray:
    """Tous les relevés depuis `first_day`, un jour après l'autre (jamais deux requêtes à la fois) : ceux
    qu'annonce le relais et ceux déjà gardés dans `cache` (facultatif), d'où sortent les jours plus anciens.
    Un jour illisible est sauté : les garde-fous jugeront s'il en reste assez. Après MAX_FAILED_DAYS jours
    illisibles de suite, le relais est tenu pour en panne et laissé tranquille."""
    kept = {name[:-len(CACHE_SUFFIX)] for name in (os.listdir(cache) if cache and os.path.isdir(cache) else []) if name.endswith(CACHE_SUFFIX)}
    for day in sorted(kept):
        if day < first_day.isoformat():
            os.remove(os.path.join(cache, day + CACHE_SUFFIX))
    days = sorted(day for day in kept.union(fetch_json(base_url, "/velov-releves")["jours"]) if day >= first_day.isoformat())
    tables, failed_in_a_row = [], 0
    for day in days:
        try:
            tables.append(day_readings(base_url, day, now, cache))
            failed_in_a_row = 0
        except Exception as exc:
            log(f"  {day} : illisible ({exc})")
            failed_in_a_row += 1
            if failed_in_a_row == MAX_FAILED_DAYS:
                raise
    log(f"  {len(tables)} jour(s) lus sur {len(days)}, dont {len(kept.intersection(days))} déjà gardé(s)")
    return stack(tables)


@dataclass
class Grid:
    """État de chaque station à chaque quart d'heure. Tableaux [quart d'heure, station]."""
    start: int               # début du premier quart d'heure (secondes epoch)
    stations: np.ndarray     # identifiants triés
    elec: np.ndarray
    meca: np.ndarray
    bornes: np.ndarray
    capacite: np.ndarray
    present: np.ndarray      # au moins un relevé dans le quart d'heure
    valid: np.ndarray        # relevé exploitable : station ouverte, capacité connue, pas figée

    @property
    def end(self) -> int:
        """Fin du dernier quart d'heure relevé (secondes epoch)."""
        return self.start + len(self.present) * STEP


def group_starts(*keys: np.ndarray) -> np.ndarray:
    """Rang du premier élément de chaque groupe de lignes consécutives aux mêmes clés."""
    changed = np.zeros(len(keys[0]), dtype=bool)
    changed[:1] = True
    for key in keys:
        changed[1:] |= key[1:] != key[:-1]
    return np.flatnonzero(changed)


def frozen_periods(station: np.ndarray, t: np.ndarray, velos: np.ndarray, ouvert: np.ndarray) -> list[tuple[int, int, int]]:
    """Périodes figées (station, première heure, dernière heure ; heures UTC en secondes epoch) à partir
    des relevés triés par station puis par heure. Une heure est immobile si la station y est ouverte à
    chaque relevé et qu'aucun relevé n'y change le nombre de vélos ; les heures fermées ou sans relevé
    ne comptent pas et n'interrompent pas la série."""
    moved = np.zeros(len(t), dtype=bool)
    moved[1:] = (velos[1:] != velos[:-1]) & (station[1:] == station[:-1])
    hour = t // HOUR
    starts = group_starts(station, hour)
    open_hours = np.minimum.reduceat(ouvert, starts) > 0
    h_station, h_hour = station[starts][open_hours], hour[starts][open_hours]
    still = np.maximum.reduceat(moved, starts)[open_hours] == 0
    # Numéro de série : il change à chaque heure qui bouge et à chaque changement de station.
    series = np.cumsum(~still | (h_station != np.roll(h_station, 1)))
    rank = np.flatnonzero(still)
    firsts = group_starts(series[rank])
    lasts = np.append(firsts[1:], len(rank)) - 1
    return [
        (int(h_station[rank[first]]), int(h_hour[rank[first]]) * HOUR, int(h_hour[rank[last]]) * HOUR)
        for first, last in zip(firsts, lasts) if last - first + 1 >= FROZEN_HOURS
    ]


def build_grid(table: np.ndarray) -> Grid | None:
    """Grille au quart d'heure de tous les relevés (lignes de `day_table`), None s'il n'y en a aucun."""
    if not len(table):
        return None
    table = table[np.lexsort((table[:, 0], table[:, 1]))]
    t, station, elec, meca, places, capacite, ouvert = table.T
    slot = t // STEP
    starts = group_starts(station, slot)
    last = np.append(starts[1:], len(t)) - 1
    stations = np.unique(station)
    first_slot = int(slot.min())
    shape = (int(slot.max()) - first_slot + 1, len(stations))
    cell = (slot[starts] - first_slot, np.searchsorted(stations, station[starts]))

    def spread(values: np.ndarray) -> np.ndarray:
        out = np.zeros(shape, dtype=np.int16)
        out[cell] = np.clip(values, 0, np.iinfo(np.int16).max)
        return out

    grid = Grid(
        start=first_slot * STEP, stations=stations,
        elec=spread(elec[last]), meca=spread(meca[last]), bornes=spread(places[last]),
        capacite=spread(np.maximum.reduceat(capacite, starts)),
        present=np.zeros(shape, dtype=bool), valid=np.zeros(shape, dtype=bool),
    )
    grid.present[cell] = True
    grid.valid[cell] = (np.minimum.reduceat(ouvert, starts) > 0) & (grid.capacite[cell] > 0)
    # Une période figée invalide ses quarts d'heure, jusqu'à une heure après sa dernière heure incluse.
    for frozen_station, first_hour, last_hour in frozen_periods(station, t, elec + meca, ouvert):
        column = np.searchsorted(stations, frozen_station)
        begin = max(0, first_hour // STEP - first_slot)
        grid.valid[begin:(last_hour + HOUR) // STEP - first_slot + 1, column] = False
    return grid
