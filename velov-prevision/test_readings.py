"""Tests de la lecture des relevés : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import datetime as dt
import gzip
import json
import os
import tempfile
import unittest
from unittest import mock

import numpy as np

import readings

# Lundi 5 octobre 2026, 00:00 UTC.
T0 = 1791158400
HOUR = 3600


def snapshot(minutes: float, *stations: list[int]) -> dict:
    return {"t": T0 + int(minutes * 60), "stations": list(stations)}


def document(*snapshots: dict, fields: tuple[str, ...] = readings.FIELDS) -> dict:
    return {"jour": "2026-10-05", "champs": list(fields), "releves": list(snapshots)}


def grid_of(*snapshots: dict) -> readings.Grid:
    return readings.build_grid(readings.day_table(document(*snapshots)))


class DayTableTest(unittest.TestCase):
    def test_columns_are_found_by_name(self):
        doc = document(snapshot(0, [1, 15, 10, 2, 3, 1001]), fields=("ouvert", "capacite", "places", "meca", "elec", "id"))
        self.assertEqual([[T0, 1001, 3, 2, 10, 15, 1]], readings.day_table(doc).tolist())

    def test_a_malformed_snapshot_is_skipped(self):
        doc = document(snapshot(0, [1001, 3, 2, 10, 15, 1]), {"t": T0 + 300, "stations": [[1001, 3]]},
                       {"t": T0 + 600, "stations": [[1001, None, 2, 10, 15, 1]]}, {"t": T0 + 900, "stations": []})
        self.assertEqual([[T0, 1001, 3, 2, 10, 15, 1]], readings.day_table(doc).tolist())

    def test_a_day_without_readings(self):
        self.assertEqual((0, 7), readings.day_table(document()).shape)


class GridTest(unittest.TestCase):
    def test_the_last_reading_of_each_quarter_is_kept(self):
        grid = grid_of(snapshot(0, [1001, 3, 2, 10, 15, 1]), snapshot(5, [1001, 4, 2, 9, 15, 1]),
                       snapshot(10, [1001, 5, 1, 9, 15, 1]), snapshot(15, [1001, 0, 1, 14, 15, 1]))
        self.assertEqual(T0, grid.start)
        self.assertEqual(T0 + 1800, grid.end)
        self.assertEqual([[5], [0]], grid.elec.tolist())
        self.assertEqual([[1], [1]], grid.meca.tolist())
        self.assertEqual([[9], [14]], grid.bornes.tolist())
        self.assertEqual([[True], [True]], grid.valid.tolist())

    def test_snapshots_may_arrive_in_any_order(self):
        grid = grid_of(snapshot(10, [1001, 5, 1, 9, 15, 1]), snapshot(0, [1001, 3, 2, 10, 15, 1]))
        self.assertEqual([[5]], grid.elec.tolist())

    def test_capacity_is_the_largest_seen_and_a_station_must_stay_open(self):
        grid = grid_of(snapshot(0, [1001, 3, 2, 10, 15, 1], [1002, 1, 1, 1, 20, 0]),
                       snapshot(5, [1001, 3, 2, 10, 14, 1], [1002, 1, 1, 1, 20, 1]))
        self.assertEqual([1001, 1002], grid.stations.tolist())
        self.assertEqual([[15, 20]], grid.capacite.tolist())
        self.assertEqual([[True, False]], grid.valid.tolist())

    def test_a_station_without_capacity_is_not_usable(self):
        self.assertEqual([[False]], grid_of(snapshot(0, [1001, 0, 0, 0, 0, 1])).valid.tolist())

    def test_a_quarter_without_reading_is_absent(self):
        grid = grid_of(snapshot(0, [1001, 3, 2, 10, 15, 1], [1002, 1, 1, 1, 20, 1]), snapshot(30, [1001, 3, 2, 10, 15, 1]))
        self.assertEqual([[True, True], [False, False], [True, False]], grid.present.tolist())
        self.assertEqual([[True, True], [False, False], [True, False]], grid.valid.tolist())

    def test_no_reading_at_all(self):
        self.assertIsNone(readings.build_grid(readings.day_table(document())))


class FrozenTest(unittest.TestCase):
    def periods(self, bikes_by_hour: list[int | None], closed: tuple[int, ...] = ()) -> list[tuple[int, int, int]]:
        """Une station relevée toutes les 20 minutes ; None : heure sans relevé ; `closed` : heures fermées."""
        t, velos, ouvert = [], [], []
        for hour, bikes in enumerate(bikes_by_hour):
            if bikes is not None:
                t += [T0 + hour * HOUR + minute * 60 for minute in (5, 25, 45)]
                velos += [bikes] * 3
                ouvert += [hour not in closed] * 3
        return readings.frozen_periods(np.full(len(t), 1001), np.array(t), np.array(velos), np.array(ouvert, dtype=np.int64))

    def test_48_still_hours_are_a_frozen_period(self):
        # L'heure 0 pose 4 vélos, l'heure 1 passe à 5 (elle bouge), puis plus rien pendant 48 heures.
        self.assertEqual([(1001, T0 + 2 * HOUR, T0 + 49 * HOUR)], self.periods([4] + [5] * 49 + [6]))

    def test_47_still_hours_are_not(self):
        self.assertEqual([], self.periods([4] + [5] * 48 + [6]))

    def test_the_first_hours_read_count_as_still(self):
        self.assertEqual([(1001, T0, T0 + 47 * HOUR)], self.periods([5] * 48 + [6]))

    def test_closed_or_missing_hours_neither_count_nor_break_the_series(self):
        hours = [4] + [5] * 30 + [None] * 5 + [5] * 5 + [5] * 19 + [6]
        self.assertEqual([(1001, T0 + 2 * HOUR, T0 + 59 * HOUR)], self.periods(hours, closed=(36, 37, 38, 39, 40)))
        self.assertEqual([], self.periods(hours[:-2] + [6], closed=(36, 37, 38, 39, 40)))

    def test_two_stations_never_share_a_series(self):
        t = np.array([T0 + hour * HOUR for hour in range(30)] * 2)
        periods = readings.frozen_periods(np.repeat([1001, 1002], 30), t, np.full(60, 5), np.ones(60, dtype=np.int64))
        self.assertEqual([], periods)

    def test_a_frozen_period_is_unusable_until_one_hour_after_its_last_hour(self):
        snapshots = [snapshot(20 * i, [1001, 5 if i < 150 else 6, 0, 10, 15, 1], [1002, i % 7, 0, 10, 15, 1]) for i in range(160)]
        grid = grid_of(*snapshots)
        # La station 1001 ne bouge pas des heures 0 à 49 (relevé 150 = heure 50) : invalide jusqu'à 50 h 00 incluse.
        frozen = ~grid.valid[:, 0]
        self.assertTrue(frozen[:50 * 4 + 1].all())
        self.assertFalse(frozen[50 * 4 + 1:][grid.present[50 * 4 + 1:, 0]].any())
        self.assertTrue(grid.valid[:, 1][grid.present[:, 1]].all())


class FakeResponse:
    def __init__(self, body: bytes, encoding: str | None = None):
        self.body, self.headers = body, {"Content-Encoding": encoding} if encoding else {}

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def read(self) -> bytes:
        return self.body


class RelayTest(unittest.TestCase):
    def test_the_relay_is_called_with_its_expected_user_agent(self):
        with mock.patch("urllib.request.urlopen", return_value=FakeResponse(b'{"jours":[]}')) as urlopen:
            self.assertEqual({"jours": []}, readings.fetch_json("https://relais.example/", "/velov-releves"))
        request = urlopen.call_args.args[0]
        self.assertEqual("https://relais.example/velov-releves", request.full_url)
        self.assertTrue(request.get_header("User-agent").startswith("AlerteTCL/"))

    def test_a_compressed_answer_is_decompressed(self):
        body = gzip.compress(json.dumps({"jours": ["2026-10-05"]}).encode())
        with mock.patch("urllib.request.urlopen", return_value=FakeResponse(body, "gzip")):
            self.assertEqual({"jours": ["2026-10-05"]}, readings.fetch_json("https://relais.example", "/velov-releves"))

    def test_a_failed_request_is_retried_after_a_growing_wait(self):
        waits = []
        answers = [OSError("503"), OSError("503"), FakeResponse(b"{}")]
        with mock.patch("urllib.request.urlopen", side_effect=answers):
            self.assertEqual({}, readings.fetch_json("https://relais.example", "/velov", wait=waits.append))
        self.assertEqual(list(readings.RETRY_DELAYS[:2]), waits)

    def test_a_request_that_keeps_failing_gives_up(self):
        waits = []
        with mock.patch("urllib.request.urlopen", side_effect=OSError("panne")):
            with self.assertRaises(OSError):
                readings.fetch_json("https://relais.example", "/velov", wait=waits.append)
        self.assertEqual(list(readings.RETRY_DELAYS), waits)



# Mardi 6 octobre 2026, 02:15 UTC : les 4 et 5 octobre sont terminés, le 6 est en cours.
NOW = T0 + 86_400 + 8100


class DownloadTest(unittest.TestCase):
    DAYS = ["2026-10-03", "2026-10-05", "2026-10-04", "2026-10-06"]

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.asked = []
        self.failing = ()

    def answer(self, base_url: str, path: str, wait=None) -> bytes:
        self.asked.append(path)
        if path == "/velov-releves":
            return json.dumps({"jours": self.DAYS}).encode()
        if path.endswith(self.failing):
            raise OSError("panne")
        return json.dumps(document(snapshot(0, [1001, 3, 2, 10, 15, 1]))).encode()

    def download(self, cache: str | None = None) -> np.ndarray:
        with mock.patch("readings.fetch", side_effect=self.answer):
            return readings.download("https://relais.example", dt.date(2026, 10, 4), NOW, cache, lambda msg: None)

    def test_days_are_read_in_order_from_the_first_wanted_day(self):
        self.assertEqual(3, len(self.download()))
        self.assertEqual(["/velov-releves", "/velov-releves?jour=2026-10-04", "/velov-releves?jour=2026-10-05", "/velov-releves?jour=2026-10-06"], self.asked)

    def test_an_unreadable_day_is_skipped(self):
        self.failing = ("2026-10-05",)
        self.assertEqual(2, len(self.download()))

    def test_reading_stops_when_the_relay_keeps_failing(self):
        self.DAYS = [f"2026-10-{day:02d}" for day in range(4, 14)]
        self.failing = tuple(self.DAYS)
        with self.assertRaises(OSError):
            self.download()
        self.assertEqual(1 + readings.MAX_FAILED_DAYS, len(self.asked))

    def test_finished_days_are_kept_and_not_asked_again(self):
        first = self.download(self.folder.name)
        self.assertEqual(["2026-10-04.json.gz", "2026-10-05.json.gz"], sorted(os.listdir(self.folder.name)))
        self.asked.clear()
        np.testing.assert_array_equal(first, self.download(self.folder.name))
        self.assertEqual(["/velov-releves", "/velov-releves?jour=2026-10-06"], self.asked)

    def test_a_kept_day_survives_its_disappearance_from_the_relay(self):
        self.download(self.folder.name)
        self.DAYS = ["2026-10-06"]
        self.assertEqual(3, len(self.download(self.folder.name)))

    def test_a_damaged_copy_is_read_again_from_the_relay(self):
        self.download(self.folder.name)
        with open(os.path.join(self.folder.name, "2026-10-04.json.gz"), "wb") as out:
            out.write(b"abime")
        self.asked.clear()
        self.assertEqual(3, len(self.download(self.folder.name)))
        self.assertIn("/velov-releves?jour=2026-10-04", self.asked)
        with gzip.open(os.path.join(self.folder.name, "2026-10-04.json.gz")) as source:
            self.assertEqual(1, len(json.load(source)["releves"]))

    def test_copies_older_than_the_first_wanted_day_are_removed(self):
        old = os.path.join(self.folder.name, "2026-10-01.json.gz")
        with open(old, "wb") as out:
            out.write(b"")
        self.download(self.folder.name)
        self.assertFalse(os.path.exists(old))

    def test_the_cache_folder_is_optional_and_created_when_needed(self):
        cache = os.path.join(self.folder.name, "absent")
        self.assertEqual(3, len(self.download(cache)))
        self.assertEqual(2, len(os.listdir(cache)))


if __name__ == "__main__":
    unittest.main()
