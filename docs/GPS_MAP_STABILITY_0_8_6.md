# TTX AATaximeter – GPS stability and map performance, 0.8.6+16

## Scope and verification levels

This release addresses code-level risks. GitHub Actions can prove that Dart
unit/widget tests, analysis and Android packaging complete. **It cannot prove
foreground-service survival, GPS accuracy or map FPS on a Xiaomi/MIUI phone.**
Never infer real-device stability from a green CI run.

### Changes

- Foreground-only idle/finished GPS preview retries after a stream error or
  completion, with a minimum 15-second interval between acquisition attempts.
  Generation checks ignore callbacks from a cancelled/replaced subscription.
- A GPS sample must pass timestamp and coordinate/accuracy/speed validation
  before an outage can reset the metering baseline or split the route. Invalid
  positions cannot be treated as proof of renewed trustworthy tracking.
- 3D MapLibre follow camera limits updates caused by GPS jitter, serializes
  native camera animations and coalesces changes to GPS-arrow and route
  GeoJSON sources. This does **not** reduce the number of GPS fixes used by
  the taximeter engine.
- 2D map caches its route polyline geometry until the route count or final
  point changes instead of reconstructing it every time the fare ticks.

## Mobile-only physical test protocol

Run these tests parked, with a passenger operating the phone, or on a safe test
route where the driver does not interact with the device.

| Test | Procedure | Evidence to collect | Pass condition |
|---|---|---|---|
| Idle GPS | Launch app, grant location, move safely without Start | Screen video of map, GPS status | Marker follows; 0 km/0 additional fare; no trip polyline |
| Preview recovery | Revoke/re-enable location or toggle device location while idle, then return to the app | Timestamp of failure and first resumed fix | Map reconnects after permissions/services are restored; no trip starts |
| Trip foreground | Start a short measured route in 2D, then 3D | Route, distance, meter, speed | No implausible jumps; GPS arrow is at actual fix |
| Screen off 5/15/30 minutes | Start trip and lock the screen while GPS can receive signals | Foreground notification; displayed totals before/after | GPS stream survives where Android permits; no billing of untrusted gaps |
| App switch | During active trip, use another app and return | Route continuity and total | Active trip remains recoverable; no fake line across GPS outages |
| GPS gap | In a safe location, temporarily disable location, then re-enable | Fare/distance before and after, screenshot of route | No blind distance/billing during outage; recovery uses new segment |
| Forced process termination | End app process only while parked and with backups | Restart status and stored trip | Restores safely paused; driver must confirm resume |
| 3D camera | Rotate, zoom, toggle light/dark and follow mode | Screen recording | No runaway animations, marker remains geo-referenced |
| Long route | 1–3 hour route with GPS and 3D map | Installed storage, battery, heat, visual fluidity | No crash/OOM or quadratic UI slowdown; route preserved |

## How to assess UI responsiveness without a computer

On Android Developer options, use **Profile HWUI rendering → On screen as bars**
(if available). Compare 2D and 3D under the same network/location conditions.
At a 60 Hz refresh rate, a frame budget is approximately 16.7 ms; this is a
measurement target, **not a measured outcome**.

Use the Android battery usage screen to compare a 30-minute session with and
without 3D. Record device model, Android/MIUI version, power saver, background
location setting, network, GPS accuracy shown and approximate temperature.
A screenshot alone does not give a verified CPU/GPU/RAM profile.

## Data protection

- Do not uninstall an existing APK to resolve a signature mismatch unless the
  SQLite trip history has been backed up and verified.
- The optimized ARM64 APK may be test-signed. Never assume it updates an APK
  signed by a different key.
- Historical trip records, tariff snapshots, payments and fees must remain.
- Do not use GPS simulation or straight-line interpolation to fill missing
  fare distance. A lack of trustworthy location never justifies extra charges.
