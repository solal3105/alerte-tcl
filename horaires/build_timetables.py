#!/usr/bin/env python3
"""
Construit les fiches horaires théoriques du réseau TCL à partir du GTFS SYTRAL.

Entrée  : l'archive GTFS (URL data.gouv.fr par défaut, ou un fichier local).
Sortie  : un dossier de fichiers JSON compacts, servis par le proxy Cloudflare
          sous /horaires/... et lus tels quels par les applications iOS et Android.

    index.json                 liste des lignes, de leurs sens et de la période couverte
    lignes/<CLE>/<A|R>.json    tous les passages d'une ligne dans un sens

Le format est documenté dans horaires/README.md. Aucune dépendance hors bibliothèque
standard : le script tourne tel quel dans GitHub Actions (voir .github/workflows).
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import json
import os
import re
import sys
import tempfile
import time
import urllib.request
import zipfile
from collections import Counter, defaultdict

# Ressource "GTFS" du jeu de données SYTRAL sur data.gouv.fr : une adresse stable qui redirige
# vers l'archive à jour, publiée sans authentification. Si elle ne répond plus, le script
# interroge le jeu de données pour retrouver l'archive GTFS courante, puis essaie l'adresse
# directe de Grand Lyon. Chaque archive est vérifiée avant d'être utilisée.
DEFAULT_GTFS_URL = "https://www.data.gouv.fr/api/1/datasets/r/abebedc6-28cf-4e2e-9c64-db57a40156f8"
DATAGOUV_DATASET_URL = "https://www.data.gouv.fr/api/1/datasets/5de42c4d8b4c417a10e62ec9/"
GRANDLYON_GTFS_URL = "https://download.data.grandlyon.com/files/rdata/tcl_sytral.tcltheorique/GTFS_TCL.ZIP"
USER_AGENT = "AlerteTCL-horaires/1.0"
REQUIRED_FILES = ("routes.txt", "trips.txt", "stop_times.txt", "stops.txt")
FORMAT_VERSION = 1
# Nombre maximal de jours couverts à partir d'aujourd'hui. La période réellement publiée
# s'arrête plus tôt : au dernier jour où l'offre est complète (voir coverage_limit).
DEFAULT_HORIZON_DAYS = 120
# Garde-fous : en dessous de ce nombre de lignes, ou de jours entièrement couverts, le GTFS est
# considéré comme tronqué et rien n'est publié (le dernier jeu de fiches valide reste en ligne).
MIN_LINES_EXPECTED = 100
MIN_COVERED_DAYS = 3

# route_type GTFS (standard et étendus) → mode affiché
ROUTE_TYPE_MODES = {
    "0": "tram", "1": "metro", "3": "bus", "4": "ferry", "7": "funicular",
    "11": "trolleybus", "700": "bus", "702": "trambus",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def line_key(name: str) -> str:
    """Clé de fichier d'une ligne : majuscules, lettres et chiffres uniquement (identique côté apps)."""
    return re.sub(r"[^A-Z0-9]", "", name.upper())


def commercial_name(short_name: str, agency_id: str, route_type: str) -> str:
    """Aligne les noms GTFS sur ceux du reste de l'application (flux SIRI, arrêts GeoServer)."""
    if agency_id == "RX" or line_key(short_name) == "RHONEXPRESS":
        return "RX"
    if route_type == "4" and short_name == "1":
        return "N1"  # navette fluviale Navigône
    return short_name


def hex_color(raw: str, default: str) -> str:
    """Couleur GTFS (« 004F9F ») → « #004F9F », ou la couleur par défaut si absente ou invalide."""
    value = (raw or "").strip().lstrip("#").upper()
    return f"#{value}" if re.fullmatch(r"[0-9A-F]{6}", value) else default


def parse_gtfs_date(s: str) -> dt.date:
    return dt.date(int(s[0:4]), int(s[4:6]), int(s[6:8]))


def parse_minutes(hms: str) -> int | None:
    """"25:07:30" → 1507 (les heures ≥ 24 sont conservées : passages après minuit)."""
    if not hms:
        return None
    parts = hms.split(":")
    if len(parts) < 2:
        return None
    try:
        return int(parts[0]) * 60 + int(parts[1])
    except ValueError:
        return None


