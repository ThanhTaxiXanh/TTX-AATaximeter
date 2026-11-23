# TTX Driver Pro — TestMap Map Engine Integration Plan

**Status:** approved direction / integration preparation (not yet merged or shipped)  
**Target product:** one Android APK named **TTX Driver Pro**  
**Map research app:** TestMap remains a separate APK and continues to be the experimental/reference implementation.

## 1. Product decision

The production deliverable is one TTX Driver Pro APK. TestMap is not renamed, removed, or merged as a second application. Selected, reviewed map capabilities are ported from TestMap into TTX Driver Pro in controlled stages.

Repository responsibilities:

- `ThanhTaxiXanh/TTX-AATaximeter`: production application, taximeter, trip records, payment and driver workflows; final APK is built here.
- `ThanhTaxiXanh/testmap`: map-engine laboratory, offline package experiments, MapCar format research, GNSS experiments and map-data QA.
- The two repositories remain independently buildable. No runtime dependency on the TestMap APK or its package ID is permitted.

## 2. Protected production invariants

The integration must not:

1. Change TTX Driver Pro's Android application ID, signing identity, or release keystore.
2. Modify the fare calculation semantics, tariff defaults, rounding, waiting-time policy, or trip state machine as part of map migration.
3. Replace or destructively migrate the trip SQLite database, active-trip snapshot, route history, or receipts.
4. Allow map-matched/snapped coordinates, visual camera offsets, road geometry, traffic events, or inferred speed-limit values to enter the fare engine as trusted GPS fixes.
5. make map availability a prerequisite for starting, continuing, suspending, or recovering a trip.
6. silently enable experimental MapCar datasets, inferred speed limits, or unverified traffic-light states as safety/legal guidance.
7. merge to `main`, publish a release APK, or rotate signing keys without explicit owner approval.

TTX's existing `LocationTrackingPolicy` and `TaximeterEngine` remain authoritative for metering. A map renderer may consume validated fixes; it must never become the source of truth for billed distance.

## 3. Target architecture

```
TTX Driver Pro (single production APK)
├── Taximeter domain (existing; protected)
│   ├── TaximeterEngine / TariffConfig
│   ├── LocationTrackingPolicy
│   ├── TripRepository / SQLite / active-trip snapshots
│   └── Receipts / revenue / payment
├── Driver application UI
│   ├── Driving dashboard and fare HUD
│   ├── Trip lifecycle controls
│   └── Map overlays and driver controls
└── TTX Map Engine (ported from TestMap in stages)
    ├── MapLibre renderer (2D / 3D)
    ├── Offline map package manager (PMTiles / verified assets)
    ├── Road & lane viewport repository
    ├── Building / 3D geometry layers
    ├── Traffic event and signal layers
    ├── Sign / camera reference layers
    ├── Vietnam sovereignty labels and protection overlays
    ├── GNSS telemetry adapter (Android Kotlin)
    └── GPS visual filtering / camera-follow policy
```

### Required boundary

Define a small map-facing contract (for example `DriverMapFix`, `MapCameraState`, `MapLayerConfig`, `OfflineRegionStatus`) instead of importing TestMap screen widgets or its app-level state into TTX.

The location pipeline must distinguish:

- **Metering fix:** the original validated location sample accepted by TTX's existing safety policy.
- **Display fix:** optionally smoothed for marker stability.
- **Map-matched display pose:** optional road/lane-snapped visual position, explicitly non-billable.
- **Camera target:** may look ahead or be offset for visual comfort; never written to trip coordinates.

Native GNSS satellite telemetry is diagnostic information (satellites in view/used, C/N0, elevation and azimuth). It is not a guarantee of lane-level accuracy, raw pseudorange access, or uninterrupted GPS.

## 4. Source inventory and compatibility findings

### TestMap reference

Reference branch: `feature/testmap-native-gnss-0.9.3`  
Reference commit at preparation: `ea009043c60b7740c1a98f3b0e639f316a343b5a`

