# TTX DRIVER PRO — Phase B2 (0.9.19+39)

## Starting point
- B1 commit `9e0cce24655871b08cbd0431629d237e022e72d4`, version 0.9.18+38.
- Actions #546: 193 automated tests passed, Debug and ARM64 release builds passed.
- Baseline ARM64 raw APK: 32,296,590 bytes, test-only signed.
- No measured device baseline yet for startup FPS, frame p95, battery or RAM.

## Goal — move GPS UI refresh off the root dashboard
Before B2 the active Geolocator stream processed every trusted location and then
called `_applyVisibleState(setState)` at the root `TaximeterHome`. The GPS
callback also advanced billing, checkpointing and saved accepted route points.

### Implemented
- `MapPresentationGate` is a **visual-only** change detector for coordinates,
  heading (angular threshold), rounded speed and appended route-point count.
  It never rejects a trusted GPS fix for the fare ledger or storage.
- `_mapPresentation` (a local ValueNotifier) rebuilds just `DashboardMap`.
  `_meterPresentation` continues to update fare and metrics, independently.
  Settings, trip status, backup/import, theme, dark style and 2D/3D switches
  still use a full root build when required.
- Idle map GPS previews likewise notify the map only. Restoring a saved
  default 3D selection still switches the parent UI once as before.
- Car/HUD mode still refreshes directly for every trusted GPS fix.
- When app is backgrounded: no visual notifications; meter, GPS accuracy
  filtering, waiting clock, SQLite checkpoint and the foreground GPS stream
  continue according to the original safety policy. Resuming triggers the
  normal full UI refresh.
- MapLibre's existing camera gate, update serialization and 2-second route
  upload coalescing remain unchanged. No native layer is removed.

## Measurement hooks
- Debug logs use `TTX_PERF gps_visual_observed=N map_revisions=M`
  every 120 eligible map observations. They count visual-notifier requests
  rather than drawn frames; this is **not an FPS metric**.
- `FrameTimingProbe` captures Flutter build/raster frame durations outside
  Release, reporting p95 over every 120 frames as:
  `TTX_PERF frame_samples=120 build_p95_ms=... raster_p95_ms=... mode=profile`
- To compare, run both 0.9.18 and 0.9.19 in Flutter Profile mode on the
  **same device**, identical 2D/3D style, comparable GPS route and memory
  pressure. Retain multiple 120-frame samples. Debug instrumentation cannot
  establish a production performance claim. Profile mode is recommended.
- Do not confuse Dart frame timing with native MapLibre rendering or tile
  network latency; measure map camera smoothness separately on hardware.

## Mandatory regression checks
1. All Flutter tests, static analysis, merged foreground-service Manifest,
   Debug and ARM64 build in GitHub Actions.
2. Idle GPS follows car without starting a fare and without a blue trip line.
3. Active 2D/3D GPS arrow, speed display and route remain live as points are
   appended even if the map preview coordinates are stabilized at a stop.
4. Car/HUD speed and fare continue to update every accepted fix.
5. Billing while screen-off/app-in-background remains gated by actual trusted
   location fixes. No time/distance is invented during GPS blackout.
6. Start/pause/resume/finish, receipts, Bank/VietQR, revenue pagination, and
   .ttxbackup restore behave identically.
7. Manual MapLibre map exploration and 2D/3D switch never break follow-car
   or active trip persistence.

## Non-goals and safety
- No changes to TaximeterEngine, signed APK certificate, SQLite schema,
  payments, GPS foreground permissions, tariff logic or retention of trip
  records. No dangerous forced uninstallation.
- B2 is a scoped repaint optimization; further JNI/MapLibre performance
  work must be based on real-device profiling, not speculation.
