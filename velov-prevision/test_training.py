"""Tests de l'entraînement et de l'export des arbres : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import json
import math
import unittest
from unittest import mock

import numpy as np

import bundle
import reader
import training
from readings import Grid

# Lundi 5 octobre 2026, 00:00 UTC.
T0 = 1791158400
DAY_SLOTS = 96
CALENDAR = {"feries": [], "vacances": []}


def synthetic_grid(days: int, stations: int) -> Grid:
    """Stations de 20 bornes dont les vélos suivent l'heure de la journée, avec un peu de hasard."""
    rng = np.random.default_rng(1)
    slot, column = np.meshgrid(np.arange(days * DAY_SLOTS), np.arange(stations), indexing="ij")
    wave = 10 + 6 * np.sin(2 * np.pi * (slot / DAY_SLOTS + column / stations))
    velos = np.clip(np.round(wave + rng.normal(0, 2, slot.shape)), 0, 20).astype(np.int16)
    elec = velos // 2
    capacite = np.full(slot.shape, 20, dtype=np.int16)
    present = np.ones(slot.shape, dtype=bool)
    return Grid(T0, 1000 + np.arange(stations), elec, velos - elec, capacite - velos, capacite, present, present.copy())


def target_time(rows: dict) -> np.ndarray:
    return rows["t0"] + rows["xq"] * reader.STEP


class RowsTest(unittest.TestCase):
    GRID = synthetic_grid(5, 5)
    CUT = 3 * DAY_SLOTS

    def test_training_never_sees_the_control_week(self):
        rows = training.training_rows(self.GRID, 0, self.CUT)
        self.assertLess(target_time(rows).max(), T0 + self.CUT * reader.STEP)
        self.assertGreaterEqual(rows["t0"].min(), T0)
        self.assertTrue(((rows["xq"] >= 1) & (rows["xq"] <= training.MAX_HORIZON)).all())

    def test_about_half_of_the_readings_are_drawn_and_the_draw_is_repeatable(self):
        first = training.training_rows(self.GRID, 0, self.CUT)
        again = training.training_rows(self.GRID, 0, self.CUT)
        # Une ligne sur deux, moins celles dont l'heure visée dépasse la coupure (la moitié de celles du dernier jour).
        self.assertAlmostEqual(0.5 * 5 / 6, len(first["xq"]) / (self.CUT * 5), delta=0.05)
        np.testing.assert_array_equal(first["t0"], again["t0"])
        np.testing.assert_array_equal(first["xq"], again["xq"])

    def test_training_starts_at_the_first_wanted_quarter(self):
        rows = training.training_rows(self.GRID, DAY_SLOTS, self.CUT)
        self.assertGreaterEqual(rows["t0"].min(), T0 + DAY_SLOTS * reader.STEP)

    def test_rows_carry_the_state_now_and_at_the_target_time(self):
        rows = training.training_rows(self.GRID, 0, self.CUT)
        i = 10
        slot, column = (rows["t0"][i] - T0) // reader.STEP, rows["station"][i] - 1000
        target = slot + rows["xq"][i]
        self.assertEqual((self.GRID.elec[slot, column], self.GRID.meca[slot, column], self.GRID.bornes[slot, column], 20),
                         (rows["elec0"][i], rows["meca0"][i], rows["bornes0"][i], rows["capacite"][i]))
        self.assertEqual((self.GRID.elec[target, column], self.GRID.elec[target, column] + self.GRID.meca[target, column], self.GRID.bornes[target, column]),
                         (rows["y_elec"][i], rows["y_velos"][i], rows["y_bornes"][i]))

    def test_control_starts_on_the_hour_at_the_eight_horizons(self):
        rows = training.control_rows(self.GRID, self.CUT)
        self.assertTrue((rows["t0"] % 3600 == 0).all())
        self.assertGreaterEqual(rows["t0"].min(), T0 + self.CUT * reader.STEP)
        self.assertEqual(list(training.CONTROL_HORIZONS), np.unique(rows["xq"]).tolist())
        # Deux jours de contrôle, 5 stations : chaque heure a son quart d'heure suivant, seul le premier jour a son lendemain.
        self.assertEqual(48 * 5, int((rows["xq"] == 1).sum()))
        self.assertEqual(24 * 5, int((rows["xq"] == 96).sum()))

    def test_an_unusable_reading_is_neither_a_start_nor_a_target(self):
        grid = synthetic_grid(5, 5)
        grid.valid[self.CUT + 4, 2] = False
        rows = training.control_rows(grid, self.CUT)
        unusable = T0 + (self.CUT + 4) * reader.STEP
        at_station = rows["station"] == 1002
        self.assertFalse((rows["t0"][at_station] == unusable).any())
        self.assertFalse((target_time(rows)[at_station] == unusable).any())
        self.assertTrue((target_time(rows)[~at_station] == unusable).any())