Relevant source areas:

- `mobile/lib/features/map/presentation/map_screen.dart`
- `mobile/lib/features/gps/data/gps_tracking_service.dart`
- `mobile/android/app/src/main/kotlin/vn/ttx/testmap/GnssBridge.kt`
- `mobile/android/app/src/main/kotlin/vn/ttx/testmap/MainActivity.kt`
- `mobile/lib/core/storage/` offline map/package services
- `mobile/lib/features/roads/` road spatial repository
- `mobile/lib/features/traffic/` traffic signal and MapCar traffic layers
- `mobile/lib/core/map/` map style and rendering helpers

TestMap's `pubspec.yaml` currently uses `maplibre_gl 0.28.0`, `geolocator 14.1.2`, `sqflite 2.4.6`, SDK constraint `>=3.12.0`, and `material_ui`.

### TTX reference

Integration base branch: `feature/ttx-map-hud-and-traffic-signs`  
TTX package version observed on that branch: `0.9.24+44`

Relevant source areas:

- `lib/src/ui/dashboard_map.dart` — existing 2D/3D dashboard composition
- `lib/src/ui/drive_map_3d.dart` — MapLibre 3D renderer and sovereignty protection
- `lib/src/core/location_tracking_policy.dart` — metering GPS safety gate
- `lib/src/core/taximeter_engine.dart` — protected fare calculation
- `lib/src/data/trip_repository.dart` — SQLite trip persistence and route data
- `pubspec.yaml` — currently includes `maplibre_gl 0.27.1`, `geolocator 14.1.2`, `sqflite 2.4.2+1`, SDK constraint `>=3.11.0`

### Compatibility risks to resolve before porting

- MapLibre versions differ: TestMap 0.28.0 vs TTX 0.27.1. Verify API and native Android compatibility, then pin one tested version in TTX; do not blindly copy TestMap's pubspec.
- SDK constraints differ: TestMap requires Dart 3.12+, TTX currently allows Dart 3.11+. The chosen CI Flutter image must satisfy the resolved dependency graph.
- TestMap uses `material_ui`; do not import this app-level UI dependency into TTX merely to port map features.
- TestMap's Kotlin GNSS bridge must be merged into TTX's generated/bootstrapped Android host without replacing TTX's existing Kotlin channels, foreground-location service, CarStateStore or native display bridge.
- TTX Android platform files are generated by `tool/bootstrap_android.py` / CI. Update the source template and bootstrap workflow together; editing a generated file alone is not durable.
- Offline package formats, manifests, checksums, licences and storage paths must be reconciled with TTX's existing app-private data layout.

## 5. Staged implementation

### Phase 0 — baseline and protection (this branch)

- Record source refs, current package ID/signing assumptions, CI workflow and test baseline.
- Keep the integration isolated from `main`.
- Establish explicit contracts and regression gates before code movement.

### Phase 1 — MapLibre renderer consolidation

- Make MapLibre the single primary vector renderer for TTX's production map, supporting flat 2D and pitched 3D.
- Retain a controlled 2D fallback if MapLibre style/tile loading fails.
- Port TestMap renderer layers incrementally; do not replace the entire TTX dashboard screen in one change.
- Preserve TTX's sovereignty overlays and fixed HUD in every style, fallback, reload and camera mode.

### Phase 2 — Offline map engine

- Port the PMTiles/offline package reader and verified package manager behind TTX-owned interfaces.
- Preserve package checksum validation, atomic install/rollback, interrupted-download recovery and storage reporting.
- Do not remove current TTX map fallback until offline install, reopen, update, corruption recovery and no-network tests pass.
- Keep TestMap's package catalog and experimental datasets independent; only approved packages become production catalog entries.

### Phase 3 — Roads, lanes and 3D geometry

