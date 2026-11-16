"""Tests des fiches de stations : `python3 -m unittest discover -s velov-prevision`."""
from __future__ import annotations

import unittest

import numpy as np

import stations
from readings import Grid

SURVEYED = [{"id": 1001, "nom": "Terreaux", "commune": "Lyon 1er", "cap": 20, "altitude": 170.0, "dist_metro_km": 0.1,
             "dist_tram_km": 0.9, "dist_gare_km": 1.8, "lat": 45.7675, "lon": 4.8335}]


def live(station: int, lat: float, lon: float, name: str = "1002 - NOUVELLE STATION") -> dict:
    return {"id": station, "name": name, "lat": lat, "lng": lon, "capacity": 12}


def grid(station_ids: list[int], capacities: list[list[int]], present: list[list[bool]]) -> Grid:
    capacite = np.array(capacities, dtype=np.int16)
    seen = np.array(present)
    return Grid(0, np.array(station_ids), capacite, capacite, capacite, capacite, seen, seen)


class StationsTest(unittest.TestCase):
    def test_a_surveyed_station_keeps_its_landmarks_and_takes_its_last_read_capacity(self):
        described = stations.describe(grid([1001], [[20], [18], [0]], [[True], [True], [False]]), SURVEYED, [], [live(1001, 0, 0)])
        self.assertEqual([{**SURVEYED[0], "cap": 18}], described)

    def test_a_new_station_borrows_the_landmarks_of_a_surveyed_station_nearby(self):
        described = stations.describe(grid([1002], [[12]], [[True]]), SURVEYED, [], [live(1002, 45.7690, 4.8340)])
        self.assertEqual({"id": 1002, "nom": "Nouvelle Station", "commune": "", "lat": 45.7690, "lon": 4.8340, "altitude": 170.0,
                          "dist_metro_km": 0.1, "dist_tram_km": 0.9, "dist_gare_km": 1.8, "cap": 12}, described[0])

    def test_a_new_station_far_from_any_surveyed_one_has_no_landmark(self):
        described = stations.describe(grid([1002], [[12]], [[True]]), SURVEYED, [], [live(1002, 45.80, 4.90)])
        self.assertEqual({"id": 1002, "nom": "Nouvelle Station", "commune": "", "lat": 45.80, "lon": 4.90, "cap": 12}, described[0])

    def test_without_the_relay_the_published_entry_is_kept(self):
        published = [{"id": 1002, "nom": "Nouvelle Station", "commune": "", "lat": 45.80, "lon": 4.90, "cap": 10}]
        described = stations.describe(grid([1002, 1003], [[12, 5]], [[True, True]]), SURVEYED, published, [])
        self.assertEqual([{**published[0], "cap": 12}], described)

    def test_names_are_shown_as_in_the_prototype(self):
        self.assertEqual("Vénissieux - Joliot Curie / Sembat", stations.display_name("16003 - VÉNISSIEUX - JOLIOT CURIE / SEMBAT"))

    def test_distance(self):
        # Un millième de degré de latitude fait 111 m.
        self.assertAlmostEqual(0.111, stations.distance_km({"lat": 45.76, "lon": 4.85}, {"lat": 45.761, "lon": 4.85}), places=3)


if __name__ == "__main__":
    unittest.main()
