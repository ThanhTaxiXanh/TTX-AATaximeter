# TTX DRIVER PRO — B5: On-device performance diagnostics (0.9.22+42)

## Baseline
- B4 source: `e3c2dd5f203fe0a3ad2c4e4ebb2fe4a8e154b1a2`.
- GitHub Actions #606 succeeded: 219 Flutter tests, static analysis, Debug APK, merged GPS FGS manifest, ARM64 Release test-only APK.
- ARM64 raw APK: **32,362,126 bytes**. This is NOT installed app size.
- No direct device measurements have been supplied; do not assert actual FPS/RAM improvements from CI.

## User-facing experience
- Cài đặt → Quyền & hệ thống → **Chẩn đoán hiệu năng**.
- The page shows dashboard-first-frame latency (relative to TaximeterHome
  creation), **storage/restore duration**, sample-based Flutter frame FPS,
  UI-build p95, raster p95, process RSS, GPS status, trusted fix age,
  2D/3D mode, visible GPS-frame requests and route-point counts.
- An opt-in **HUD trên bản đồ** allows seeing Flutter FPS, UI-build p95
  and RSS while viewing the real taximeter/dashboard. Closing the HUD
  also stops sampling; opening the page automatically starts sampling,
  and closing the page without the HUD stops it.
- The reporting button copies text locally to the clipboard, with no
  GPS coordinates, bank identifiers or receipt payloads. User discretion
  is still required before sharing logs or screenshots.
- Diagnostics UI uses the existing dark navy/cyan Driver Pro design.

## Performance cost & safety
- No frame probes or memory polling are active by default in **Release**.
  The B5 opt-in probe is explicitly enabled by opening the page or HUD;
  the older debug-only frame and RSS logs are unchanged.
- Flutter frame samples use a fixed-size 120-entry window. The latest
  samples provide p95 Flutter build/raster times and an observed frame
  submission rate. The values are refreshed to UI every two seconds;
  never every frame. A recent sparse/idle screen can display very low
  Flutter FPS although the native MapLibre map is drawing smoothly.
- RSS comes from `ProcessInfo.currentRss` and does not account for
  all native GPU driver allocations. It is not a proof of a memory leak
  or leak absence.
- Sampling is foreground-only. Timer and Flutter timings callbacks are
  released when monitoring is turned off or the HomeState is disposed.
- The first frame and storage-ready timings are captured even when full
  monitoring is disabled (tiny primitive in-memory state only).
- No telemetry network, files, persistent personal information, or
  GPS coordinate records are produced by these diagnostics.

## Verification
- `flutter test` including new bounded-frame statistics,
  opt-in lifecycle and diagnostics UI tests.
- `flutter analyze`, Debug APK, merged GPS FGS manifest,
  ARM64 optimized APK and size report in GitHub Actions.
- On Android: cold start 10 times; verify first-frame and storage
  restore timing; run map 2D/3D with overlay, stop at zero speed,
  toggle day/night, follow-car and screen-off GPS.
- Compare 10–15 min samples between 0.9.21 and 0.9.22 with same phone,
  network tile coverage and trip state. Check revenue/backup/VietQR
  regressions and signed APK certificate before update.
- Flutter FPS is **not** a MapLibre-native GPU FPS counter. For actual
  native GPU memory, tile cache and render cadence, external Android
  profiling is still required.

## Invariants
- No fare/GPS filtering changes, no waiting-fee policy change,
  no SQLite migrations, no change to native MapLibre layers,
  no modifications to VietQR, backup, vehicle/tariff storage or APK
  signing.
- Leave PR #1 Draft and `main` untouched. Never uninstall a production
  package without exporting and verifying `.ttxbackup`.
