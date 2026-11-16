"""Tests du lecteur Python (variables et parcours des arbres) : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import datetime as dt
import math
import unittest

import numpy as np

import reader


def epoch(text: str) -> int:
    """Secondes epoch d'une heure UTC écrite « 2026-07-14T08:30 »."""
    return int(dt.datetime.fromisoformat(text).replace(tzinfo=dt.timezone.utc).timestamp())


def leaf(value: float) -> dict:
    """Arbre réduit à une feuille."""
    return {"f": [], "s": [], "d": [], "g": [], "r": [], "v": [value], "racine": -1}


def split(threshold: float, flags: int, left: float = -1.0, right: float = 1.0, feature: int = 0) -> dict:
    """Arbre à un seul nœud."""
    return {"f": [feature], "s": [threshold], "d": [flags], "g": [-1], "r": [-2], "v": [left, right], "racine": 0}


def walk(tree: dict, x: list[float]) -> float:
    """Transcription ligne à ligne du parcours fait par l'application (une ligne à la fois)."""
    node = tree["racine"]
    while node >= 0:
        value, flags = x[tree["f"][node]], tree["d"][node]
        missing = (flags >> 2) & 3
        if math.isnan(value) and missing != 2:
            value = 0.0
        if (missing == 1 and abs(value) <= 1e-35) or (missing == 2 and math.isnan(value)):
            go_left = flags & 2 != 0
        else:
            go_left = value <= tree["s"][node]
        node = tree["g"][node] if go_left else tree["r"][node]
    return tree["v"][~node]


def values(tree: dict, column: list[float]) -> list[float]:
    cols = [np.array(column, dtype=float)]
    out = np.zeros(len(column))
    reader.tree_values(tree, cols, [bool(np.isnan(cols[0]).any())], out)
    return out.tolist()


class TreeTest(unittest.TestCase):
    def test_a_value_equal_to_the_threshold_goes_left(self):
        self.assertEqual([-1, -1, 1], values(split(1.5, 2), [1, 1.5, 2]))

    def test_without_missing_type_nan_counts_as_zero(self):
        self.assertEqual([-1], values(split(1.5, 2), [math.nan]))
        self.assertEqual([1], values(split(-1, 2), [math.nan]))

    def test_nan_missing_type_follows_the_default_side(self):
        self.assertEqual([1, -1], values(split(5, 8), [math.nan, 0]))
        self.assertEqual([-1, 1], values(split(-5, 10), [math.nan, 0]))

    def test_zero_missing_type_sends_zero_and_nan_to_the_default_side(self):
        self.assertEqual([-1, -1, 1], values(split(-5, 6), [0, math.nan, 3]))
        self.assertEqual([1, 1, -1], values(split(5, 4), [0, math.nan, 3]))

    def test_a_tree_reduced_to_a_leaf(self):
        self.assertEqual([0.25, 0.25], values(leaf(0.25), [1, math.nan]))

    def test_random_trees_match_the_row_by_row_walk(self):
        rng = np.random.default_rng(7)
        cols = [rng.normal(size=500), rng.integers(0, 3, 500).astype(float), rng.normal(size=500)]
        cols[0][rng.random(500) < 0.2] = np.nan
        cols[1][rng.random(500) < 0.2] = np.nan
        has_nan = [bool(np.isnan(col).any()) for col in cols]
        for _ in range(40):
            # Arbre à trois nœuds : la racine, puis un nœud de chaque côté ; tous les drapeaux possibles.
            tree = {
                "f": rng.integers(0, 3, 3).tolist(), "s": rng.normal(size=3).round(2).tolist(),
                "d": rng.choice([0, 2, 4, 6, 8, 10], 3).tolist(), "g": [1, -1, -3], "r": [2, -2, -4],
                "v": rng.normal(size=4).tolist(), "racine": 0,
            }
            out = np.zeros(500)
            reader.tree_values(tree, cols, has_nan, out)
            expected = [walk(tree, [col[i] for col in cols]) for i in range(500)]
            np.testing.assert_array_equal(out, expected)


