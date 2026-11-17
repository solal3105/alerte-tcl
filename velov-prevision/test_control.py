"""Tests du contrôle et des garde-fous : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import unittest

import numpy as np

import control

DECILES = [10, 30, 50, 70, 90]


def rows(*lines: dict) -> dict:
    return {name: np.array([line[name] for line in lines]) for name in lines[0]}


def line(**changes) -> dict:
    """Chiffres d'un horizon pour une sorte saine (ceux des vélos de l'étude d'origine à 2 h)."""
    base = {"h": 2, "lignes": 80000, "err": 2.48, "err_actuel": 2.88, "couv80": 0.83, "couv40": 0.43, "brier": 0.084,
            "brier_actuel": 0.148, "pinball": 0.96, "pinball_actuel": 1.44}
    return {**base, **changes}


def by_kind(*lines: dict, **own: dict) -> dict:
    """Chiffres d'un modèle : les mêmes horizons pour chaque sorte, sauf celles qui ont leur ligne à elles."""
    return {kind: {"couv80": 0.83, "horizons": [own[kind]] if kind in own else list(lines or (line(),))} for kind in control.KINDS}


def verdict(score: float, good: bool = True) -> control.Verdict:
    return control.Verdict(by_kind(line(pinball=score, pinball_actuel=1.0)), [] if good else ["défaut"])


class FiguresTest(unittest.TestCase):
    # Deux stations à l'horizon d'une heure : cinq vélos puis sept ; aucun puis toujours aucun.
    ROWS = rows(
        {"xq": 4, "elec0": 2, "meca0": 3, "bornes0": 10, "capacite": 15, "y_elec": 3, "y_meca": 4, "y_bornes": 8},
        {"xq": 4, "elec0": 0, "meca0": 0, "bornes0": 15, "capacite": 15, "y_elec": 0, "y_meca": 0, "y_bornes": 15},
    )
    Q = np.array([[4.0, 5, 6, 7, 8], [0, 0, 0, 1, 2]])
    P1 = np.array([0.9, 0.2])

    def kind(self, now: list[int], actual: list[int], xq: tuple[int, ...] = (4, 4)) -> dict:
        return control.kind_figures(self.Q, DECILES, self.P1, np.array(now), np.array(actual), np.array(xq))

    def test_figures_of_one_kind_at_one_horizon(self):
        self.assertEqual({"couv80": 1.0, "horizons": [{
            "h": 1.0, "lignes": 2, "err": 0.5, "err_actuel": 1.0, "couv80": 1.0, "couv40": 1.0, "brier": 0.025, "brier_actuel": 0.0,
            "pinball": 0.2, "pinball_actuel": 0.5,
        }]}, self.kind([5, 0], [7, 0]))

    def test_one_line_per_horizon_and_the_mean_coverage_of_the_kind(self):
        # À 24 h la première station sort de sa fourchette : juste une fois sur deux, donc trois fois sur quatre en moyenne.
        figures = control.kind_figures(np.tile(self.Q, (2, 1)), DECILES, np.tile(self.P1, 2), np.array([5, 0, 5, 0]), np.array([7, 0, 12, 0]), np.array([4, 4, 96, 96]))
        self.assertEqual([(1.0, 1.0), (24.0, 0.5)], [(at["h"], at["couv80"]) for at in figures["horizons"]])
        self.assertEqual(0.75, figures["couv80"])

    def test_a_count_outside_the_band_is_not_covered(self):
        missed = self.kind([5, 0], [12, 3])["horizons"][0]
        self.assertEqual([0.0, 0.0], [missed["couv80"], missed["couv40"]])

    def test_each_kind_is_judged_on_its_own_count(self):
        pred = {"q": {kind: self.Q for kind in control.KINDS}, "p1": {kind: self.P1 for kind in control.KINDS}}
        figures = control.figures(pred, self.ROWS, DECILES)
        self.assertEqual(list(control.KINDS), list(figures))
        # « Comme maintenant » se trompe de 2 vélos, 1 électrique, 1 mécanique et 2 places à la première station, de rien à la seconde.
        self.assertEqual([1.0, 0.5, 0.5, 1.0], [figures[kind]["horizons"][0]["err_actuel"] for kind in control.KINDS])
        self.assertEqual(self.kind([5, 0], [7, 0]), figures["velos"])
        self.assertEqual(self.kind([10, 15], [8, 15]), figures["bornes"])


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
        self.assertEqual([], control.model_defects(by_kind(line(h=0.25, err=1.29, err_actuel=0.88), line())))

    def test_the_band_of_each_kind_must_be_right_about_as_often_as_announced(self):
        for kind, (low, high) in control.COVERAGE_RANGE.items():
            self.assertEqual(1, len(control.model_defects(by_kind(**{kind: line(couv80=low - 0.01)}))), kind)
            self.assertEqual(1, len(control.model_defects(by_kind(**{kind: line(couv80=high + 0.01)}))), kind)
            self.assertEqual([], control.model_defects(by_kind(**{kind: line(couv80=low)})), kind)
            self.assertEqual([], control.model_defects(by_kind(**{kind: line(couv80=high)})), kind)

    def test_the_median_of_each_kind_must_beat_same_as_now_from_its_horizon(self):
        for kind, first in control.MEDIAN_BEATS_FROM.items():
            self.assertEqual(1, len(control.model_defects(by_kind(**{kind: line(h=first, err=2.88)}))), kind)
            self.assertEqual(1, len(control.model_defects(by_kind(**{kind: line(h=24, err=4.5, err_actuel=4.4)}))), kind)
            self.assertEqual([], control.model_defects(by_kind(**{kind: line(h=first / 2, err=2.88)})), kind)

    def test_the_probability_of_each_kind_must_beat_same_as_now_from_two_hours(self):
        for kind in control.KINDS:
            self.assertEqual(1, len(control.model_defects(by_kind(**{kind: line(brier=0.148)}))), kind)
            self.assertEqual([], control.model_defects(by_kind(**{kind: line(h=1, brier=0.148)})), kind)

    def test_a_defect_names_the_kind_and_the_horizon(self):
        self.assertEqual(["fourchette 10-90 des vélos électriques juste 40% du temps à 2 h"], control.model_defects(by_kind(elec=line(couv80=0.4))))


class JudgeTest(unittest.TestCase):
    def test_an_unreadable_file_is_a_defective_model_not_a_crash(self):
        judged = control.judge({"format": 1}, FiguresTest.ROWS)
        self.assertFalse(judged.good)
        self.assertEqual({}, judged.figures)

    def test_the_score_gives_each_kind_of_bike_the_same_weight_whatever_its_counts(self):
        # Pinball rapporté à « comme maintenant », sommés sur les horizons : 0,5 pour les vélos, 0,9 et 1 pour les deux autres.
        figures = by_kind(line(pinball=0.4, pinball_actuel=1.2), line(pinball=0.6, pinball_actuel=0.8),
                          elec=line(pinball=0.09, pinball_actuel=0.1), meca=line(pinball=0.3, pinball_actuel=0.3), bornes=line(pinball=50))
        self.assertAlmostEqual(0.8, control.Verdict(figures, []).score)


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
        self.assertEqual("candidat", control.choose(verdict(2.0), control.Verdict({}, ["fichier illisible"])))

    def test_without_candidate_the_published_model_is_kept_only_if_still_good(self):
        self.assertEqual("en_ligne", control.choose(None, verdict(1.0)))
        self.assertIsNone(control.choose(None, verdict(1.0, good=False)))


if __name__ == "__main__":
    unittest.main()