def today_in_paris() -> dt.date:
    try:
        from zoneinfo import ZoneInfo
        return dt.datetime.now(ZoneInfo("Europe/Paris")).date()
    except Exception:  # pragma: no cover - environnement sans base de fuseaux
        return dt.datetime.utcnow().date()


def download(url: str) -> str:
    log(f"Téléchargement du GTFS : {url}")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    fd, path = tempfile.mkstemp(suffix=".zip")
    with os.fdopen(fd, "wb") as out, urllib.request.urlopen(req, timeout=300) as resp:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            out.write(chunk)
    log(f"  {os.path.getsize(path) / 1e6:.1f} Mo reçus")
    return path


def check_archive(path: str) -> None:
    """Refuse une archive qui n'est pas un GTFS complet (page d'erreur, fichier tronqué)."""
    with zipfile.ZipFile(path) as archive:
        names = set(archive.namelist())
    missing = [f for f in REQUIRED_FILES if f not in names]
    if missing:
        raise ValueError(f"fichiers absents de l'archive : {', '.join(missing)}")


def candidate_urls(primary: str):
    """Adresses à essayer dans l'ordre : la ressource stable, puis ce que le jeu de données
    data.gouv.fr annonce comme archive GTFS, puis l'adresse directe de Grand Lyon."""
    yield primary
    try:
        req = urllib.request.Request(DATAGOUV_DATASET_URL, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as resp:
            dataset = json.load(resp)
        for resource in dataset.get("resources", []):
            url = resource.get("url") or ""
            if "gtfs" in url.lower() and url != primary:
                yield url
    except Exception as exc:  # le catalogue est un secours, pas une dépendance
        log(f"  catalogue data.gouv.fr indisponible ({exc})")
    yield GRANDLYON_GTFS_URL


def download_first_valid(primary: str) -> str:
    for url in candidate_urls(primary):
        path = None
        try:
            path = download(url)
            check_archive(path)
            return path
        except Exception as exc:
            log(f"  source inutilisable ({exc}) : essai de la suivante")
            if path and os.path.exists(path):
                os.unlink(path)
    raise SystemExit("Aucune source GTFS utilisable : publication annulée, les fiches précédentes restent en ligne")


def coverage_limit(trips_per_day: Counter, valid_from: dt.date, horizon_days: int) -> int:
    """
    Dernier jour (en décalage depuis valid_from) où l'offre est complète.

    SYTRAL planifie ses calendriers réguliers environ trois mois à l'avance ; au-delà, le GTFS
    ne contient plus que des exceptions éparses. Annoncer ces jours-là comme couverts
    afficherait des fiches presque vides. Un jour est complet s'il porte au moins 60 % des
    courses du même jour de semaine (médiane des quatre premières semaines), ou au moins 80 %
    d'un dimanche type (jours fériés). On s'arrête au premier jour incomplet : pas de trous.
    """
    reference: dict[int, int] = {}
    for weekday in range(7):
        counts = sorted(trips_per_day[d] for d in range(min(28, horizon_days)) if (valid_from + dt.timedelta(days=d)).weekday() == weekday)
        reference[weekday] = counts[len(counts) // 2] if counts else 0
    sunday_like = reference[6]
    last = -1
    for d in range(horizon_days):
        weekday = (valid_from + dt.timedelta(days=d)).weekday()
        count = trips_per_day[d]
        complete = (reference[weekday] and count >= 0.6 * reference[weekday]) or (sunday_like and count >= 0.8 * sunday_like)
        if not complete:
            break
        last = d
    return last


def open_csv(archive: zipfile.ZipFile, name: str):
    """Itère les lignes d'un fichier du GTFS sous forme de dict (encodage utf-8 avec ou sans BOM)."""
    raw = archive.open(name)
    return csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig", newline=""))


def build(gtfs_path: str, out_dir: str, horizon_days: int) -> dict:
    started = time.time()
    archive = zipfile.ZipFile(gtfs_path)
    names = set(archive.namelist())
    for required in REQUIRED_FILES:
        if required not in names:
            raise SystemExit(f"Fichier {required} absent de l'archive GTFS")

    valid_from = today_in_paris()
    valid_to_max = valid_from + dt.timedelta(days=horizon_days - 1)

    # ── Lignes ──────────────────────────────────────────────────────────────
    routes: dict[str, dict] = {}
    for r in open_csv(archive, "routes.txt"):
        short = (r.get("route_short_name") or "").strip()
        if not short:
            continue
        name = commercial_name(short, (r.get("agency_id") or "").strip(), (r.get("route_type") or "").strip())
        routes[r["route_id"]] = {
            "line": name,
            "key": line_key(name),
            "mode": ROUTE_TYPE_MODES.get((r.get("route_type") or "").strip(), "bus"),
            # Couleurs officielles SYTRAL du pictogramme de ligne (fond, texte)
            "color": hex_color(r.get("route_color") or "", "#FFFFFF"),
            "textColor": hex_color(r.get("route_text_color") or "", "#1A1A1A"),
        }
    log(f"{len(routes)} lignes dans routes.txt")

    # ── Arrêts ──────────────────────────────────────────────────────────────
    stop_names: dict[int, str] = {}
    for s in open_csv(archive, "stops.txt"):
        try:
            stop_names[int(s["stop_id"])] = (s.get("stop_name") or "").strip()
        except ValueError:
            continue  # identifiants non numériques : hors périmètre SYTRAL
    log(f"{len(stop_names)} arrêts dans stops.txt")

    # ── Calendriers : service_id → jours (décalage depuis valid_from) ────────
    service_days: dict[str, set[int]] = defaultdict(set)
    weekday_cols = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
    if "calendar.txt" in names:
        for c in open_csv(archive, "calendar.txt"):
            start = max(parse_gtfs_date(c["start_date"]), valid_from)
            end = min(parse_gtfs_date(c["end_date"]), valid_to_max)
            flags = [c.get(col) == "1" for col in weekday_cols]
            day = start
            while day <= end:
                if flags[day.weekday()]:
                    service_days[c["service_id"]].add((day - valid_from).days)
                day += dt.timedelta(days=1)
    if "calendar_dates.txt" in names:
        for c in open_csv(archive, "calendar_dates.txt"):
            day = parse_gtfs_date(c["date"])
            if not (valid_from <= day <= valid_to_max):
                continue
            offset = (day - valid_from).days
            if c["exception_type"] == "1":
                service_days[c["service_id"]].add(offset)
            else:
                service_days[c["service_id"]].discard(offset)
    service_days = {k: v for k, v in service_days.items() if v}
    log(f"{len(service_days)} services actifs entre {valid_from} et {valid_to_max}")

    # ── Courses ─────────────────────────────────────────────────────────────
    # trip_id → (route_id, sens, service_id)
    trips: dict[str, tuple[str, str, str]] = {}
    dropped_direction = 0
    for t in open_csv(archive, "trips.txt"):
        route = t["route_id"]
        if route not in routes or t["service_id"] not in service_days:
            continue
        direction_id = (t.get("direction_id") or "").strip()
        # Convention SYTRAL vérifiée sur le réseau : 0 = aller, 1 = retour.
        if direction_id == "0":
            direction = "A"
        elif direction_id == "1":
            direction = "R"
        else:
            dropped_direction += 1
            continue
        trips[t["trip_id"]] = (route, direction, t["service_id"])
    log(f"{len(trips)} courses retenues" + (f", {dropped_direction} sans sens ignorées" if dropped_direction else ""))

    # ── Horaires d'arrêt (fichier volumineux : lecture en flux, sans DictReader) ──
    stop_times: dict[str, list[tuple[int, int, int]]] = defaultdict(list)  # trip → [(séquence, arrêt, minutes)]
    reader = csv.reader(io.TextIOWrapper(archive.open("stop_times.txt"), encoding="utf-8-sig", newline=""))
    header = next(reader)
    col = {name: i for i, name in enumerate(header)}
    i_trip, i_stop, i_seq = col["trip_id"], col["stop_id"], col["stop_sequence"]
    i_dep, i_arr = col.get("departure_time"), col.get("arrival_time")
    rows = 0
    for row in reader:
        rows += 1
        trip_id = row[i_trip]
        if trip_id not in trips:
            continue
        minutes = parse_minutes(row[i_dep]) if i_dep is not None else None
        if minutes is None and i_arr is not None:
            minutes = parse_minutes(row[i_arr])
        if minutes is None:
            continue
        try:
            stop_times[trip_id].append((int(row[i_seq]), int(row[i_stop]), minutes))
        except ValueError:
            continue
    log(f"{rows} horaires d'arrêt lus, {len(stop_times)} courses avec horaires")

    # ── Courses définies par fréquence : le GTFS ne donne qu'un gabarit, on génère chaque passage ──
    if "frequencies.txt" in names:
        generated = 0
        templates: set[str] = set()
        for f in open_csv(archive, "frequencies.txt"):
            trip_id = f.get("trip_id") or ""
            if trip_id not in trips or trip_id not in stop_times:
                continue
            start, end = parse_minutes(f.get("start_time") or ""), parse_minutes(f.get("end_time") or "")
            try:
                headway = int(f.get("headway_secs") or 0)
            except ValueError:
                headway = 0
            if start is None or end is None or headway <= 0:
                continue
            template = sorted(stop_times[trip_id])
            first = template[0][2]
            templates.add(trip_id)
            run_start = start
            run = 0
            while run_start < end:
                shift = run_start - first
                new_id = f"{trip_id}#{run}"
                trips[new_id] = trips[trip_id]
                stop_times[new_id] = [(seq, stop, minutes + shift) for seq, stop, minutes in template]
                generated += 1
                run += 1
                run_start = start + round(run * headway / 60)
        for trip_id in templates:  # le gabarit lui-même n'est pas un passage réel
            trips.pop(trip_id, None)
            stop_times.pop(trip_id, None)
        if generated:
            log(f"{generated} passages générés à partir de {len(templates)} courses à fréquence")

    # ── Période réellement couverte : on s'arrête au dernier jour d'offre complète ──
    trips_per_day: Counter = Counter()
    for trip_id, (_route, _direction, service_id) in trips.items():
        if trip_id in stop_times:
            for day in service_days[service_id]:
                trips_per_day[day] += 1
    last_covered = coverage_limit(trips_per_day, valid_from, horizon_days)
    if last_covered + 1 < MIN_COVERED_DAYS:
        raise SystemExit(f"Seulement {last_covered + 1} jour(s) entièrement couverts : GTFS incomplet, publication annulée")
    service_days = {sid: {d for d in days if d <= last_covered} for sid, days in service_days.items()}
    service_days = {sid: days for sid, days in service_days.items() if days}
    trips = {tid: info for tid, info in trips.items() if info[2] in service_days}
    log(f"Offre complète du {valid_from} au {valid_from + dt.timedelta(days=last_covered)} ({last_covered + 1} jours)")

    # ── Regroupement par ligne et sens ───────────────────────────────────────
    groups: dict[tuple[str, str], list[str]] = defaultdict(list)  # (key, sens) → trip_ids
    key_info: dict[str, dict] = {}
    for trip_id, (route, direction, _service) in trips.items():
        if trip_id not in stop_times:
            continue
        info = routes[route]
        key_info.setdefault(info["key"], info)
        groups[(info["key"], direction)].append(trip_id)

    os.makedirs(os.path.join(out_dir, "lignes"), exist_ok=True)
    index_lines: dict[str, dict] = {}
    last_offset_overall = 0
    total_trips = 0

    for (key, direction), trip_ids in groups.items():
        info = key_info[key]
        # Courses : séquence d'arrêts + horaires, triées par heure de départ
        courses = []
        for trip_id in trip_ids:
            calls = sorted(stop_times[trip_id])
            if len(calls) < 2:
                continue
            courses.append((calls[0][2], tuple(c[1] for c in calls), tuple(c[2] for c in calls), trips[trip_id][2]))
        if not courses:
            continue
        courses.sort(key=lambda c: (c[0], c[1]))

        stop_order = canonical_stop_order([c[1] for c in courses])
        stop_index = {stop_id: i for i, stop_id in enumerate(stop_order)}
        patterns: dict[tuple[int, ...], int] = {}
        services: dict[str, int] = {}
        trips_out = []
        for _first, stops_seq, times, service_id in courses:
            pattern = tuple(stop_index[s] for s in stops_seq)
            p = patterns.setdefault(pattern, len(patterns))
            s = services.setdefault(service_id, len(services))
            trips_out.append({"p": p, "s": s, "t": list(times)})

        service_lists = [sorted(service_days[sid]) for sid in services]
        last_offset = max(days[-1] for days in service_lists)
        last_offset_overall = max(last_offset_overall, last_offset)

        # Destination affichée : terminus le plus fréquent des courses du sens
        terminus_counter = Counter(stop_names.get(c[1][-1], str(c[1][-1])) for c in courses)
        headsign = terminus_counter.most_common(1)[0][0]

        payload = {
            "format": FORMAT_VERSION,
            "line": info["line"],
            "key": key,
            "dir": direction,
            "mode": info["mode"],
            "color": info["color"],
            "textColor": info["textColor"],
            "headsign": headsign,
            "validFrom": valid_from.isoformat(),
            "validTo": (valid_from + dt.timedelta(days=last_offset)).isoformat(),
            "stops": [{"id": sid, "name": stop_names.get(sid, str(sid))} for sid in stop_order],
            "patterns": [list(p) for p in patterns],
            "services": service_lists,
            "trips": trips_out,
        }
        line_dir = os.path.join(out_dir, "lignes", key)
        os.makedirs(line_dir, exist_ok=True)
        with open(os.path.join(line_dir, f"{direction}.json"), "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))

        entry = index_lines.setdefault(key, {
            "line": info["line"], "key": key, "mode": info["mode"],
            "color": info["color"], "textColor": info["textColor"], "directions": [],
        })
        entry["directions"].append({
            "dir": direction,
            "headsign": headsign,
            "stops": len(stop_order),
            "trips": len(trips_out),
        })
        total_trips += len(trips_out)

    if len(index_lines) < MIN_LINES_EXPECTED:
        raise SystemExit(f"Seulement {len(index_lines)} lignes produites : GTFS suspect, publication annulée")

    mode_rank = {"metro": 0, "funicular": 1, "tram": 2, "trambus": 3, "trolleybus": 4, "bus": 5, "ferry": 6}

    def sort_key(entry: dict):
        digits = re.sub(r"\D", "", entry["line"])
        return (mode_rank.get(entry["mode"], 9), int(digits) if digits else 10**9, entry["line"])

    for entry in index_lines.values():
        entry["directions"].sort(key=lambda d: d["dir"])

    index = {
        "format": FORMAT_VERSION,
        "generatedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "validFrom": valid_from.isoformat(),
        "validTo": (valid_from + dt.timedelta(days=last_offset_overall)).isoformat(),
        "lines": sorted(index_lines.values(), key=sort_key),
    }
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, separators=(",", ":"))

    log(f"{len(index_lines)} lignes, {total_trips} courses écrites dans {out_dir} en {time.time() - started:.0f} s")
    return index


def canonical_stop_order(sequences: list[tuple[int, ...]]) -> list[int]:
    """
    Ordre de présentation des arrêts d'un sens : la course la plus longue sert de colonne
    vertébrale, les arrêts des autres variantes (courses partielles, antennes) sont insérés
    juste après leur prédécesseur déjà connu. Un arrêt desservi deux fois (boucle) n'apparaît
    qu'une fois.
    """
    ordered: list[int] = []
    position: dict[int, int] = {}
    for seq in sorted(set(sequences), key=len, reverse=True):
        previous_pos = -1
        for stop_id in seq:
            if stop_id in position:
                previous_pos = position[stop_id]
                continue
            insert_at = previous_pos + 1
            ordered.insert(insert_at, stop_id)
            position = {s: i for i, s in enumerate(ordered)}
            previous_pos = insert_at
    return ordered


def main() -> None:
    parser = argparse.ArgumentParser(description="Fiches horaires théoriques TCL (JSON) à partir du GTFS.")
    parser.add_argument("--gtfs", default=DEFAULT_GTFS_URL, help="URL ou chemin local de l'archive GTFS")
    parser.add_argument("--out", default="horaires-out", help="dossier de sortie")
    parser.add_argument("--horizon-days", type=int, default=DEFAULT_HORIZON_DAYS, help="jours couverts à partir d'aujourd'hui")
    args = parser.parse_args()

    downloaded = None
    gtfs_path = args.gtfs
    if re.match(r"^https?://", gtfs_path):
        downloaded = gtfs_path = download_first_valid(gtfs_path)
    try:
        index = build(gtfs_path, args.out, args.horizon_days)
    finally:
        if downloaded:
            os.unlink(downloaded)
    log(f"Période couverte : du {index['validFrom']} au {index['validTo']}")


if __name__ == "__main__":
    main()