class CalendarTest(unittest.TestCase):
    CALENDAR = {"feries": ["2026-07-14", "2027-01-01"], "vacances": [[epoch("2026-07-03T22:00") * 1000, epoch("2026-08-31T22:00") * 1000]]}

    def columns(self, *times: str) -> dict:
        return reader.calendar_columns(np.array([epoch(t) for t in times]), self.CALENDAR)

    def test_time_is_read_on_the_lyon_clock(self):
        cal = self.columns("2026-07-15T08:30", "2026-01-15T08:30")
        self.assertEqual([10.5, 9.5], cal["heure"].tolist())
        self.assertEqual([3, 4], cal["jour_sem"].tolist())
        self.assertEqual([7, 1], cal["mois"].tolist())

    def test_day_types(self):
        # Jeudi, samedi, dimanche, puis un mardi férié.
        cal = self.columns("2026-07-16T10:00", "2026-07-18T10:00", "2026-07-19T10:00", "2026-07-14T10:00")
        self.assertEqual([0, 1, 2, 2], cal["type_jour"].tolist())
        self.assertEqual([0, 0, 0, 1], cal["ferie"].tolist())

    def test_a_holiday_starts_at_midnight_in_lyon_not_utc(self):
        cal = self.columns("2026-12-31T22:30", "2026-12-31T23:30")
        self.assertEqual([0, 1], cal["ferie"].tolist())

    def test_school_holidays_include_their_start_and_exclude_their_end(self):
        cal = self.columns("2026-07-03T21:45", "2026-07-03T22:00", "2026-08-31T21:45", "2026-08-31T22:00")
        self.assertEqual([0, 1, 1, 0], cal["vacances"].tolist())

    def test_both_02_30_of_the_autumn_clock_change(self):
        cal = self.columns("2026-10-25T00:30", "2026-10-25T01:30")
        self.assertEqual([2.5, 2.5], cal["heure"].tolist())


class VariablesTest(unittest.TestCase):
    STATIONS = [{"id": 7, "altitude": 170.0, "dist_metro_km": 0.2, "dist_tram_km": 0.4, "dist_gare_km": 1.5, "lat": 45.75, "lon": 4.85},
                {"id": 9, "lat": 45.8, "lon": 4.9, "altitude": None}]
    HABIT = {"7": {"0_11": [4.5, 0.9, 0.8, None]}}
    CALENDAR = {"feries": [], "vacances": []}

    def rows(self, **changes) -> dict:
        # Mercredi 15 juillet 2026, 10:45 à Lyon ; horizon d'un quart d'heure, donc heure visée 11:00.
        base = {"station": [7], "t0": [epoch("2026-07-15T08:45")], "xq": [1], "elec0": [2], "meca0": [3], "bornes0": [10], "capacite": [15]}
        return {name: np.array(changes.get(name, value)) for name, value in base.items()}

    def variables(self, **changes) -> dict:
        return reader.variables(self.rows(**changes), self.STATIONS, self.CALENDAR, reader.parse_habit(self.HABIT))

    def test_state_calendar_habit_and_geography(self):
        v = self.variables()
        self.assertEqual([5, 2, 3, 10, 15, 0.4], [v[name][0] for name in ("velos0", "elec0", "meca0", "bornes0", "capacite", "part_elec0")])
        self.assertEqual([0.25, 10.75, 11.0, 3, 7, 0], [v[name][0] for name in ("horizon_h", "heure_origine", "heure_cible", "jour_sem", "mois", "type_jour")])
        self.assertEqual([4.5, 0.9, 0.8], [v[name][0] for name in ("hab_velos", "hab1_velos", "hab1_bornes")])
        self.assertTrue(math.isnan(v["hab_part_elec"][0]))
        self.assertEqual([170.0, 0.2, 0.4, 1.5, 45.75, 4.85], [v[name][0] for name in reader.GEO])

    def test_the_electric_share_is_unknown_without_bikes(self):
        self.assertTrue(math.isnan(self.variables(elec0=[0], meca0=[0])["part_elec0"][0]))

    def test_habit_is_read_at_the_target_hour(self):
        self.assertTrue(math.isnan(self.variables(xq=[8])["hab_velos"][0]))

    def test_an_unknown_station_has_no_habit_and_no_geography(self):
        v = self.variables(station=[1234])
        self.assertTrue(all(math.isnan(v[name][0]) for name in (*reader.HABIT, *reader.GEO)))

    def test_a_missing_or_null_landmark_is_unknown(self):
        v = self.variables(station=[9])
        self.assertEqual([45.8, 4.9], [v["lat"][0], v["lon"][0]])
        self.assertTrue(all(math.isnan(v[name][0]) for name in ("altitude", "dist_metro_km", "dist_tram_km", "dist_gare_km")))


