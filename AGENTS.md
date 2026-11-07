# TTX Driver Pro — Instructions for all future contributors and AI coding agents

## Mandatory gate: Vietnam map sovereignty policy (TTX-VN-MAP-01)

This repository has a permanent product-specific labeling requirement:
**Hoàng Sa (Việt Nam)**, **Trường Sa (Việt Nam)**, **Biển Đông**.
Do not introduce competing territorial captions or foreign claim boundaries
in app-owned map text, datasets, search results, previews or screenshots.

Before **every change** involving 2D/3D maps, tile/style URLs, MapLibre
layers, administrative borders, local search/geocoding, map exports, or map
screen captures:
1. Read `docs/VIETNAM_MAP_SOVEREIGNTY_POLICY.md`.
2. Keep all external basemap URLs in
   `lib/src/ui/vietnam_map_sovereignty.dart`.
3. Preserve the Vietnam-facing labels on both raster 2D and vector 3D.
4. Run `python3 tool/check_map_sovereignty.py` and
   `python3 -m unittest discover -s tool -p 'test_map_sovereignty_gate.py'`.
5. Run `flutter test test/vietnam_map_sovereignty_test.dart`,
   `flutter test` and `flutter analyze`; verify CI's mandatory source gate.
6. **Before any external release of a map, its tiles, search data, or images**,
   run `python3 tool/check_map_sovereignty.py --publish`. A failure means
   the asset is NOT certified. Do not override, skip or fake this check.

External OSM/OpenFreeMap raster pixels and disputed vector boundaries cannot
be validated by merely overlaying three labels. A visual and data audit, with
real evidence recorded in
`docs/VIETNAM_MAP_PUBLICATION_EVIDENCE.json`, is mandatory before making
compliance claims or distributing geographic output.

No change to GPS filtering, metering, SQLite or user bank records may be made
just to satisfy a visual-only map rule. Keep PR #1 Draft and do not merge
`main` without the repository owner's express approval.
