"""
Calendrier publié avec le modèle : jours fériés (calculés ici, aucune source à interroger) et
vacances scolaires de la zone A, celle de Lyon (API ouverte du ministère de l'Éducation nationale).

Une panne ou un changement de l'API ne doit jamais bloquer la publication : faute de réponse
utilisable, les vacances du modèle déjà en ligne sont reprises telles quelles.
"""
from __future__ import annotations

import datetime as dt
import json
import urllib.parse
import urllib.request

SCHOOL_API = "https://data.education.gouv.fr/api/explore/v2.1/catalog/datasets/fr-en-calendrier-scolaire/exports/json"
USER_AGENT = "AlerteTCL/velov-prevision"
# Ancienneté au-delà de laquelle des vacances terminées ne sont plus publiées : tout l'entraînement tient dedans.
SCHOOL_PAST_DAYS = 400
# Des vacances de plus de cent jours n'existent pas : au-delà, la réponse est jugée fausse.
MAX_HOLIDAY_DAYS = 100
DAY_MS = 86_400_000


def easter(year: int) -> dt.date:
    """Dimanche de Pâques (calendrier grégorien, algorithme de Butcher-Meeus)."""
    a, b, c = year % 19, year // 100, year % 100
    d, e = b // 4, b % 4
    g = (8 * b + 13) // 25
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 19 * l) // 433
    month = (h + l - 7 * m + 90) // 25
    return dt.date(year, month, (h + l - 7 * m + 33 * month + 19) % 32)


def public_holidays(today: dt.date) -> list[str]:
    """Les onze jours fériés de métropole, de l'année précédente à la fin de l'année N+2 :
    tout l'entraînement passé et au moins deux ans devant, bien plus que la durée de vie d'un modèle."""
    days = []
    for year in range(today.year - 1, today.year + 3):
        paques = easter(year)
        days += [dt.date(year, month, day) for month, day in ((1, 1), (5, 1), (5, 8), (7, 14), (8, 15), (11, 1), (11, 11), (12, 25))]
        # Lundi de Pâques, jeudi de l'Ascension, lundi de Pentecôte.
        days += [paques + dt.timedelta(days=offset) for offset in (1, 39, 50)]
    return sorted(day.isoformat() for day in days)


def parse_school_holidays(records: list[dict], today: dt.date) -> list[list[int]]:
    """Réponse de l'API → périodes [début, fin exclue] en millisecondes epoch, triées et fusionnées.
    Les lignes propres aux enseignants (prérentrée) sont écartées, comme les périodes sans fin
    ou terminées depuis plus de SCHOOL_PAST_DAYS jours."""
    oldest = dt.datetime.combine(today - dt.timedelta(days=SCHOOL_PAST_DAYS), dt.time(), dt.timezone.utc).timestamp() * 1000
    periods = []
    for record in records:
        if record.get("population") == "Enseignants" or not record.get("start_date") or not record.get("end_date"):
            continue
        start, end = (int(dt.datetime.fromisoformat(record[key]).timestamp() * 1000) for key in ("start_date", "end_date"))
        if end >= oldest:
            periods.append([start, end])
    merged: list[list[int]] = []
    for start, end in sorted(periods):
        if merged and start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    return merged


def school_holidays_defect(periods: list[list[int]]) -> str | None:
    """Ce qui rend une liste de vacances inutilisable, ou None si elle est saine."""
    if len(periods) < 3:
        return f"{len(periods)} période(s) seulement"
    for start, end in periods:
        if not 0 < end - start <= MAX_HOLIDAY_DAYS * DAY_MS:
            return f"période impossible ({start} → {end})"
    return None


def fetch_school_holidays(today: dt.date) -> list[list[int]]:
    """Vacances scolaires de Lyon annoncées par le ministère, passées récentes et à venir."""
    query = urllib.parse.urlencode({"where": "location='Lyon'"})
    request = urllib.request.Request(f"{SCHOOL_API}?{query}", headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return parse_school_holidays(json.load(response), today)


def choose_school_holidays(fetched: list[list[int]] | None, published: list[list[int]]) -> tuple[list[list[int]], str | None]:
    """Vacances à publier, et la raison du repli quand celles du ministère sont écartées. Les nouvelles
    ne remplacent les anciennes que si elles sont saines et voient au moins aussi loin : le calendrier
    en ligne ne recule jamais."""
    if fetched is None:
        return published, "API injoignable ou réponse illisible"
    defect = school_holidays_defect(fetched)
    if defect:
        return published, defect
    if published and fetched[-1][1] < published[-1][1]:
        return published, "réponse moins étendue que le calendrier en ligne"
    return fetched, None


def build_calendar(today: dt.date, published: dict) -> tuple[dict, str | None]:
    """Calendrier du nouveau modèle, et la raison du repli éventuel sur les vacances de `published`
    (le calendrier du modèle en ligne)."""
    try:
        fetched = fetch_school_holidays(today)
    except Exception:  # l'API est un confort, pas une dépendance
        fetched = None
    vacances, fallback = choose_school_holidays(fetched, published.get("vacances", []))
    return {"feries": public_holidays(today), "vacances": vacances}, fallback