- Port viewport-based road/lane queries and 3D building geometry.
- Query by visible bounds and zoom; never materialize all national features as map markers.
- Validate coordinate order, geometry validity, simplification, feature IDs, spatial indexes and memory usage.
- Snapped lane position is visual-only until independently validated; no fare distance changes.

### Phase 4 — Traffic intelligence

- Port MapCar-derived traffic events and signal locations with source/provenance metadata.
- Distinguish a traffic-light location from its live red/yellow/green state. Never infer live state from a static icon.
- Keep camera/sign data reference-only until verified and approved.
- Inferred speed values remain explicitly inferred, not legal road limits; no automatic fare or speeding logic.

### Phase 5 — Native GNSS integration

- Adapt TestMap's Kotlin GNSS telemetry to TTX's existing Android host.
- Keep TTX's trusted-fix acceptance and trip suspension policy authoritative.
- Compare native location samples against current Geolocator/foreground service behavior before changing the production source.
- Show satellite diagnostics separately from GPS accuracy and metering status.
- Ensure permissions are requested only through the driver's explicit GPS action and foreground notification/service behavior remains valid.

### Phase 6 — Driver UI integration and acceptance

- Integrate map, fare HUD, speed, trip route and controls into one TTX Driver Pro dashboard.
- Keep map operations asynchronous and isolated so map stalls cannot freeze the taximeter.
- Run migration, trip recovery, GPS interruption, offline and map-rendering regression tests.
- Produce a QA APK only from the TTX repository and existing application identity/signing setup.

## 6. Required regression matrix

| Area | Required cases |
|---|---|
| Fare engine | Existing unit tests unchanged; known tariff fixtures; waiting and pause/resume |
| Trip persistence | Start, checkpoint, background, process death, recovery, finish, receipt |
| SQLite | Existing database opens; migrations are additive; no trip/route loss |
| GPS | Permission denied, GPS off, poor accuracy, stale fix, mock fix, no signal, recovery |
| GNSS | Satellites in view/used, C/N0, callback cleanup, lifecycle and provider disabled |
| Map | 2D, 3D, 2D fallback, dark/light, style reload, tile failure, camera follow |
| Offline | Fresh install, download, resume, checksum failure, rollback, reopen without network |
| Roads | Viewport query, dense urban geometry, lane rendering, zoom transitions |
| Traffic | Signal location vs live state; no fabricated event state |
| Sovereignty | Hoàng Sa (Việt Nam), Trường Sa (Việt Nam), Biển Đông in all relevant map modes |
| Device | Xiaomi Redmi Note 12 Pro; heat, memory, battery, GPS continuity and UI responsiveness |

## 7. Release gates

A phase is not complete merely because code is committed. It requires:

1. Flutter analysis and unit tests passing.
2. Android debug/QA APK successfully built from the TTX repository.
3. Installation/update behavior verified without changing package identity or signing key.
4. On-device checks on the target Android phone.
5. Trip and fare regression evidence.
6. Offline and no-network evidence.
7. Owner review before merge or release.

## 8. Current status

- Direction confirmed: one final TTX Driver Pro APK; TestMap remains a separate research/test APK.
- Preparation branches created:
  - TTX: `integration/testmap-map-engine-into-ttx-driver-pro`
  - TestMap: `integration/ttx-driver-pro-map-engine-handoff`
- This document is an integration contract and staged plan. It does **not** claim that TestMap's map engine has already been ported, that an APK has been built, or that device QA has passed.
- No merge to `main`, no PR auto-merge and no production signing/application-ID changes are authorized by this plan.

## 9. Immediate next engineering task

Start with Phase 1's dependency and Android-host compatibility audit. Resolve the MapLibre version and Flutter SDK matrix, inspect TTX's Android bootstrap template and native channels, then port the renderer behind a TTX-owned map interface. Do not start by copying TestMap's full `MapScreen` or replacing TTX's GPS/taximeter pipeline.
