"""Tests du calendrier (jours fériés, vacances scolaires) : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import datetime as dt
import io
import json
import unittest
from unittest import mock

import holidays

TODAY = dt.date(2026, 11, 16)
DAY_MS = holidays.DAY_MS


def ms(text: str) -> int:
    return int(dt.datetime.fromisoformat(text).timestamp() * 1000)


def record(description: str, start: str, end: str | None, population: str = "-") -> dict:
    return {"description": description, "start_date": start, "end_date": end, "population": population, "location": "Lyon", "zones": "Zone A"}


TOUSSAINT = record("Vacances de la Toussaint", "2026-10-17T00:00:00+02:00", "2026-11-02T00:00:00+01:00")
NOEL = record("Vacances de Noël", "2026-12-19T00:00:00+01:00", "2027-01-04T00:00:00+01:00")
HIVER = record("Vacances d'Hiver", "2027-02-13T00:00:00+01:00", "2027-03-01T00:00:00+01:00")


class PublicHolidaysTest(unittest.TestCase):
    def test_easter_sunday(self):
        known = {2023: (4, 9), 2024: (3, 31), 2025: (4, 20), 2026: (4, 5), 2027: (3, 28), 2030: (4, 21), 2038: (4, 25)}
        for year, (month, day) in known.items():
            self.assertEqual(dt.date(year, month, day), holidays.easter(year))

    def test_the_eleven_holidays_of_a_year(self):
        days = [day for day in holidays.public_holidays(TODAY) if day.startswith("2026")]
        self.assertEqual(["2026-01-01", "2026-04-06", "2026-05-01", "2026-05-08", "2026-05-14", "2026-05-25",
                          "2026-07-14", "2026-08-15", "2026-11-01", "2026-11-11", "2026-12-25"], days)

    def test_the_window_covers_last_year_and_two_years_ahead(self):
        days = holidays.public_holidays(TODAY)
        self.assertEqual(("2025-01-01", "2028-12-25", 44), (days[0], days[-1], len(days)))


class SchoolHolidaysTest(unittest.TestCase):
    def test_periods_are_sorted_in_epoch_milliseconds(self):
        periods = holidays.parse_school_holidays([NOEL, TOUSSAINT], TODAY)
        self.assertEqual([[ms("2026-10-16T22:00:00+00:00"), ms("2026-11-01T23:00:00+00:00")],
                          [ms("2026-12-18T23:00:00+00:00"), ms("2027-01-03T23:00:00+00:00")]], periods)

    def test_teacher_only_rows_and_open_ended_periods_are_ignored(self):
        records = [TOUSSAINT, record("Vacances d'Été", "2027-07-03T00:00:00+02:00", None),
                   record("Prérentrée", "2026-08-28T00:00:00+02:00", "2026-08-31T00:00:00+02:00", "Enseignants")]
        self.assertEqual(1, len(holidays.parse_school_holidays(records, TODAY)))

    def test_duplicated_or_overlapping_rows_are_merged(self):
        longer = record("Vacances de la Toussaint", "2026-10-17T00:00:00+02:00", "2026-11-03T00:00:00+01:00", "Élèves")
        periods = holidays.parse_school_holidays([TOUSSAINT, longer, TOUSSAINT], TODAY)
        self.assertEqual([[ms("2026-10-16T22:00:00+00:00"), ms("2026-11-02T23:00:00+00:00")]], periods)

    def test_periods_ended_long_ago_are_dropped(self):
        old = record("Vacances de Printemps", "2025-04-19T00:00:00+02:00", "2025-05-05T00:00:00+02:00")
        self.assertEqual(1, len(holidays.parse_school_holidays([old, TOUSSAINT], TODAY)))

    def test_defects(self):
        good = holidays.parse_school_holidays([TOUSSAINT, NOEL, HIVER], TODAY)
        self.assertIsNone(holidays.school_holidays_defect(good))
        self.assertIsNotNone(holidays.school_holidays_defect(good[:2]))
        self.assertIsNotNone(holidays.school_holidays_defect(good + [[good[-1][1] + DAY_MS, good[-1][1] + 200 * DAY_MS]]))
        self.assertIsNotNone(holidays.school_holidays_defect(good + [[5, 5]]))


class CalendarChoiceTest(unittest.TestCase):
    FETCHED = holidays.parse_school_holidays([TOUSSAINT, NOEL, HIVER], TODAY)
    PUBLISHED = holidays.parse_school_holidays([TOUSSAINT, NOEL], TODAY)

    def test_a_sound_answer_replaces_the_published_holidays(self):
        self.assertEqual((self.FETCHED, None), holidays.choose_school_holidays(self.FETCHED, self.PUBLISHED))

    def test_without_answer_the_published_holidays_are_kept(self):
        chosen, reason = holidays.choose_school_holidays(None, self.PUBLISHED)
        self.assertEqual(self.PUBLISHED, chosen)
        self.assertIsNotNone(reason)

    def test_a_truncated_answer_is_refused(self):
        chosen, reason = holidays.choose_school_holidays(self.FETCHED[:1], self.PUBLISHED)
        self.assertEqual(self.PUBLISHED, chosen)
        self.assertIsNotNone(reason)

    def test_the_calendar_never_looks_less_far_than_the_published_one(self):
        further = self.FETCHED + [[self.FETCHED[-1][1] + 40 * DAY_MS, self.FETCHED[-1][1] + 56 * DAY_MS]]
        chosen, reason = holidays.choose_school_holidays(self.FETCHED, further)
        self.assertEqual(further, chosen)
        self.assertIsNotNone(reason)

    def test_an_api_failure_never_blocks_the_calendar(self):
        with mock.patch("urllib.request.urlopen", side_effect=OSError("panne")):
            calendar, reason = holidays.build_calendar(TODAY, {"feries": [], "vacances": self.PUBLISHED})
        self.assertEqual(self.PUBLISHED, calendar["vacances"])
        self.assertEqual(holidays.public_holidays(TODAY), calendar["feries"])
        self.assertIsNotNone(reason)

    def test_the_api_answer_is_read_as_published_by_the_ministry(self):
        body = io.BytesIO(json.dumps([TOUSSAINT, NOEL, HIVER]).encode())
        with mock.patch("urllib.request.urlopen", return_value=body) as urlopen:
            calendar, reason = holidays.build_calendar(TODAY, {})
        self.assertIn("where=location%3D%27Lyon%27", urlopen.call_args.args[0].full_url)
        self.assertEqual((self.FETCHED, None), (calendar["vacances"], reason))


if __name__ == "__main__":
    unittest.main()
