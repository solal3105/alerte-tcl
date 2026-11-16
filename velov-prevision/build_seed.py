#!/usr/bin/env python3
"""
Construit le modèle d'amorce (`amorce/modele.json`) à partir des quatre fichiers du prototype
(modele.json, habitude.json, stations.json, calendrier.json) : le modèle tenu pour « en ligne » tant
que le robot n'a rien publié. À relancer seulement si l'amorce doit être refaite.

    python3 velov-prevision/build_seed.py <dossier du prototype> --version 2026-10-20 --controle controle.json
"""
from __future__ import annotations

import argparse
import json
import os
import time

import bundle


def main() -> None:
    parser = argparse.ArgumentParser(description="Modèle d'amorce de la prévision Vélo'v à partir des fichiers du prototype.")
    parser.add_argument("dossier", help="dossier contenant les quatre fichiers du prototype")
    parser.add_argument("--version", required=True, help="fin de l'entraînement du prototype (AAAA-MM-JJ)")
    parser.add_argument("--controle", required=True, help="fichier JSON des chiffres de contrôle du prototype")
    parser.add_argument("--out", default=bundle.SEED_PATH, help="fichier à écrire")
    args = parser.parse_args()

    def part(name: str) -> dict | list:
        with open(os.path.join(args.dossier, name), encoding="utf-8") as source:
            return json.load(source)

    with open(args.controle, encoding="utf-8") as source:
        controle = json.load(source)
    # Le calendrier du prototype s'arrête fin 2026 : le robot le remplace par celui du jour à chaque publication.
    seed = bundle.assemble(args.version, int(time.time()), part("modele.json"), part("habitude.json"), part("stations.json"), part("calendrier.json"), controle)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "wb") as out:
        out.write(bundle.encode(seed))
    print(f"{args.out} : {os.path.getsize(args.out)} octets")


if __name__ == "__main__":
    main()
