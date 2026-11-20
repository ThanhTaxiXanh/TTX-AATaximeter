"""Synthetic unit fixtures: they are NOT production traffic-sign records."""
from __future__ import annotations

import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

import build_traffic_sign_db as builder


def feature(sign_id: int, lon: float, lat: float, speed: int | None = None) -> dict:
    props = {
        "sign_id": sign_id,
        "sign_type_code": 1,
        "direction_raw": 255,
        "value_raw": 60,
    }
    if speed is not None:
        props["speed_kmh_inferred"] = speed
    return {
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [lon, lat]},
        "properties": props,
    }


class TrafficSignBuilderTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.traffic = self.root / "traffic_signs.geojson"
        self.speed = self.root / "speed_limit_signs.geojson"
        self.output = self.root / "traffic_signs.sqlite"

    def write(self, path: Path, features: list[dict]):
        path.write_text(
            json.dumps({"type": "FeatureCollection", "features": features}),
            encoding="utf-8",
        )

    def build_fixture(self):
        with patch.dict(builder.EXPECTED_SHA256, {
            "traffic": builder.sha256(self.traffic),
            "speed": builder.sha256(self.speed),
        }), patch.dict(builder.EXPECTED_COUNTS, {"traffic": 2, "speed": 1}):
            return builder.build_database(self.traffic, self.speed, self.output)

    def test_build_merges_subset_without_duplication_and_supports_id_zero(self):
        self.write(self.traffic, [
            feature(0, 105.85, 21.03),
            feature(7, 106.70, 10.82),
        ])
        self.write(self.speed, [feature(7, 106.70, 10.82, speed=60)])
        result = self.build_fixture()
        self.assertEqual(result["unique_renderable_sign_count"], 2)
        self.assertEqual(result["speed_inferred_count"], 1)
        self.assertEqual(result["verification_status"], "unverified")
        with sqlite3.connect(self.output) as db:
            rows = db.execute(
                "SELECT sign_id, speed_kmh_inferred, direction_raw, "
                "verification_status FROM traffic_signs ORDER BY sign_id"
            ).fetchall()
            self.assertEqual(rows, [(0, None, 255, "unverified"),
                                    (7, 60, 255, "unverified")])
            viewport = db.execute("""
                SELECT s.sign_id FROM traffic_sign_rtree AS r
                JOIN traffic_signs AS s USING (sign_id)
                WHERE r.max_longitude >= ? AND r.min_longitude <= ?
                  AND r.max_latitude >= ? AND r.min_latitude <= ?
                  AND s.longitude BETWEEN ? AND ?
                  AND s.latitude BETWEEN ? AND ?
            """, (105.0, 106.0, 20.0, 22.0,
                  105.0, 106.0, 20.0, 22.0)).fetchall()
            self.assertEqual(viewport, [(0,)])
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone()[0], "ok")

    def test_unverified_speed_subset_mismatch_fails_closed(self):
        self.write(self.traffic, [
            feature(0, 105.85, 21.03),
            feature(7, 106.70, 10.82),
        ])
        self.write(self.speed, [feature(7, 108.00, 10.82, speed=60)])
        with self.assertRaisesRegex(ValueError, "subset mismatch"):
            self.build_fixture()
        self.assertFalse(self.output.exists())

    def test_duplicate_sign_id_is_rejected(self):
        self.write(self.traffic, [
            feature(0, 105.85, 21.03),
            feature(0, 105.85, 21.03),
        ])
        with self.assertRaisesRegex(ValueError, "duplicate sign_id"):
            builder.load_source(self.traffic, speed=False)

    def test_swapped_or_invalid_coordinate_range_is_rejected(self):
        self.write(self.traffic, [feature(0, 105.85, 999.0)])
        with self.assertRaisesRegex(ValueError, "coordinate out of range"):
            builder.load_source(self.traffic, speed=False)

    def test_checksum_mismatch_does_not_create_database(self):
        self.write(self.traffic, [feature(0, 105.85, 21.03)])
        self.write(self.speed, [])
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            builder.build_database(self.traffic, self.speed, self.output)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
