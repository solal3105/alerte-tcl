"""Tests du déroulé hebdomadaire et de ses garde-fous : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import argparse
import json
import os
import tempfile
import unittest
from unittest import mock

import numpy as np

import build_forecast
import bundle
import control
from readings import Grid
from test_control import verdict

DAY = 86_400
# Lundi 26 octobre 2026, 02:15 UTC : heure d'un passage planifié.
NOW = 1792980900

GOOD = verdict(1.0)
BAD = verdict(1.0, good=False)


CALENDAR = {"feries": ["2026-11-01"], "vacances": [[1792188000000, 1793574000000]]}


def model(version: str, generated: int = 1, calendar: dict = CALENDAR) -> bytes:
    return bundle.encode({"format": 1, "version": version, "genere": generated, "calendrier": calendar, "stations": []})


def grid(days: float, end: int = NOW) -> Grid:
    """Grille vide de `days` jours finissant à `end` : seules ses bornes comptent ici."""
    slots = int(days * 96)
    cells = np.zeros((slots, 1), dtype=bool)
    return Grid(end // 900 * 900 - slots * 900, np.array([1001]), cells, cells, cells, cells, cells, cells)


class RunTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.seed = os.path.join(self.folder.name, "amorce.json")
        with open(self.seed, "wb") as out:
            out.write(model("2026-10-20"))
        self.online = os.path.join(self.folder.name, "en-ligne")
        self.out = os.path.join(self.folder.name, "out")

    def publish(self, version: str, verified: int, content: bytes | None = None) -> bytes:
        """Met un modèle « en ligne » (copie locale de la branche)."""
        content = model(version, generated=verified - 3600) if content is None else content
        os.makedirs(self.online)
        with open(os.path.join(self.online, "modele.json"), "wb") as out:
            out.write(content)
        with open(os.path.join(self.online, "index.json"), "wb") as out:
            out.write(bundle.encode({"format": 1, "version": version, "genere": verified - 3600, "verifie": verified, "taille": len(content)}))
        return content

    def run_robot(self, online: control.Verdict = GOOD, candidate=build_forecast.TooEarly("trop tôt"), readings_grid=None,
                  holes: tuple[str, ...] = (), scheduled: bool = False, calendar: dict = CALENDAR) -> list[str]:
        """Une exécution avec un relais, un calendrier, un contrôle et un entraînement simulés. `candidate` :
        le verdict du modèle de la semaine (version 2026-10-19), ou l'erreur que lève son entraînement."""
        readings_grid = grid(30) if readings_grid is None else readings_grid
        trained = candidate if isinstance(candidate, Exception) else (json.loads(model("2026-10-19", NOW)), candidate)
        args = argparse.Namespace(relais="https://relais.example", en_ligne=self.online, amorce=self.seed, out=self.out, planifie=scheduled, cache=None)
        with mock.patch("readings.download", side_effect=readings_grid if isinstance(readings_grid, Exception) else None) as self.download, \
                mock.patch("readings.build_grid", return_value=None if isinstance(readings_grid, Exception) else readings_grid), \
                mock.patch("training.control_rows", return_value={"xq": np.zeros(3)}), \
                mock.patch("control.week_defects", return_value=list(holes)), \
                mock.patch("control.judge", return_value=online) as self.judge, \
                mock.patch("holidays.build_calendar", return_value=(calendar, None)), \
                mock.patch("build_forecast.live_stations", return_value=[]), \
                mock.patch("build_forecast.build_candidate", side_effect=trained if isinstance(trained, Exception) else None, return_value=trained) as self.training, \
                mock.patch("build_forecast.log"):
            return build_forecast.run(args, NOW)

    def written(self) -> tuple[dict, bytes] | None:
        if not os.path.exists(self.out):
            return None
        with open(os.path.join(self.out, "index.json"), "rb") as index, open(os.path.join(self.out, "modele.json"), "rb") as content:
            return json.load(index), content.read()

    def test_the_seed_is_published_once_it_passes_the_check(self):
        self.assertEqual([], self.run_robot())
        index, content = self.written()
        self.assertEqual(model("2026-10-20"), content)
        self.assertEqual({"format": 1, "version": "2026-10-20", "genere": 1, "verifie": NOW, "taille": len(content)}, index)

    def test_before_any_publication_an_aged_seed_is_not_an_incident(self):
        self.assertEqual([], self.run_robot(online=BAD))
        self.assertIsNone(self.written())

    def test_a_good_candidate_is_published(self):
        self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot(candidate=GOOD))
        index, content = self.written()
        self.assertEqual("2026-10-19", json.loads(content)["version"])
        self.assertEqual({"format": 1, "version": "2026-10-19", "genere": NOW, "verifie": NOW, "taille": len(content)}, index)

    def test_a_clearly_worse_candidate_leaves_the_published_model_untouched_with_a_fresh_check(self):
        published = self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot(candidate=verdict(1.2)))
        index, content = self.written()
        self.assertEqual(published, content)
        self.assertEqual({"format": 1, "version": "2026-10-12", "genere": NOW - 7 * DAY - 3600, "verifie": NOW, "taille": len(content)}, index)

    def test_a_kept_model_is_republished_with_the_calendar_of_the_day(self):
        self.publish("2026-10-12", NOW - 7 * DAY)
        longer = {"feries": ["2026-11-01", "2028-12-25"], "vacances": CALENDAR["vacances"] + [[1797634800000, 1799017200000]]}
        self.assertEqual([], self.run_robot(calendar=longer))
        index, content = self.written()
        self.assertEqual(model("2026-10-12", NOW - 7 * DAY - 3600, longer), content)
        self.assertEqual({"format": 1, "version": "2026-10-12", "genere": NOW - 7 * DAY - 3600, "verifie": NOW, "taille": len(content)}, index)
        # Le modèle est noté avec le calendrier qu'il portera une fois republié.
        self.assertEqual(longer, self.judge.call_args.args[0]["calendrier"])

    def test_the_seed_is_first_published_with_the_calendar_of_the_day(self):
        longer = {"feries": ["2028-12-25"], "vacances": []}
        self.assertEqual([], self.run_robot(calendar=longer))
        self.assertEqual(model("2026-10-20", calendar=longer), self.written()[1])

    def test_a_defective_candidate_is_not_published(self):
        published = self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot(candidate=BAD))
        self.assertEqual(published, self.written()[1])

    def test_when_no_model_is_good_nothing_is_published_and_the_run_fails(self):
        self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual(1, len(self.run_robot(online=BAD, candidate=BAD)))
        self.assertIsNone(self.written())
        self.assertEqual(1, len(self.run_robot(online=BAD)))
        self.assertIsNone(self.written())

    def test_a_failed_training_keeps_the_published_model_and_fails_the_run(self):
        published = self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual(1, len(self.run_robot(candidate=ValueError("le lecteur s'écarte de LightGBM"))))
        index, content = self.written()
        self.assertEqual((published, NOW), (content, index["verifie"]))

    def test_too_little_history_to_train_is_not_an_incident(self):
        published = self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot())
        self.assertEqual(published, self.written()[1])

    def test_the_model_of_the_week_is_not_trained_twice(self):
        published = self.publish("2026-10-19", NOW - DAY)
        self.assertEqual([], self.run_robot(candidate=GOOD))
        self.training.assert_not_called()
        index, content = self.written()
        self.assertEqual((published, NOW), (content, index["verifie"]))

    def test_an_unreadable_published_model_is_replaced_by_a_good_candidate(self):
        self.publish("2026-10-12", NOW - 7 * DAY, content=b"{tronqu")
        self.assertEqual([], self.run_robot(online=control.Verdict({}, ["fichier illisible"]), candidate=GOOD))
        self.assertEqual("2026-10-19", self.written()[0]["version"])

    def test_a_relay_outage_changes_nothing_and_is_silent(self):
        self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot(readings_grid=OSError("relais en panne")))
        self.assertIsNone(self.written())

    def test_readings_that_stopped_days_ago_do_not_refresh_the_check(self):
        self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot(readings_grid=grid(30, end=NOW - 3 * DAY)))
        self.assertIsNone(self.written())

    def test_less_than_a_week_of_readings_cannot_check_anything(self):
        self.assertEqual([], self.run_robot(readings_grid=grid(6.5)))
        self.assertIsNone(self.written())

    def test_a_week_with_holes_does_not_refresh_the_check(self):
        self.publish("2026-10-12", NOW - 7 * DAY)
        self.assertEqual([], self.run_robot(holes=("12 heures de départ relevées",)))
        self.assertIsNone(self.written())
        self.training.assert_not_called()

    def test_two_weeks_without_a_check_fail_the_run(self):
        self.publish("2026-10-05", NOW - build_forecast.ALERT_AFTER - 3600)
        self.assertEqual(1, len(self.run_robot(readings_grid=OSError("relais en panne"))))
        self.assertEqual(1, len(self.run_robot(holes=("12 heures de départ relevées",))))
        self.assertIsNone(self.written())

    def test_the_catch_up_run_does_nothing_after_a_recent_check(self):
        self.publish("2026-10-19", NOW - 2 * DAY)
        self.assertEqual([], self.run_robot(candidate=GOOD, scheduled=True))
        self.download.assert_not_called()
        self.assertIsNone(self.written())

    def test_the_weekly_run_works_again_five_days_after_a_catch_up(self):
        self.publish("2026-10-14", NOW - 5 * DAY)
        self.assertEqual([], self.run_robot(candidate=GOOD, scheduled=True))
        self.assertEqual("2026-10-19", self.written()[0]["version"])

    def test_a_manual_run_always_checks(self):
        self.publish("2026-10-12", NOW - DAY)
        self.assertEqual([], self.run_robot(candidate=GOOD))
        self.assertEqual("2026-10-19", self.written()[0]["version"])