class PredictTest(unittest.TestCase):
    def bundle(self, deltas: dict[int, float], electric: dict[int, float] | None = None) -> dict:
        """Modèle à une feuille par arbre : `deltas` pour tous les vélos, `electric` pour les électriques, rien pour les mécaniques."""
        by_kind = {"velos": deltas, "elec": electric or dict.fromkeys(deltas, 0.0), "meca": dict.fromkeys(deltas, 0.0)}
        forests = {f"{kind}_q{k}": {"objectif": "quantile", "arbres": [leaf(delta)]} for kind, values in by_kind.items() for k, delta in values.items()}
        forests["velos_p1"] = {"objectif": "binary", "arbres": [leaf(0.0), leaf(math.log(3))]}
        forests["elec_p1"] = {"objectif": "binary", "arbres": [leaf(math.log(4))]}
        forests["meca_p1"] = {"objectif": "binary", "arbres": [leaf(0.0)]}
        forests["bornes_p1"] = {"objectif": "binary", "arbres": [leaf(-math.log(3))]}
        return {"variables": ["velos0"], "deciles": list(deltas), "modeles": forests, "habitude": {}, "stations": [], "calendrier": {"feries": [], "vacances": []}}

    def predict(self, deltas: dict[int, float], capacite: int = 20, bornes0: int = 10, **more) -> dict:
        rows = {"station": np.array([1]), "t0": np.array([epoch("2026-07-15T08:45")]), "xq": np.array([4]),
                "elec0": np.array([2]), "meca0": np.array([3]), "bornes0": np.array([bornes0]), "capacite": np.array([capacite])}
        return reader.predict(self.bundle(deltas, **more), rows)

    def test_deciles_are_added_to_the_present_bikes_and_sorted(self):
        self.assertEqual([[4.0, 5.5, 7.0]], self.predict({10: 0.5, 50: -1, 90: 2})["q"]["velos"].tolist())

    def test_each_kind_starts_from_its_own_present_count(self):
        q = self.predict({10: -1, 50: 0, 90: 1}, electric={10: -0.5, 50: 0.5, 90: 4})["q"]
        self.assertEqual([[1.5, 2.5, 6.0]], q["elec"].tolist())
        self.assertEqual([[3.0, 3.0, 3.0]], q["meca"].tolist())

    def test_deciles_are_kept_within_the_capacity(self):
        self.assertEqual([[0.0, 5.0, 6.0]], self.predict({10: -9, 50: 0, 90: 30}, capacite=6)["q"]["velos"].tolist())
        self.assertEqual([[0.0, 2.0, 6.0]], self.predict({10: 0, 50: 0, 90: 0}, capacite=6, electric={10: -9, 50: 0, 90: 30})["q"]["elec"].tolist())
        self.assertEqual([[1.0]], self.predict({50: 3}, capacite=0)["q"]["velos"].tolist())

    def test_free_docks_are_what_is_not_a_bike(self):
        # 5 vélos et 10 places : avec 4 à 7 vélos attendus, il restera 8 à 11 places, du décile bas au décile haut.
        self.assertEqual([[8.0, 10.0, 11.0]], self.predict({10: -1, 50: 0, 90: 2})["q"]["bornes"].tolist())

    def test_free_docks_stay_within_the_capacity(self):
        # 5 vélos et 1 place sur 6 bornes en service : 8 vélos ne laissent aucune place, jamais un nombre négatif.
        self.assertEqual([[0.0, 1.0, 6.0]], self.predict({10: -9, 50: 0, 90: 3}, capacite=6, bornes0=1)["q"]["bornes"].tolist())

    def test_probabilities_go_through_a_sigmoid_of_the_summed_leaves(self):
        p1 = self.predict({50: 0})["p1"]
        self.assertEqual(["velos", "elec", "meca", "bornes"], list(p1))
        for kind, expected in (("velos", 0.75), ("elec", 0.8), ("meca", 0.5), ("bornes", 0.25)):
            self.assertAlmostEqual(expected, p1[kind][0])


if __name__ == "__main__":
    unittest.main()
