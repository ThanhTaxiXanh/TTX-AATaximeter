# TTX DRIVER PRO — Phase B1 performance, 0.9.18+38

## Scope
- Baseline: 0.9.17+37, commit `5c803c53dc2fd8395cfe8d3afbb0153153dbb108` (Actions #528: 187 tests).
- This is the first incremental Phase B revision; not a full rewrite.
- **No SQLite schema change.** No changes to the fare formula, waiting time, accepted GPS fixes, active-trip checkpoint/recovery, bank accounts, VietQR or combined backup.
- Existing UI theme and Android foreground GPS service remain unchanged.

## B1.1 — Revenue and history load

### Previous implementation
`TripHistoryPage._load()` called `TripRepository.listTrips()`, which read the
entire `trips.payload` column into memory and decoded each JSON receipt
(including its potentially multi-hour GPS route) before displaying today's
summary. Each filter switch then sorted and rebuilt the entire list.

### Revised implementation
- `TripRepository.readTripHistoryStats()` uses read-only SQLite aggregates for
  non-empty fare/distance records and reads only zero/zero candidates to keep
  the existing rule: a legitimate 0đ/0km trip with a positive duration counts.
  The existing `RevenueSummary.periodStart()` defines the exact same
  locally interpreted day/week/month boundary for SQL and Dart. `julianday`
  compares mixed ISO8601 timestamps by actual instant, not string order.
- `listTripsPage()` returns a bounded slice (25 raw rows per page in the UI).
  Only these rows' full receipt JSON and GPS routes are decoded. Hidden empty
  test receipts still consume raw-row offsets; cursor values never skip or
  repeat a database row.
- `TripHistoryPage` uses `ListView.builder` to construct only visible rows,
  adds an explicit **Tải thêm chuyến đi** action, and ignores stale async
  results after filter changes/refresh. Changing payment/deleting a trip
  refreshes the current period.
- The full original `listTrips()` API remains for backup, migrations,
  regression verification and any callers requiring all records.
- No stored receipts are rewritten. All amount, distance, duration and payment
  metadata in completed trips remain authoritative.

## B1.2 — Map route rendering for long journeys
- Both flutter_map 2D and MapLibre 3D call the same pure
  `displayRouteSegments()` visual helper.
- Routes of <=750 accepted samples per segment are unchanged.
- Longer segments use bounded 64-sample iterative Ramer-Douglas-Peucker
  windows with a 2.5-metre visual tolerance. Every kept vertex references an
  **existing** GPS sample; first and last points of each segment, meaningful
  corners and GPS segment breaks are preserved.
- Only visual polylines and vector-map GeoJSON are simplified. Meter distance,
  GPS accuracy/speed filtering, snapshot persistence, complete trip receipts
  and backup export use untouched original lists.
- The renderer caches its last version as before. MapLibre's 2-second upload
  coalescing and native camera throttling remain in place.

## Validation and caveats
- Run all tests and static analysis, including SQLite FFI tests comparing
  period totals to `RevenueSummary.calculate` with 0đ, empty, future and
  offset-timestamp cases; pagination and geometry tests covering route
  preservation.
- Confirm Android Debug merged GPS manifest and ARM64 build on Actions.
- On an Android device: verify 0/100/1000+ completed trips, filters,
  real receipts, correct total amounts, full GPS route in trip detail, 2D/3D
  map rendering on a multi-hour route, no jump across GPS outages, frame
  responsiveness, app-switch and screen-off behaviour.
- No performance speedup percentage may be claimed without a baseline and
  a repeated Profile-mode/device measurement. SQL date predicates use
  `julianday(started_at)`, which may need an expression index for very large
  datasets; add only after a measured need, with an additive migration plan.
- ARM64 remains test-signed; protect verified .ttxbackup and do not uninstall
  to resolve package-signature errors.