class CandidateTest(unittest.TestCase):
    def test_no_candidate_below_three_weeks_of_training(self):
        with self.assertRaises(build_forecast.TooEarly), mock.patch("training.train") as train:
            build_forecast.build_candidate(grid(27), 20 * 96, {}, CALENDAR, [], NOW)
        train.assert_not_called()

    def test_no_candidate_when_the_training_weeks_are_mostly_holes(self):
        with self.assertRaises(build_forecast.TooEarly), mock.patch("training.train") as train:
            build_forecast.build_candidate(grid(40), 33 * 96, {}, CALENDAR, [], NOW)
        train.assert_not_called()


class PublishedFilesTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)

    def test_what_is_written_is_read_back(self):
        content = model("2026-10-19", 123)
        index = bundle.write(self.folder.name, content, 456)
        self.assertEqual({"format": 1, "version": "2026-10-19", "genere": 123, "verifie": 456, "taille": len(content)}, index)
        self.assertEqual((index, content), bundle.read_published(self.folder.name))

    def test_nothing_published_yet(self):
        self.assertEqual((None, None), bundle.read_published(None))
        self.assertEqual((None, None), bundle.read_published(os.path.join(self.folder.name, "absent")))

    def test_an_unusable_index_counts_as_nothing_published(self):
        bundle.write(self.folder.name, model("2026-10-19"), 456)
        for broken in (b"{", b"[]", b'{"version":"2026-10-19"}', b'{"version":"2026-10-19","verifie":"hier"}'):
            with open(os.path.join(self.folder.name, "index.json"), "wb") as out:
                out.write(broken)
            self.assertEqual((None, None), bundle.read_published(self.folder.name))

    def test_station_names_keep_their_accents(self):
        self.assertIn("Vénissieux".encode("utf-8"), bundle.encode({"nom": "Vénissieux"}))

    def test_the_seed_of_the_repository_is_a_complete_model(self):
        with open(bundle.SEED_PATH, "rb") as source:
            seed = json.load(source)
        self.assertEqual(bundle.FORMAT, seed["format"])
        self.assertEqual({"version", "genere", "variables", "deciles", "modeles", "habitude", "stations", "calendrier", "controle"}, set(seed) - {"format"})
        self.assertEqual(19, len(seed["modeles"]))
        # Le contrôle de l'amorce est le sien : l'application y lit la justesse annoncée de chaque sorte.
        self.assertEqual(set(control.KINDS), set(seed["controle"]["sortes"]))


if __name__ == "__main__":
    unittest.main()
