#!/usr/bin/env python3
"""Required, fail-closed source/publishing checks for TTX Vietnam map policy.

Normal CI checks static wiring and selected app-owned labels. This CANNOT
certify pixels in external OSM raster tiles, live vector boundaries, search
results or user-captured screenshots. --publish fails until independently
reviewed evidence has been recorded and explicitly signed off.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "lib/src/ui/vietnam_map_sovereignty.dart"
TWO_D = ROOT / "lib/src/ui/dashboard_map.dart"
THREE_D = ROOT / "lib/src/ui/drive_map_3d.dart"
TRIP_MAP = ROOT / "lib/src/ui/trip_detail_page.dart"
WORKFLOW = ROOT / ".github/workflows/flutter-debug.yml"
EVIDENCE = ROOT / "docs/VIETNAM_MAP_PUBLICATION_EVIDENCE.json"

EXPECTED_LABELS = {
    "hoangSa": "Hoàng Sa (Việt Nam)",
    "truongSa": "Trường Sa (Việt Nam)",
    "bienDong": "Biển Đông",
}
EXPECTED_SOURCES = {
    "osmRasterTiles": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "openFreeMapDark": "https://tiles.openfreemap.org/styles/dark",
    "openFreeMapLiberty": "https://tiles.openfreemap.org/styles/liberty",
}

def assert_contains(source: str, term: str, description: str, errors: list[str]):
    if term not in source:
        errors.append(f"{description}: missing {term!r}")

def check_source() -> list[str]:
    errors: list[str] = []
    for path in (POLICY, TWO_D, THREE_D, TRIP_MAP, WORKFLOW, EVIDENCE):
        if not path.is_file():
            errors.append(f"Required policy file missing: {path.relative_to(ROOT)}")
    if errors:
        return errors

    policy = POLICY.read_text(encoding="utf-8")
    dashboard = TWO_D.read_text(encoding="utf-8")
    vector = THREE_D.read_text(encoding="utf-8")
    trip_map = TRIP_MAP.read_text(encoding="utf-8")
    workflow = WORKFLOW.read_text(encoding="utf-8")

    for constant, expected in EXPECTED_LABELS.items():
        assert_contains(policy, f"const {constant} = '{expected}';",
                        f"Canonical label {constant}", errors)
    for constant, url in EXPECTED_SOURCES.items():
        assert_contains(policy, url, f"Reviewed source {constant}", errors)
    for term in ("geoJsonLabels()", "anchor_only", "approvedLabel(",
                 "_restrictedLines"):
        assert_contains(policy, term, "Vietnam label sanitizer", errors)

    for term in ("VietnamMapSovereignty.osmRasterTiles",
                 "VietnamMapSovereignty.labels", "fm.MarkerLayer("):
        assert_contains(dashboard, term, "2D renderer", errors)
    for term in ("VietnamMapSovereignty.openFreeMapDark",
                 "VietnamMapSovereignty.openFreeMapLiberty",
                 "_installVietnamLabels(controller, epoch)",
                 "VietnamMapSovereignty.geoJsonLabels()",
                 "VietnamMapSovereignty.approvedLabel("):
        assert_contains(vector, term, "MapLibre renderer", errors)
    for term in ("VietnamMapSovereignty.osmRasterTiles",
                 "VietnamMapSovereignty.labels", "MarkerLayer("):
        assert_contains(trip_map, term, "History/receipt map", errors)
    assert_contains(workflow, "python3 tool/check_map_sovereignty.py",
                    "Required CI map sovereignty job", errors)

    # Map and tile URLs may only be declared in the central policy module.
    # This fails on a new hardcoded source in any Dart screen/search/export.
    endpoint = re.compile(r"https?://[^'\"\s)>]+")
    map_host = re.compile(
        r"(?:openstreetmap|openfreemap|mapbox|maptiler|openmaptiles|"
        r"hereapi|tomtom|arcgis|mapquest|tileserver)", re.IGNORECASE)
    literal_source = re.compile(
        r"(?:styleString|urlTemplate)\s*:\s*['\"]https?://", re.IGNORECASE)
    for path in (ROOT / "lib").rglob("*.dart"):
        if path == POLICY:
            continue
        content = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        if literal_source.search(content):
            errors.append(f"{relative}: direct style/tile source bypasses policy")
        for url in endpoint.findall(content):
            if map_host.search(url):
                errors.append(
                    f"{relative}: unreviewed map endpoint; route via policy: {url}")

    # Source changes must be accompanied by a failing pre-publication gate
    # until live raster tiles, vector boundaries and generated output are
    # independently checked. Evidence is never auto-marked as certified.
    try:
        evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"Invalid publication evidence JSON: {exc}")
        return errors
    if evidence.get("policy") != "TTX-VN-MAP-01":
        errors.append("Publication evidence has wrong policy ID")
    if evidence.get("sources") != list(EXPECTED_SOURCES.values()):
        errors.append("Publication source list differs from reviewed Dart source URLs")
    if evidence.get("categories_required") != [
        "raster_tiles", "vector_style_and_tiles",
        "search_results", "screenshots_and_exports"
    ]:
        errors.append("Publication evidence missing compulsory coverage areas")
    return errors

def check_publication() -> list[str]:
    errors = check_source()
    if errors:
        return errors
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if evidence.get("approved_for_external_publication") is not True:
        errors.append("NOT CERTIFIED: external map assets are not approved for publication")
    for category in evidence["categories_required"]:
        record = evidence.get("reviews", {}).get(category, {})
        if record.get("passed") is not True:
            errors.append(f"NOT CERTIFIED: {category} has no successful visual/data review")
        if not record.get("reviewer") or not record.get("date_utc"):
            errors.append(f"NOT CERTIFIED: {category} needs reviewer/date")
        if not record.get("evidence_sha256"):
            errors.append(f"NOT CERTIFIED: {category} needs archived evidence checksum")
    return errors

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true",
                        help="Fail closed unless independently validated for public distribution")
    args = parser.parse_args()
    errors = check_publication() if args.publish else check_source()
    if errors:
        for error in errors:
            print(f"VIETNAM_MAP_SOVEREIGNTY_FAIL: {error}", file=sys.stderr)
        return 1
    if args.publish:
        print("VIETNAM_MAP_PUBLICATION_GATE_PASS: reviewed evidence metadata present")
        print("WARNING: metadata presence is not a substitute for human inspection")
    else:
        print("VIETNAM_MAP_SOURCE_GATE_PASS: labels, render paths, source routing, CI")
        print("EXTERNAL_TILES_UNVERIFIED: --publish MUST pass before distributing maps")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
