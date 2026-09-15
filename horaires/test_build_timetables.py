"""Tests des règles du script de fiches horaires : `python3 -m unittest discover -s horaires`."""
from __future__ import annotations

import datetime as dt
import unittest
from collections import Counter

import build_timetables as bt


class CoverageLimitTest(unittest.TestCase):
    def counts(self, weekday_trips: int, days: int, cliff_after: int | None = None) -> Counter:
        """Semaine type : 100 % en semaine, 68 % le samedi, 41 % le dimanche ; offre presque vide après la falaise."""
        start = dt.date(2026, 9, 15)
        c = Counter()
        for d in range(days):
            weekday = (start + dt.timedelta(days=d)).weekday()
            full = weekday_trips if weekday < 5 else (weekday_trips * 68 // 100 if weekday == 5 else weekday_trips * 41 // 100)
            c[d] = full if cliff_after is None or d <= cliff_after else weekday_trips // 20
        return c

    def test_stops_at_the_first_incomplete_day(self):
        start = dt.date(2026, 9, 15)
        self.assertEqual(77, bt.coverage_limit(self.counts(20000, 120, cliff_after=77), start, 120))

    def test_covers_the_whole_horizon_when_the_offer_is_complete(self):
        start = dt.date(2026, 9, 15)
        self.assertEqual(119, bt.coverage_limit(self.counts(20000, 120), start, 120))

    def test_a_holiday_with_sunday_service_does_not_end_the_coverage(self):
        start = dt.date(2026, 9, 15)
        counts = self.counts(20000, 120)
        counts[30] = 20000 * 41 // 100  # jour férié en semaine, service du dimanche
        self.assertEqual(119, bt.coverage_limit(counts, start, 120))

    def test_nothing_covered_when_the_first_day_is_empty(self):
        start = dt.date(2026, 9, 15)
        counts = self.counts(20000, 120)
        counts[0] = 0
        self.assertEqual(-1, bt.coverage_limit(counts, start, 120))


class HelpersTest(unittest.TestCase):
    def test_minutes_keep_times_after_midnight(self):
        self.assertEqual(1507, bt.parse_minutes("25:07:30"))
        self.assertIsNone(bt.parse_minutes(""))

    def test_line_keys_and_names(self):
        self.assertEqual("C15E", bt.line_key("c15e"))
        self.assertEqual("RX", bt.commercial_name("Rhônexpress", "RX", "0"))
        self.assertEqual("N1", bt.commercial_name("1", "SYTRAL", "4"))
        self.assertEqual("#004F9F", bt.hex_color("004f9f", "#FFFFFF"))
        self.assertEqual("#FFFFFF", bt.hex_color("bleu", "#FFFFFF"))


if __name__ == "__main__":
    unittest.main()
