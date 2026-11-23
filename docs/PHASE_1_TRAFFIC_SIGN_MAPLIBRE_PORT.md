# Phase 1 implementation — MapLibre traffic-sign viewport layer

**Branch:** `integration/testmap-map-engine-into-ttx-driver-pro`  
**Status:** source implementation committed; Flutter CI pending; no APK/device QA claimed.

## What changed

- Added `lib/src/traffic_signs/presentation/traffic_sign_maplibre_overlay.dart`.
- Integrated the overlay into `DriveMap3D`, which is used by TTX's 3D mode and zero-pitch MapLibre 2D fallback.
- Added `test/traffic_sign_maplibre_overlay_test.dart` for the GeoJSON adapter.

## Data flow

```
MapLibre camera idle
  -> getVisibleRegion()
  -> SignViewport validation
  -> existing TrafficSignRepository.viewport()
  -> SQLite RTree + SQL filtering / bounded clustering
  -> GeoJSON FeatureCollection (WGS84 [longitude, latitude])
  -> MapLibre circle layer
```

The overlay reuses:
- `TrafficSignDatabase.openOptional()`
- `TrafficSignRepository.viewport()`
- `ttx_signs_layer_enabled_v1`
- `ttx_signs_speed_only_v1`
- `ttx_signs_type_code_v1`

It does not duplicate the 151,228 raw records into Flutter markers. Only the repository's bounded viewport result is sent to MapLibre. Camera updates are coalesced and the query epoch rejects stale results.

## Safety and behavior

- The layer is opt-in: it is installed only when the existing saved preference enables traffic signs.
- Inferred speed values are passed through as `speed_kmh_inferred`; they are not converted to legal speed limits.
- The layer is visual-only and does not write to GPS samples, route history, fare calculations or trip SQLite.
- Database/query errors are contained to the optional overlay; they must not block map rendering or trip operation.
- The existing raster 2D implementation and its filter controls remain unchanged.
- This first slice adds the data layer to MapLibre 3D and vector 2D fallback. The interactive detail sheet and filter controls on MapLibre itself are not yet ported; saved settings can be configured from the existing raster 2D filter panel.

## Validation

- Traffic-sign database CI workflow completed successfully for the overlay commit (workflow run 70).
- Flutter MVP Debug APK workflow was pending at the time of recording; no Flutter analyzer/test/build pass is claimed.
- GeoJSON adapter tests were added but have not yet been observed passing in CI.
- No APK has been installed on a physical device; no Xiaomi Redmi Note 12 Pro QA is claimed.

## Next tasks

1. Obtain a completed Flutter CI run and resolve any analyzer/test/build failures.
2. Add MapLibre feature tapping to open the existing `TrafficSignDetails` sheet.
3. Expose the existing filter controls when MapLibre 2D/3D is active, without duplicating preference keys or repository logic.
4. Verify style reload, dark/light, camera idle, no database, large urban viewport, and 2D/3D transitions.
5. Only after these pass, evaluate making MapLibre flat 2D the default. Keep raster 2D as explicit fallback.
