# TTX AATaximeter — Performance review and improvement roadmap (0.8.8+18)

## Evidence vs. assumptions

- Code reviewed on the Flutter feature branch on 2026-11-05.
- GitHub Actions validates tests, static analysis and Android APK packaging.
- **No on-device FPS, p95 frame time, RAM, startup time, background-GPS
  survival or battery drain measurements have yet been captured for this
  revision.** Do not claim a percentage gain based only on source changes.
- Production-like validation requires a real Android phone and a safe
  parked/test ride. Do not test UI interactions while driving.

## Implemented in 0.8.8+18

1. **Background UI:** trusted GPS continues reaching the fare engine,
   storage and foreground service, but a background Activity no longer
   rebuilds the full Flutter dashboard for each location fix/timer tick.
   A single refresh occurs on resume.
2. **2D raster camera:** tiny stationary GPS jitter no longer triggers a
   map pan each callback; the actual marker coordinates are not altered.
3. **3D map:** GPS-route GeoJSON uploads are coalesced to a minimum
   two-second interval; route samples remain complete in the meter and
   persisted history. The arrow sprite PNG is reused across style changes.
4. **SQLite checkpoint:** snapshots are still frozen at the original
   point in time and written in order. On journeys with >=160 route samples,
   expensive JSON encoding occurs on a background isolate. The same JSON
   schema and crash recovery remain in use. Small trips avoid isolate
   startup overhead.
5. **CI efficiency:** newer runs cancel superseded branch runs to avoid
   repeatedly packaging stale commits.

## Next improvements, in priority order

| Priority | Proposal | Evidence and requirement | Verification |
|---|---|---|---|
| P0 | Validate 2D basemap on affected phone | The user observed a blank raster map in #137/#138; 0.8.7 adds a fallback but no on-device proof exists | Test OSM, OpenFreeMap and Wi-Fi/mobile data. Confirm streets/labels, GPS position and zoom |
| P0 | Background GPS and fare integrity | Foreground Service and 12-second watchdog exist, but MIUI can restrict background service | 5/15/30-min screen-off and app-switch route; forbid any distance/fare fabricated during GPS outages |
| P0 | Release signing plus verified export/import of SQLite trips | Test APKs use temporary signing; uninstall may lose trip records | Stable keystore and backup restore test before release/update |
| P1 | Normalize active route checkpoints into append-only SQLite rows | Every periodic checkpoint still stores a complete route, leading to growing write amplification over long trips | DB schema migration, transactional recovery test, 3-hour long-route write benchmark |
| P1 | Split meter UI from map/native platform view | The root dashboard is still a single State; its rebuild cost grows with complexity | Flutter DevTools frame times and widget rebuild profiling; isolate map with listenable snapshots |
| P1 | Optimize tile/network policy, caching and offline experience | 2D raster and 3D vector rely on network; fallback may also fail offline | Explicit loading/error states, bounded cache, provider usage policy, real offline behaviour |
| P1 | Instrument cold-start and map frame times | Startup and scrolling/render rates have not been measured | Compare cold/warm startup p50/p95, UI/GPU p95, memory and 30-min battery usage |
| P2 | Replace example 4-seat taxi label and verify tariff catalogue | Legacy sample label can conflict with 5/7-seat vehicle registration | Preserve IDs and old trips during any migration |
| P2 | Improve bank-list refresh, asset footprint and long-history pagination | Bank list is bundled and trips decoded in bulk in history | Proven API sync and tests with thousands of trips |
| P2 | More precise legal speed limits, routes, real 3D meshes, Android Auto | Current speed limit is manually set; 3D arrow is a shaded billboard, Android Auto scaffold is unregistered | Separate feasibility and official-policy review; do not mislabel these as existing features |

## Suggested acceptance targets (NOT measurements)

- Android 60Hz map: median UI frame <16.7 ms; p95 ideally <33 ms during normal travel.
- Cold start: first usable 2D map frame p95 <5s on a midrange Android phone
  with normal network/storage conditions.
- No visible jump in charge or route across a GPS blackout.
- Repeated 2D/3D and light/dark switches do not leak native map views.
- During a three-hour test, memory should stabilize rather than grow
  unbounded; checkpoint duration and size should be recorded.
- Restore backed-up trips with unchanged totals, payments and route points.

## Safety

The fare engine must use accepted GPS samples, never screen animation
samples. GUI throttling may skip a camera update but may **never** drop
accepted billable GPS fixes, synthesize missing distance, bypass safeguards
or erase previous trip history. Never force an app uninstall without a
verified backup.
