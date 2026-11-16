"""Tests du contrôle et des garde-fous : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import unittest

import numpy as np

import control

DECILES = [10, 30, 50, 70, 90]


def rows(*lines: dict) -> dict:
    return {name: np.array([line[name] for line in lines]) for name in lines[0]}


def line(**changes) -> dict:
    """Chiffres d'un horizon pour un modèle sain (ceux de l'étude d'origine à 2 h)."""
    base = {"h": 2, "lignes": 80000, "err": 2.48, "err_actuel": 2.88, "couv80": 0.83, "couv40": 0.43, "couv80_places": 0.81,
            "couv40_places": 0.42, "brier": 0.084, "brier_actuel": 0.148, "brier_place": 0.038, "brier_place_actuel": 0.065,
            "pinball": 0.96, "err_part_elec": 0.12}
    return {**base, **changes}


def verdict(score: float, good: bool = True) -> control.Verdict:
    return control.Verdict([line(pinball=score)], [] if good else ["défaut"])


class FiguresTest(unittest.TestCase):
    # Deux stations à l'horizon d'une heure : cinq vélos puis sept ; aucune puis toujours aucune.
    ROWS = rows(
        {"xq": 4, "elec0": 2, "meca0": 3, "bornes0": 10, "capacite": 15, "y_velos": 7, "y_elec": 3, "y_bornes": 8},
        {"xq": 4, "elec0": 0, "meca0": 0, "bornes0": 15, "capacite": 15, "y_velos": 0, "y_elec": 0, "y_bornes": 15},
    )
    PRED = {"q": np.array([[4.0, 5, 6, 7, 8], [0, 0, 0, 1, 2]]), "p_velo": np.array([0.9, 0.2]), "p_place": np.array([0.8, 1.0]),
            "part_elec": np.array([0.5, 0.5])}

    def test_figures_of_one_horizon(self):
        self.assertEqual([{
            "h": 1.0, "lignes": 2, "err": 0.5, "err_actuel": 1.0, "couv80": 1.0, "couv40": 1.0, "couv80_places": 1.0,
            "couv40_places": 1.0, "brier": 0.025, "brier_actuel": 0.0, "brier_place": 0.02, "brier_place_actuel": 0.0,
            "pinball": 0.2, "err_part_elec": 0.0714,
        }], control.horizon_figures(self.PRED, self.ROWS, DECILES))

    def test_one_line_per_horizon(self):
        both = {name: np.concatenate([values, values]) for name, values in self.ROWS.items()}
        both["xq"] = np.array([4, 4, 96, 96])
        pred = {name: np.concatenate([values, values]) for name, values in self.PRED.items()}
        self.assertEqual([1.0, 24.0], [figures["h"] for figures in control.horizon_figures(pred, both, DECILES)])

    def test_bikes_outside_the_band_are_not_covered(self):
        missed = rows({"xq": 8, "elec0": 2, "meca0": 3, "bornes0": 10, "capacite": 15, "y_velos": 12, "y_elec": 3, "y_bornes": 3})
        pred = {name: values[:1] for name, values in self.PRED.items()}
        figures = control.horizon_figures(pred, missed, DECILES)[0]
        self.assertEqual([0.0, 0.0, 0.0, 0.0], [figures[name] for name in ("couv80", "couv40", "couv80_places", "couv40_places")])

    def test_free_docks_are_what_is_not_a_bike_within_the_capacity(self):
        # 5 vélos et 1 place sur 6 bornes en service : le décile 90 (8 vélos) ne laisse aucune place, jamais un nombre négatif.
        full = rows({"xq": 8, "elec0": 2, "meca0": 3, "bornes0": 1, "capacite": 6, "y_velos": 6, "y_elec": 3, "y_bornes": 0})
        pred = {name: values[:1] for name, values in self.PRED.items()}
        self.assertEqual(1.0, control.horizon_figures(pred, full, DECILES)[0]["couv80_places"])

    def test_the_electric_share_is_undefined_without_any_bike(self):
        empty = {name: values[1:] for name, values in self.ROWS.items()}
        pred = {name: values[1:] for name, values in self.PRED.items()}
        self.assertIsNone(control.horizon_figures(pred, empty, DECILES)[0]["err_part_elec"])


