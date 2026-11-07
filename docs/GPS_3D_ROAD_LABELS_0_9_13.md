# TTX DRIVER PRO — GPS camera and upright 3D road labels (0.9.13+33)

## User evidence

The driver provided a screen recording of the TTX Driver Pro home screen
while travelling in **GPS • 3D** mode (approximately 10–12 km/h displayed),
plus a reference screenshot of a third-party nighttime 3D map with street
names that visually face the viewer.

The recording demonstrates the current native MapLibre/OpenFreeMap map view
and the concern about jerky camera motion. A recording alone does not
measure CPU/GPU frame latency; this iteration is a code-level mitigation,
not a verified measured FPS improvement.

## Root causes found in repository

- `DriveMap3D` previously followed the GPS fix by scheduling **400 ms**
  native camera animations and shifted its target **35 m forward**
  using the unfiltered GPS course. Small heading changes could shift the
  forward-looking camera target sideways.
- Several OpenFreeMap Liberty and Dark vector street-name layers use
  `text-rotation-alignment: map`, which lays labels out with the map
  as the user tilts or rotates the perspective.
- Camera and arrow geo-source updates were triggered together for
  changes including pitch-only updates, even though changing pitch
  does not change the arrow's GPS geometry.

## Implemented

1. **Visual-only 3D camera filter.**
   `NavigationCameraFilter` adjusts camera latitude/longitude and
   heading without ever changing the GPS source, accepted trip points,
   distance, fare, database or arrow's underlying GPS coordinate.
   - Holds the visual heading when the vehicle is nearly stationary;
     small stationary GPS drift is ignored.
   - Blends position and direction using elapsed time and vehicle speed,
     with wrap-safe interpolation between 359° and 1°.
   - Responds more promptly to a sharp turn while moving.
   - Snaps the camera to valid fixes after an extended GPS outage or a
     large location jump rather than animating across a large area.
   - Resets on map-mode/style changes and manual **Về vị trí xe**.
2. **MapLibre follow camera.** A 620 ms minimum update gate and 700 ms
   camera transitions limit redundant native animation while bridging
   sparse GPS updates. Latest-fix coalescing remains in place; route
   drawing and metered GPS storage are not throttled by this UI gate.
3. **More frequent native GPS requests.** Both the foreground-only
   location preview and the trip foreground service now request a
   **1-second** Android location interval (previously 2 seconds), with
   a 1m distance filter. Android/GNSS delivery may vary and is not
   guaranteed to be 1 Hz. Cached preview fixes older than 45 seconds
   (previously 3 minutes) are no longer used for the initial map anchor.
   A higher sampling request may consume more battery; fare validation
   continues to use only the existing trusted-GPS rules.
4. **Street-name typography aligned to the screen.** On each MapLibre style
   load, the app parses the loaded style and targets the exact road-name
   symbol layers from OpenMapTiles `transportation_name`. It sets
   `text-pitch-alignment: viewport` and
   `text-rotation-alignment: viewport` and adds a subtle day/night
   text halo. This aims to make street names face the phone as the 3D
   map rotates. Other symbols (POIs, shields, one-way arrows, and the
   GPS arrow) retain their original layout and rotation semantics.
5. **Fail safely.** If an online map provider changes its layer names or
   a native device refuses a layout property, the map stays available.
   Problems are logged for debugging rather than blocking GPS or fares.

This is not a custom 3D text mesh, road snapping, map matching or a
navigation route planner. All street names still come from the upstream
OpenFreeMap/OpenStreetMap source.

## Regression coverage

- `test/navigation_camera_filter_test.dart`: motion filtering, stationary
  jitter, heading wrap, sharp turns, resets and GPS gaps.
- `test/road_label_style_test.dart`: OpenFreeMap Liberty/Dark street labels
  are selected without accidentally restyling roads, POIs or route shields.
- Existing `test/gps_arrow_geometry_test.dart` proves the arrow remains
  at the true WGS84 GPS fix; existing metering and route tests remain active.

## Mobile physical acceptance test

Park the vehicle before operating the map controls; use a passenger for
interaction during any driving test.

1. With reliable mobile internet, compare 3D motion over the same safe
   route with the prior APK and the new APK; document speed, device,
   Android/MIUI version and network status.
2. Verify that names are readable while turning the map through 0/90/180/270°
   and when pitching to the existing 3D-supported range in both light and
   dark styles.
3. Move slowly around 3–15 km/h: confirm the camera no longer repeatedly
   swings sideways at stable GPS heading. Test sharper turns at normal
   speed and confirm no excessive camera lag.
4. Stop for one minute: the follow camera should not drift around from
   GPS noise. Return to **Về vị trí xe** after manually dragging the map.
5. Confirm GPS marker, fare engine, speed, completed receipts, trip path
   and SQLite restore behaviour remain unaffected in 2D and 3D.
6. Optionally enable Android **Profile HWUI rendering** to record
   median/p95 frame times. Targeting 60 Hz means 16.7 ms per frame;
   no actual frame-time or power improvement is claimed without evidence.

## Data and release safety

The optimized ARM64 APK is test-signed. Do **not** uninstall the current
application to bypass a signature mismatch. Export and verify private
history first; changing an installed signing identity can block safe
in-place updates and risk lost trip records.

All changes go only to `feature/flutter-taximeter-foundation`. PR #1 stays
Draft and `main` remains unchanged.
