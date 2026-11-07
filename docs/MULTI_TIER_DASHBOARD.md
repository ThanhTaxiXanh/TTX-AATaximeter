# Multi-tier taxi fare + Dashboard map — implementation/verification

Date: 2026-11-04. This is a clean-room app and does not use code or protected graphical assets extracted from the reference app.

## New UI
- Top bar, vehicle/GPS and LED area, active company tariff selection, one-tap "Taxi Hương Giang", interactive map, speed arc, yellow fare, KPIs, BOT, trip actions, payment/quote/history/settings.
- Map: flutter_map 8.3.2 + latlong2 0.10.x, OSM standard tiles, visible OSM attribution, rotate/pinch/pan/zoom/location/north controls.
- If GPS unknown, the map is centered over a **Vietnam overview**, not the driver's purported current location. Location button explicitly requests permission.
- Full OSM map is displayed in the Flutter phone Dashboard, not in Kotlin Android Auto CarAppService.

## Multi-tier fare formulas
- Opening: baseFare covers the distance [0, baseDistanceKm].
- Progressive tier i: charge rate_i * max(0, min(distanceKm, tierUpper_i) - tierLower_i).
- Last tier has no upper limit.
- Waiting fee + toll + surcharge - discount; round final cost to nearest VND 1,000 if configured.
- Validate: finite nonnegative numbers; tier cutoffs strictly increase above the opening distance; only final cutoff may be null; positive opening rate and per-tier rates required by UI for user-configured profiles.
- The quote calculator retains a per-km override; if not overridden, use progressive tier formula.
- Two-way discount/return-leg formula is a *provisional estimate* and not verified against either video.

## Company quick-switch
- Catalog contains a pre-existing Urban 4-seats *reference* configuration and a **Taxi Hương Giang with no price** placeholder.
- Tapping the latter: must fill opening/km boundaries/rates before activation.
- Same saved profile used for dashboard meter, bill/receipt and quote.
- The active trip's tariff is frozen; switching requires idle meter.
- Schema-v1 JSON persisted as ttx_tariff_catalog_v1; old single ttx_tariff_v1 is read for migration/fallback.
- Rate values for example unit tests are fabricated fixtures and must not be presented as real Taxi Hương Giang tariffs.

## Source & compliance
- https://pub.dev/packages/flutter_map
- https://pub.dev/packages/latlong2
- https://operations.osmfoundation.org/policies/tiles/
- OSM tiles are community funded, availability best effort, no SLA, must cache as directed and clearly identify User-Agent. The default network map is for small-scale manual testing, not ready for broad commercial deployment. Select compliant tile provider/persistent caching before release.

## Validation to perform on a real Android
1. Save 3-tier profile and reopen; unchanged rates and correct active company.
2. Tap Taxi Hương Giang from Dashboard; verify empty placeholder cannot activate.
3. Set user-confirmed tiered prices and tap company; total resets for new trip only.
4. At each exact tier boundary, compare cumulative calculation; do not apply one rate retroactively.
5. Start trip and verify profile change is blocked.
6. Allow precise location; map moves to marker. Deny permission; map remains on Vietnam overview.
7. Pan/rotate/pinch zoom with two fingers; location button recenters and North button resets rotation.
8. GPS FGS and lock-screen behavior must be tested separately from map panel.
9. Confirm attribution remains visible and tiles are only downloaded for viewport.
10. Verify UI side-by-side against the newly provided videos; no pixel-perfect claim before visual trace.

## What is not implemented
- Exact pixel-for-pixel reproduction of the two new uploaded clips (not directly validated in the running app).
- Route engine/turn-by-turn navigation, street-name reverse-geocoding, 3D buildings, licensed production tile service, and native Android Auto host.
