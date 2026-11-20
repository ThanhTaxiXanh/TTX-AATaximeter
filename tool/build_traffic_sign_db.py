#!/usr/bin/env python3
"""Build a standalone offline SQLite/RTree index from the two owner datasets.

Build-time only: never run this on the taxi metering thread or on app startup.
No legal meaning is inferred from sign_type_code, direction_raw or speed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sqlite3
import tempfile

EXPECTED_SHA256 = {
    "traffic": "20f59d11fc0f98df3f7c830165ce14684915fa98b2054d017cc09fcab017d5ff",
    "speed": "77142d75a7f03cd3ada06804743e55ed49c5ab3ceb0e8dca0afe95616f481dc7",
}
EXPECTED_COUNTS = {"traffic": 151228, "speed": 38757}
RAW_FIELDS = ("sign_id", "sign_type_code", "direction_raw", "value_raw")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_source(path: Path, *, speed: bool) -> dict[int, tuple]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(doc, dict) or doc.get("type") != "FeatureCollection":
        raise ValueError(f"{path.name}: not a GeoJSON FeatureCollection")
    features = doc.get("features")
    if not isinstance(features, list):
        raise ValueError(f"{path.name}: features is not a list")

    records: dict[int, tuple] = {}
    errors: list[str] = []
    for index, feature in enumerate(features):
        try:
            if not isinstance(feature, dict) or feature.get("type") != "Feature":
                raise ValueError("invalid Feature")
            geometry = feature.get("geometry")
            props = feature.get("properties")
            if not isinstance(geometry, dict) or geometry.get("type") != "Point":
                raise ValueError("geometry is not Point")
            coordinates = geometry.get("coordinates")
            if not isinstance(coordinates, list) or len(coordinates) != 2:
                raise ValueError("Point must have [longitude, latitude]")
            longitude, latitude = coordinates
            if any(type(v) not in (int, float) or not math.isfinite(v)
                   for v in coordinates):
                raise ValueError("nonfinite/non-numeric coordinate")
            if not (-180 <= longitude <= 180 and -90 <= latitude <= 90):
                raise ValueError("coordinate out of range")
            if not isinstance(props, dict):
                raise ValueError("missing properties")
            for field in RAW_FIELDS:
                if type(props.get(field)) is not int:
                    raise ValueError(f"{field} must be an integer")
            speed_value = props.get("speed_kmh_inferred")
            if speed and type(speed_value) is not int:
                raise ValueError("speed_kmh_inferred must be an integer")
            sign_id = props["sign_id"]
            if sign_id in records:
                raise ValueError(f"duplicate sign_id {sign_id}")
            records[sign_id] = (
                float(longitude), float(latitude),
                props["sign_type_code"], props["direction_raw"],
                props["value_raw"], speed_value if speed else None,
            )
        except (TypeError, ValueError) as error:
            errors.append(f"feature[{index}]: {error}")
    if errors:
        sample = "\n".join(errors[:30])
        raise ValueError(f"{path.name}: {len(errors)} invalid features; first 30:\n{sample}")
    return records


def build_database(traffic: Path, speed: Path, output: Path) -> dict:
    for role, path in (("traffic", traffic), ("speed", speed)):
        actual = sha256(path)
        if actual != EXPECTED_SHA256[role]:
            raise ValueError(f"{role}: SHA-256 mismatch: {actual}")

    primary = load_source(traffic, speed=False)
    inferred = load_source(speed, speed=True)
    for role, rows in (("traffic", primary), ("speed", inferred)):
        if len(rows) != EXPECTED_COUNTS[role]:
            raise ValueError(f"{role}: expected {EXPECTED_COUNTS[role]} unique IDs, got {len(rows)}")

    missing, mismatched = [], []
    for sign_id, candidate in inferred.items():
        original = primary.get(sign_id)
        if original is None:
            missing.append(sign_id)
        elif original[:5] != candidate[:5]:
            mismatched.append(sign_id)
    if missing or mismatched:
        raise ValueError(
            f"speed subset mismatch: {len(missing)} missing IDs, "
            f"{len(mismatched)} different coordinates/raw attributes; "
            f"examples missing={missing[:10]} mismatched={mismatched[:10]}"
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=output.name + ".", suffix=".tmp", dir=output.parent,
        delete=False,
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with sqlite3.connect(temporary_path) as db:
            db.executescript("""
                PRAGMA journal_mode=DELETE;
                CREATE TABLE traffic_signs (
                    sign_id INTEGER PRIMARY KEY,
                    longitude REAL NOT NULL,
                    latitude REAL NOT NULL,
                    sign_type_code INTEGER NOT NULL,
                    direction_raw INTEGER NOT NULL,
                    value_raw INTEGER NOT NULL,
                    speed_kmh_inferred INTEGER,
                    source_dataset TEXT NOT NULL,
                    verification_status TEXT NOT NULL
                );
                CREATE VIRTUAL TABLE traffic_sign_rtree USING rtree(
                    sign_id, min_longitude, max_longitude,
                    min_latitude, max_latitude
                );
                CREATE TABLE metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
            """)
            rows = []
            spatial = []
            for sign_id in sorted(primary):
                lon, lat, code, direction, raw, _ = primary[sign_id]
                speed_value = inferred[sign_id][5] if sign_id in inferred else None
                source_dataset = (
                    "traffic_signs.geojson+speed_limit_signs.geojson"
                    if speed_value is not None else "traffic_signs.geojson"
                )
                rows.append((
                    sign_id, lon, lat, code, direction, raw,
                    speed_value, source_dataset, "unverified",
                ))
                spatial.append((sign_id, lon, lon, lat, lat))
            db.executemany("INSERT INTO traffic_signs VALUES (?,?,?,?,?,?,?,?,?)", rows)
            db.executemany("INSERT INTO traffic_sign_rtree VALUES (?,?,?,?,?)", spatial)
            db.executemany(
                "INSERT INTO metadata VALUES (?,?)",
                [
                    ("schema_version", "1"),
                    ("traffic_sha256", EXPECTED_SHA256["traffic"]),
                    ("speed_sha256", EXPECTED_SHA256["speed"]),
                    ("traffic_count", str(len(primary))),
                    ("inferred_count", str(len(inferred))),
                    ("verification_status", "unverified"),
                ],
            )
            db.executescript("""
                CREATE INDEX idx_traffic_sign_type
                    ON traffic_signs(sign_type_code);
                CREATE INDEX idx_inferred_speed
                    ON traffic_signs(speed_kmh_inferred)
                    WHERE speed_kmh_inferred IS NOT NULL;
            """)
            counts = (
                db.execute("SELECT COUNT(*) FROM traffic_signs").fetchone()[0],
                db.execute("SELECT COUNT(*) FROM traffic_sign_rtree").fetchone()[0],
                db.execute("SELECT COUNT(*) FROM traffic_signs WHERE speed_kmh_inferred IS NOT NULL").fetchone()[0],
            )
            if counts != (len(primary), len(primary), len(inferred)):
                raise ValueError(f"database row-count mismatch: {counts}")
            result = db.execute("PRAGMA integrity_check").fetchone()[0]
            if result != "ok":
                raise ValueError(f"SQLite integrity_check failed: {result}")
            db.commit()
        os.replace(temporary_path, output)
    finally:
        temporary_path.unlink(missing_ok=True)

    code_1_without_inference = sum(
        item[2] == 1 and sign_id not in inferred
        for sign_id, item in primary.items()
    )
    return {
        "schema_version": 1,
        "traffic_sign_count": len(primary),
        "speed_inferred_count": len(inferred),
        "unique_renderable_sign_count": len(primary),
        "type_1_without_inferred_speed": code_1_without_inference,
        "verification_status": "unverified",
        "traffic_sha256": EXPECTED_SHA256["traffic"],
        "speed_sha256": EXPECTED_SHA256["speed"],
        "db_sha256": sha256(output),
        "db_bytes": output.stat().st_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--traffic", type=Path, required=True)
    parser.add_argument("--speed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = build_database(args.traffic, args.speed, args.output)
    text = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True)
    print(text)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
