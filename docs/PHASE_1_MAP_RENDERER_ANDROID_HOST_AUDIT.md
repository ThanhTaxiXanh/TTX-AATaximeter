# Phase 1 — Map Renderer and Android Host Audit

**Repository:** `ThanhTaxiXanh/TTX-AATaximeter`  
**Branch:** `integration/testmap-map-engine-into-ttx-driver-pro`  
**Audit date:** 2026-11-24  
**Scope:** read-only source audit; no runtime code changed by this audit.

## Executive decision

**Do not switch TTX's production 2D renderer to MapLibre yet.** TTX already has a MapLibre-based vector renderer for 3D and a zero-pitch vector fallback, but its current raster 2D path owns additional production overlays that are not yet present in the MapLibre renderer. Switching the default renderer now would silently remove functionality.

The next implementation slice must first port and test those missing overlays on the MapLibre flat-2D path. Only then can the renderer default be switched behind a controlled fallback.

## Verified source findings

### 1. Current TTX 2D composition

File: `lib/src/ui/dashboard_map.dart`

The current raster 2D path contains:
- OSM raster tiles with a tile-error failover counter.
- Maritime redaction polygons from `VietnamMapSovereignty.maritimeRedactionZones`.
- Explicit geographic label markers from `VietnamMapSovereignty.labels`.
- The viewport-driven `TrafficSignMap2D` layer, including sign focus and cluster zoom callbacks.
- Recorded trip route polylines.
- The current GPS vehicle marker.
- A separate fixed sovereignty HUD and driver controls above the map.

The current MapLibre vector 2D fallback uses `DriveMap3D(flat2D: true)`; it does not mount `TrafficSignMap2D` or the raster path's sign-filter/focus controls.

### 2. Existing TTX MapLibre renderer

File: `lib/src/ui/drive_map_3d.dart`

Already implemented:
- One MapLibre widget supports pitched 3D and zero-pitch flat 2D.
- GPS marker is a native geo-referenced symbol using the true WGS84 fix.
- Camera look-ahead is visual-only and does not rewrite the GPS marker or trip route.
- Route rendering is coalesced for display; persisted route samples are not throttled.
- Road-name rendering and optional 3D building extrusion.
- Maritime redaction + Vietnamese label installation.
- Fail-closed opaque cover while maritime protection layers are incomplete or fail.
- Style epoch guards for asynchronous style changes.

The existing vector fallback is therefore a useful TTX-owned renderer foundation; copying TestMap's complete `MapScreen` is unnecessary and unsafe.

### 3. MapLibre dependency compatibility

TTX `pubspec.yaml` currently declares:
- `maplibre_gl: 0.27.1`
- Dart SDK `>=3.11.0 <4.0.0`
- `geolocator: ^14.1.2`
- `sqflite: ^2.4.2+1`

TestMap reference `mobile/pubspec.yaml` declares:
- `maplibre_gl: 0.28.0`
- Dart SDK `>=3.12.0 <4.0.0`
- `geolocator: ^14.1.2`
- `sqflite: ^2.4.6`
- `material_ui: ^1.11.1`

**Decision:** retain TTX's current dependency versions for the first overlay-port slice. No evidence from this source audit justifies a blind MapLibre upgrade. TestMap's `material_ui` is app-level UI and must not be added to TTX for renderer integration. A separate compatibility change may be proposed after API and Android build validation.

### 4. Android bootstrap and native host

Files:
- `tool/bootstrap_android.py`
- `tool/android_templates/MainActivity.kt`
- `tool/android_templates/CarStateStore.kt`

Verified:
- CI generates the Android project before applying TTX-specific native configuration.
- Bootstrap copies `MainActivity.kt` and `CarStateStore.kt` into the generated package path.
- The existing native MethodChannel is `vn.thanhtaxixanh.ttx_aataximeter/car`, with `publishState` writing a display snapshot to `CarStateStore`.
- The channel is explicitly a display mirror; SQLite remains the authoritative trip record.
- Any future native GNSS adapter must be added to the source template and bootstrap path without replacing this channel, TTX's foreground location service, or trip storage.

No native GNSS changes are included in this phase.

### 5. CI workflow

File: `.github/workflows/flutter-debug.yml`

The workflow:
- Generates Android files with `flutter create`.
- Runs `tool/bootstrap_android.py`.
- Resolves packages, runs sovereignty gates, unit tests and Flutter analysis.
- Builds debug and test-only ARM64 release APKs.
- Explicitly warns that the optimized release artifact uses temporary debug signing and is not a production release.

The current integration branch must be validated through the PR workflow. No CI success or APK/device validation is claimed by this audit.

## Phase 1 implementation sequence

1. Keep the current raster 2D renderer as the production default.
2. Port the TTX traffic-sign viewport data into a MapLibre-compatible source/layer path, preserving filtering, focus, cluster behavior and bounded viewport queries.
3. Verify that the MapLibre flat-2D path displays the route, GPS marker, road labels, sovereignty geographic labels, redaction protection and fixed sovereignty HUD.
4. Add regression tests for layer lifecycle, style reload, dark/light changes, camera movement and empty/unavailable sign data.
5. Only after those gates pass, make MapLibre flat 2D the default renderer; retain raster as an explicit fallback and preserve fail-closed sovereignty protection.
6. Reconcile TestMap MapLibre 0.28.0 with TTX 0.27.1 only in a separate, tested dependency change.

## Protected boundaries

- No fare engine, tariff, trip state machine or trip SQLite schema changes.
- No change to Android application ID or signing identity.
- No map-matched or smoothed display coordinate may enter billable route data.
- No static traffic-signal location may be presented as a live signal state.
- No change to `main`, no merge and no production release action.
