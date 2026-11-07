# TTX DRIVER PRO — Safe Performance Phase A (0.9.17+37)

## Scope and verified baseline
- Baseline commit: `f8bd4409460c5ee848feee498e40f0522f997917` (0.9.16+36).
- GitHub Actions #519: 184 tests passed; static analysis and both Android APK builds passed.
- Reported **raw APK** (not artifact ZIP): universal Debug 202,136,702 bytes; ARM64 test-signed release 32,296,542 bytes.
- No real-device cold-start, FPS, RAM or battery benchmarks are available. Changes below are code-level optimizations, **not proof of a speedup**.

## A1 — Early, safe 2D map paint
- `TaximeterHome.build` renders the lightweight 2D DashboardMap even while SQLite, tariffs, bank settings and any active trip are being restored.
- A loading/error strip overlays the map; the underlying map controls are absorbed (no interactions), settings entry is disabled, and the start/quotation actions remain disabled. No demo-tariff amount or "SẴN SÀNG" claim appears until restoration is validated.
- The map widget stays in the same tree location on storage readiness, avoiding a teardown/recreation solely because storage became ready.
- Important: the map preview is a visual aid, not a billing source. Saved trip, prices, GPS route and SQLite checkpoints must always be restored before the user can start a trip.
- Startup initialization prevents concurrent retry/migration. A debug-only `TTX_PERF startup_storage_ready_ms=...` line records elapsed data-restore time.

## A2 — Isolate timer-only fare repaints
- A `ValueNotifier<int>` drives only the active fare/KPI/status/breakdown column on elapsed-second changes. GPS processing and SQLite checkpoint cadence are unchanged; no GPS fix is dropped.
- Full-screen HUD/Car Mode retains its previous redraw behavior.
- GPS position updates still request root rebuilds so the GPS marker, map camera and route remain live. This change **does not** yet split map visual state completely; that is Phase B pending device profiling.
- A change to trip status, pause/resume, GPS interruption, BOT or backup UI still uses normal full rebuilds, prioritizing correctness.

## A3 — Rate-limit non-authoritative Android display state
- `CarStateBridge` now skips redundant native SharedPreferences snapshots within 10 seconds while status and interruption state are unchanged.
- Publish immediately for new status or interruption state; do not throttle completed/paused transition.
- The mirror is **not the fare ledger** and the Android Auto service remains unregistered. Any platform write failure leaves the gate eligible to retry. Core TaximeterEngine and SQLite cannot be affected.

## Explicit non-goals / protections
- No migration/schema change, database deletion, fare formula change, GPS filtering change, bank book/VietQR behavior change, 2D/3D feature removal, Android permissions change, or package removal.
- The ARM64 APK is still signed with a TEST-ONLY key. An in-place install may fail if the currently installed APK has a different certificate. **Never uninstall without exporting and verifying the complete .ttxbackup.**
- Background continuous billing is not guaranteed after force-stop, Android vendor process kill or GPS blackout.

## Validation
Automated:
1. `flutter test` (existing SQLite/recovery/GPS/fare/widget tests plus publish gate tests).
2. `flutter analyze`.
3. Debug and release ARM64 APK compilation and merged GPS foreground-service manifest verification.
4. Compare raw APK bytes to the baseline before claiming a reduction.

On an actual Android/MIUI phone (safe test, not while driving):
1. Cold start 10 times with existing history: see map and progress strip without enabling Start; verify any active trip is recovered paused with the correct fare and route.
2. First launch without GPS permissions: preview visible without demanding background permission, then normal foreground permission flow after restoration.
3. Test app-switch and screen-off for 5/15 minutes with GPS updates, and compare charged waiting/distance against a controlled stationary route.
4. Use Car Mode during an active test trip: time/speed/fare continue refreshing.
5. Observe frame rendering in Android Developer Options or DevTools Profile mode. Compare cold-start, p95 frame time, RAM, battery and package size to baseline, not against debug emulator impressions.
6. Verify 2D/3D, day/night, bank/VietQR, receipts, combined backup and safe restore work as before.
