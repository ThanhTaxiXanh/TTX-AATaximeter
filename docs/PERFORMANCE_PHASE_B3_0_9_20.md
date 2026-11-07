# TTX DRIVER PRO — Performance Phase B3 (0.9.20+40)

## Baseline
- Source: `feature/flutter-taximeter-foundation`, parent commit
  `ea3380e823f68a9a99598cddbd303b20cc4907ff` (0.9.19+39).
- CI #563 succeeded: 201 Flutter tests, Flutter static analysis, Debug APK,
  verified Android foreground-location manifest, ARM64 test-signed Release.
- Actual ARM64 APK: **32,296,590 bytes**. This is not installed app size.
- No real phone baseline for GPU utilization, native MapLibre frame time,
  memory residency or battery yet; do not claim measured improvements.

## B3.1 — Incremental geometry cache for 2D and 3D
Previously `displayRouteSegments()` grouped and re-simplified the **whole**
accepted GPS route for every visual polyline or MapLibre GeoJSON upload.
Even though B1 throttled native uploads, route simplification was repeated.

`RouteRenderGeometryCache` keeps append-only segment lists, finalized
64-sample RDP windows and the current open tail. It calculates each
completed window just once, recalculates only the tail on an append,
and returns the same source point objects, segments, turns, endpoints,
tolerance and order as the earlier full renderer.

The 2D FlutterMap and 3D MapLibre now each own a disposable visual cache.
A replaced list, truncated route, or changed last processed point resets
the cache. A **same-list prefix edit with the same length/tail is NOT
supported**: the existing accepted-route contract is append-only, with
new source lists used for replacements. Complete raw GPS points remain in
`TaximeterEngine`, SQLite active checkpoints, receipts and backup.

The existing MapLibre 2-second GeoJSON upload coalescer, 700 ms camera
animation serialization and navigation camera filter stay unchanged.

## B3.2 — Eliminate unnecessary street-name vector-tile scans
Previously `DriveMap3D._updateCurrentRoad` queried the source name layer
as often as every 6 seconds, including at a standstill. Each query
may enumerate many loaded vector features.

`RoadQueryGate` now:
- keeps the existing 6-second minimum after a request;
- refreshes after >=18 m of actual visual-map movement;
- allows a periodic 45-second check at a stationary named road;
- retries unresolved/no-name results every 15 seconds;
- refreshes immediately when the style reloads or name panel turns on;
- validates coordinates and avoids getting stuck after a wall-clock reversal.

A name query uses the GPS coordinates captured at dispatch time, rather
than coordinates that might have changed during the native async request.
This gate does not affect GPS fixes, the meter, distance or route recording.
No street name is invented; vector-tile labels and the user's dark navy
style remain in place.

## B3.3 — More informative APK size accounting
`tool/apk_size_report.py` now includes the top 12 `.so` libraries
by raw payload alongside compressed ZIP bytes to pinpoint native size.
It remains read-only and the built APK is unchanged. We do not remove
MapLibre native libraries or other dependencies without measured evidence.

## Regression and device checks
1. `flutter test`, `flutter analyze`, APK Debug, merged foreground-service
   manifest and ARM64 Release build must succeed.
2. Incremental cached route geometry must match the old full renderer at
   64-fix boundaries, the 750-fix simplification threshold, appended points,
   gap-separated routes and a replaced/truncated GPS route.
3. Verify on Android hardware: live 2D/3D arrow, road names, day/night,
   follow camera, zoom/rotate gestures and a long 1,000+ point trip.
4. Compare CPU/frame p95 and memory over 15–60 minute sessions with identical
   map style, tile coverage and test route; use Profile mode and collect
   MapLibre-native diagnostics separately. Include Android screen-off /
   app-switch GPS billing checks.
5. Confirm mileage, waiting charges, completed receipts, bank/VietQR,
   SQLite checkpoint, full trip GPS route, backup/restore and PR Draft status.
6. Never uninstall production-signed packages to install this test-only APK
   without first creating and verifying a complete .ttxbackup.

## Explicit non-goals
No fare formula changes, no GPS observation filter changes, no database
migration, no removal of features, no changes to signature, secrets or
Android foreground location permissions. This is an incremental
CPU/allocation optimization, not a claim of GPU or memory speedup without
real-device measurements.
