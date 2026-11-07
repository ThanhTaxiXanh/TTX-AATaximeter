# TTX DRIVER PRO — B4 memory & MapLibre lifecycle (0.9.21+41)

## Verified baseline
- Previous code: `fe8ec630489bd2c23ad6272d0e8dcc4434f7cc5e`, version 0.9.20+40.
- Actions #588: 212 tests, Flutter Analyze, Android Debug, GPS FGS manifest and ARM64 APK succeeded.
- ARM64 Release APK baseline: **32,296,590 bytes**; still **test-only signed**.
- No Android hardware or GPU profiler is remotely connected in this change. Actual native graphics memory, tile-cache pressure, and GPU jank are **not** measured by CI.

## B4.1 — Prevent stale native MapLibre work during style changes

`DriveMap3D` uses native asynchronous operations for road recoloring,
road-name overlays, buildings, route GeoJSON, GPS arrow symbols and source
queries. A style/day/night swap or map teardown may occur while those
operations are awaiting a platform channel.

`MapStyleEpoch` has monotonically increasing generations. The map:
- invalidates the prior generation on day/night selection and controller
  replacement;
- allocates a fresh generation when a style is loaded;
- checks the generation, widget mount and exact native controller after
  each awaited style/layer operation;
- ignores a stale GPS arrow, route upload, or street-name query completion;
- retries a stale street-name query if a replacement style is ready;
- invalidates generations on widget dispose, cancels pending route timer,
  drops the visual route geometry cache and releases its controller reference.

Already queued native calls cannot be forcibly cancelled. Their Dart
continuations no longer mark the *new* style ready or publish stale road
names. Core GPS acquisition and fare accounting are unaffected.

## B4.2 — Bounded process-memory diagnostics

`MemoryUsageProbe` samples `ProcessInfo.currentRss` every 30 seconds,
**only in Debug/Profile and only when app is visible**. A bounded 10-sample
`RssSampleWindow` outputs:
`TTX_PERF process_rss_mb=... rss_window_min_mb=... rss_window_max_mb=... mode=profile`.

- This is a process-resident-memory approximation; not all MapLibre GPU
  surfaces, graphics driver allocations or Android graphics memory are
  captured.
- No persistent logs, telemetry, GPS coordinates, payment information,
  bank details or trip history are collected.
- Diagnostics are disabled in Release and stopped on screen disposal.
- Exceptions in diagnostics never reach the fare engine.

## Test and on-device validation

Automatic CI:
- existing GPS, wait billing, database/backup, map, billing/UI regressions;
- `test/map_style_epoch_test.dart`: concurrent and stale styles, disposal;
- `test/memory_usage_probe_test.dart`: bounded sampling and reset;
- Flutter Analyze, APK Debug and ARM64, verified foreground GPS manifest.

Profile/Android hardware tests (still required):
1. Cold start and warm start on 2D and 3D with >=1,000 stored trips;
   collect wall-clock time and p95 UI/raster frame time (multiple runs).
2. Repeatedly switch 2D/3D, dark/light and zoom during stationary preview.
   Verify road names, buildings and GPS marker remain correct; monitor RSS
   for 15–60 minutes and Android Studio/ADB gfxinfo/meminfo separately.
3. Drive a stationary-safe controlled GPS test with >1,000 route points,
   switch styles and verify the next visible route contains all segments.
4. Screen-off/background 5–15 minutes: GPS foreground notification, time
   and waiting fare only for verified GPS intervals.
5. Check all trip receipts, SQL revenue pages, VietQR accounts, and
   complete `.ttxbackup` export/import for regressions.

Do not claim a measurable RAM/FPS gain without an identical-device baseline.
Do not remove native MapLibre or Flutter library binaries to reduce size:
they are needed for the map and Flutter runtime.

## Safety
- No SQL migration, deletion, GPS acceptance, fare calculation,
  checkpoint/route persistence, network permission, release signing,
  VietQR/backup or payment changes.
- Keep PR #1 Draft, do not merge main.
- Never uninstall to bypass a signing mismatch without a verified backup.