class WeekTest(unittest.TestCase):
    def week(self, hours: int, stations: int, horizons: tuple[int, ...] = (1, 96)) -> dict:
        t0, station, xq = np.meshgrid(np.arange(hours) * 3600, np.arange(stations), np.array(horizons), indexing="ij")
        return {"t0": t0.ravel(), "station": station.ravel(), "xq": xq.ravel()}

    def test_a_full_week_can_be_judged(self):
        self.assertEqual([], control.week_defects(self.week(168, 450)))

    def test_too_few_hours_stations_or_rows(self):
        self.assertEqual(1, len(control.week_defects(self.week(control.MIN_HOURS - 1, 450))))
        self.assertEqual(1, len(control.week_defects(self.week(168, control.MIN_STATIONS - 1))))
        thin = self.week(168, 450)
        keep = (thin["xq"] == 1) | (thin["station"] < 100)
        self.assertEqual(1, len(control.week_defects({name: values[keep] for name, values in thin.items()})))

    def test_an_empty_week(self):
        self.assertEqual(3, len(control.week_defects(self.week(0, 0))))


class ModelDefectsTest(unittest.TestCase):
    def test_the_reference_model_is_good(self):
        self.assertEqual([], control.model_defects([line(h=0.25, err=1.29, err_actuel=0.88), line()]))

    def test_the_band_must_be_right_about_as_often_as_announced(self):
        low, high = control.COVERAGE_RANGE
        self.assertEqual(1, len(control.model_defects([line(couv80=low - 0.01)])))
        self.assertEqual(1, len(control.model_defects([line(couv80=high + 0.01)])))
        self.assertEqual(1, len(control.model_defects([line(couv80_places=low - 0.01)])))
        self.assertEqual([], control.model_defects([line(couv80=low, couv80_places=high)]))

    def test_median_and_probabilities_must_beat_same_as_now_from_two_hours(self):
        self.assertEqual(1, len(control.model_defects([line(err=2.88)])))
        self.assertEqual(1, len(control.model_defects([line(h=24, err=4.5, err_actuel=4.4)])))
        self.assertEqual(1, len(control.model_defects([line(brier=0.148)])))
        self.assertEqual(1, len(control.model_defects([line(brier_place=0.07)])))

    def test_before_two_hours_the_present_state_may_win(self):
        self.assertEqual([], control.model_defects([line(h=1, err=1.95, err_actuel=1.94, brier=0.13, brier_actuel=0.12, brier_place=0.06, brier_place_actuel=0.05)]))


class JudgeTest(unittest.TestCase):
    def test_an_unreadable_file_is_a_defective_model_not_a_crash(self):
        judged = control.judge({"format": 1}, FiguresTest.ROWS)
        self.assertFalse(judged.good)
        self.assertEqual([], judged.figures)

    def test_the_score_is_the_mean_pinball_loss_over_horizons(self):
        self.assertAlmostEqual(1.0, control.Verdict([line(pinball=0.5), line(pinball=1.5)], []).score)


class ChooseTest(unittest.TestCase):
    def test_a_better_candidate_is_published(self):
        self.assertEqual("candidat", control.choose(verdict(0.95), verdict(1.0)))

    def test_a_slightly_worse_candidate_is_still_preferred_because_it_is_fresher(self):
        self.assertEqual("candidat", control.choose(verdict(1.0 + control.TOLERANCE - 0.001), verdict(1.0)))

    def test_a_clearly_worse_candidate_leaves_the_published_model_in_place(self):
        self.assertEqual("en_ligne", control.choose(verdict(1.0 + control.TOLERANCE + 0.001), verdict(1.0)))

    def test_a_defective_candidate_is_never_published(self):
        self.assertEqual("en_ligne", control.choose(verdict(0.5, good=False), verdict(1.0)))
        self.assertIsNone(control.choose(verdict(0.5, good=False), verdict(1.0, good=False)))
        self.assertIsNone(control.choose(verdict(0.5, good=False), None))

    def test_a_good_candidate_replaces_a_defective_published_model_whatever_the_scores(self):
        self.assertEqual("candidat", control.choose(verdict(2.0), verdict(1.0, good=False)))
        self.assertEqual("candidat", control.choose(verdict(2.0), control.Verdict([], ["fichier illisible"])))

    def test_without_candidate_the_published_model_is_kept_only_if_still_good(self):
        self.assertEqual("en_ligne", control.choose(None, verdict(1.0)))
        self.assertIsNone(control.choose(None, verdict(1.0, good=False)))


if __name__ == "__main__":
    unittest.main()