class HabitTest(unittest.TestCase):
    ROWS = {"station": np.array([7, 7, 7, 9]), "y_velos": np.array([4, 0, 3, 2]), "y_elec": np.array([1, 0, 2, 2]), "y_bornes": np.array([0, 5, 2, 1])}

    def habit(self) -> tuple[np.ndarray, np.ndarray]:
        return training.habit_table(self.ROWS, np.array([0, 0, 0, 2]), np.array([8, 8, 8, 23]))

    def test_means_by_station_day_type_and_hour(self):
        ids, table = self.habit()
        self.assertEqual([7, 9], ids.tolist())
        # Moyenne des vélos, fréquence d'au moins un vélo, d'au moins une place, part d'électriques quand il y a des vélos.
        self.assertEqual([2.3333, 0.6667, 0.6667, 0.4583], table[0, 0, 8].tolist())
        self.assertEqual([2.0, 1.0, 1.0, 1.0], table[1, 2, 23].tolist())
        self.assertTrue(np.isnan(table[0, 1, 8]).all())

    def test_the_published_habit_omits_slots_without_reading(self):
        self.assertEqual({"7": {"0_8": [2.3333, 0.6667, 0.6667, 0.4583]}, "9": {"2_23": [2.0, 1.0, 1.0, 1.0]}}, training.habit_json(self.habit()))

    def test_an_electric_share_without_bikes_is_published_as_null(self):
        rows = {"station": np.array([7]), "y_velos": np.array([0]), "y_elec": np.array([0]), "y_bornes": np.array([3])}
        self.assertEqual({"7": {"1_0": [0.0, 0.0, 1.0, None]}}, training.habit_json(training.habit_table(rows, np.array([1]), np.array([0]))))

    def test_the_published_habit_reads_back_identically(self):
        ids, table = self.habit()
        read_ids, read_table = reader.parse_habit(training.habit_json((ids, table)))
        np.testing.assert_array_equal(ids, read_ids)
        np.testing.assert_array_equal(table, read_table)


class TreeExportTest(unittest.TestCase):
    def node(self, feature: int, threshold: float, left, right, default_left: bool = True, missing: str = "None") -> dict:
        return {"split_feature": feature, "threshold": threshold, "decision_type": "<=", "default_left": default_left,
                "missing_type": missing, "left_child": left, "right_child": right}

    def test_a_tree_is_flattened_with_leaves_as_negative_children(self):
        tree = {"tree_structure": self.node(3, 1.5, {"leaf_value": 0.25}, self.node(0, 2.123456789123, {"leaf_value": -1.0}, {"leaf_value": 2.0}, False, "NaN"))}
        self.assertEqual({"f": [3, 0], "s": [1.5, 2.12345679], "d": [2, 8], "g": [-1, -2], "r": [1, -3], "v": [0.25, -1.0, 2.0], "racine": 0},
                         training.tree_arrays(tree))

    def test_a_tree_reduced_to_a_leaf(self):
        self.assertEqual({"f": [], "s": [], "d": [], "g": [], "r": [], "v": [0.5], "racine": -1}, training.tree_arrays({"tree_structure": {"leaf_value": 0.5}}))

    def test_a_categorical_split_is_refused(self):
        node = {**self.node(0, 1.0, {"leaf_value": 0.0}, {"leaf_value": 1.0}), "decision_type": "=="}
        with self.assertRaises(ValueError):
            training.tree_arrays({"tree_structure": node})


class TrainingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        grid = synthetic_grid(15, 30)
        cut = 13 * DAY_SLOTS
        # La moitié des stations ont une position, une sur trois ses repères : les autres exercent les valeurs manquantes.
        described = [{"id": 1000 + i, "lat": 45.7 + i / 300, "lon": 4.8 + i / 300, **({"altitude": 170.0 + i} if i % 3 == 0 else {})} for i in range(0, 30, 2)]
        with mock.patch.object(training, "MAX_TREES", 25):
            modeles, habitude, cls.boosters = training.train(training.training_rows(grid, 0, cut), described, CALENDAR, lambda msg: None)
        # Le modèle passe par le fichier publié, comme dans les applications.
        cls.bundle = json.loads(bundle.encode(bundle.assemble("2026-10-18", T0, modeles, habitude, described, CALENDAR, {})))
        cls.check = training.control_rows(grid, cut)

    def test_the_twelve_models_are_published_with_their_variables(self):
        self.assertEqual(list(training.VARIABLES), self.bundle["variables"])
        self.assertEqual([10, 20, 30, 40, 50, 60, 70, 80, 90], self.bundle["deciles"])
        self.assertEqual({"quantile": 9, "binary": 2, "cross_entropy": 1},
                         {objective: sum(m["objectif"] == objective for m in self.bundle["modeles"].values()) for objective in ("quantile", "binary", "cross_entropy")})
        self.assertTrue(all(1 <= len(m["arbres"]) <= 25 for m in self.bundle["modeles"].values()))

    def test_the_reader_finds_the_scores_of_lightgbm_in_the_published_file(self):
        self.assertLess(training.reader_gap(self.bundle, self.boosters, self.check), 1e-6)

    def test_missing_values_were_learnt_and_exported(self):
        flags = {d for m in self.bundle["modeles"].values() for tree in m["arbres"] for d in tree["d"]}
        self.assertTrue(flags & {8, 10}, "aucun nœud à valeur manquante NaN dans les arbres")

    def test_forecasts_follow_the_daily_wave(self):
        pred = reader.predict(self.bundle, self.check)
        self.assertTrue((np.diff(pred["q"], axis=1) >= 0).all())
        self.assertTrue(((pred["q"] >= 0) & (pred["q"] <= 20)).all())
        day_ahead = self.check["xq"] == 96
        median_error = np.abs(pred["q"][day_ahead, 4] - self.check["y_velos"][day_ahead]).mean()
        self.assertLess(median_error, 2.5)
        self.assertTrue(all(math.isfinite(v) for v in pred["p_velo"][:50]))


if __name__ == "__main__":
    unittest.main()
