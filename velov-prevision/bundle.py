"""
Fichiers publiés sur la branche `velov-prevision` et lus par les applications à travers le relais
(format 1, décrit dans README.md) : `modele.json`, tout ce qu'il faut pour prévoir sans réseau, et
`index.json`, qui dit quel modèle est en ligne et quand le robot l'a contrôlé pour la dernière fois.
"""
from __future__ import annotations

import json
import os

FORMAT = 1
MODEL_FILE = "modele.json"
INDEX_FILE = "index.json"
# Modèle tenu pour « en ligne » tant que le robot n'a rien publié (voir build_seed.py).
SEED_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "amorce", MODEL_FILE)


def assemble(version: str, generated: int, modeles: dict, habitude: dict, stations: list[dict], calendrier: dict, controle: dict) -> dict:
    """Réunit en un seul fichier les quatre parties que lit l'application (`modeles` porte les variables,
    les déciles et les arbres) et le contrôle du modèle. `version` change à chaque nouveau modèle."""
    return {
        "format": FORMAT, "version": version, "genere": generated, **modeles,
        "habitude": habitude, "stations": stations, "calendrier": calendrier, "controle": controle,
    }


def encode(document: dict) -> bytes:
    return json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def read_published(folder: str | None) -> tuple[dict | None, bytes | None]:
    """Index et modèle actuellement en ligne (copie locale de la branche). (None, None) avant la première
    publication, ou si l'index est inutilisable : le robot repart alors de l'amorce, comme au premier jour."""
    try:
        with open(os.path.join(folder or "", INDEX_FILE), "rb") as source:
            index = json.load(source)
        with open(os.path.join(folder or "", MODEL_FILE), "rb") as source:
            model = source.read()
        return (index, model) if isinstance(index["version"], str) and isinstance(index["verifie"], int) else (None, None)
    except (OSError, ValueError, KeyError, TypeError):
        return None, None


def write(folder: str, model: bytes, verified: int) -> dict:
    """Écrit les deux fichiers à publier ; `verified` est l'heure du contrôle qui vient de réussir."""
    described = json.loads(model)
    index = {"format": FORMAT, "version": described["version"], "genere": described["genere"], "verifie": verified, "taille": len(model)}
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, MODEL_FILE), "wb") as out:
        out.write(model)
    with open(os.path.join(folder, INDEX_FILE), "wb") as out:
        out.write(encode(index))
    return index
