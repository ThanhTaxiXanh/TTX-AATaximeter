# TTX AATaximeter — SQLite GPS route journal (0.8.9+19)

## Purpose and scope

A full active-trip JSON checkpoint previously included every recorded GPS sample
every three seconds. For long trips, this repeatedly serialized, transferred
and wrote an ever-growing route.

Version 0.8.9+19 uses SQLite schema version **3**, with **append-only GPS
points**. Checkpoints now contain the compact fare/meter state and only the
new recorded GPS samples. This optimizes storage and UI work without changing
how valid GPS fixes are evaluated, how distance is billed, or how missing
GPS intervals are handled.

## Database

- Existing `trips` table retains completed receipt + full route JSON.
- Existing `active_trip` table retains the current meter, frozen tariff,
  vehicle metadata, and a `routeStorage=sqlite-v3`/`routeCount` integrity
  marker. Its `routePoints` array is empty on disk.
- New `active_trip_route` table has:
  `sequence INTEGER PRIMARY KEY`, latitude, longitude, recorded_at,
  accuracy_meters, speed_kmh, segment.
- No historic completed-trip records are rewritten or deleted by migration.
- Database filename remains `ttx_aataximeter_v1.db`, avoiding an accidental
  switch to a blank separate database.

## Atomicity and retries

1. The Dart state captures a snapshot of the meter and only the GPS points
   after its last successfully committed sequence number.
2. Checkpoints execute sequentially. A single SQLite transaction appends
   those points as one batch, validates that sequence positions are contiguous,
   then saves the matching meter header and route count.
3. If a database insert or the header write fails, SQLite rolls back the
   entire transaction, preserving the previous valid checkpoint. The next
   checkpoint resends the unsaved range.
4. Duplicate retries use `INSERT OR IGNORE` for the same sequence number;
   a gap or a stale checkpoint is rejected rather than silently truncated.
5. Completing the trip stores the final receipt (with its exact route)
   and deletes both active-trip tables **in the same transaction**.

## Upgrade from old app builds

- SQLite `onUpgrade` from v1/v2 adds the new route table without touching
  the existing inline `active_trip.payload` or any receipts.
- On first v3 checkpoint the older route is adopted into the new table in
  the same transaction as the new header.
- On launch, `loadActive` reads old inline checkpoints unchanged; new v3
  checkpoints are reassembled from ordered route rows for compatibility
  with the existing restoration path.
- Missing or discontinuous route rows raise an error; **no substitute
  coordinates, interpolated lines or invented mileage** are produced.
- Restored trips remain safely paused and require deliberate driver action.

## Test coverage

The SQLite FFI test suite exercises:
- New trip, incremental append and complete trip, including receipt route
- Repeated checkpoints and no duplicates
- Missing GPS sequence and stale write rejection
- Deliberate SQLite trigger failure: full transaction rollback
- Upgrade from an actual v2 file with an inline route; no history loss
- Protection against accidentally overwriting an unfinished trip
- Old full checkpoint and manual clear compatibility

GitHub CI can validate the code and APK build. It cannot simulate abrupt
battery failure at arbitrary fsync points, diagnose Android vendor storage
behaviour, or prove long-trip durability on every phone.

## Physical acceptance test (real Android device)

1. Back up existing history. Install the *same-signed* APK without first
   uninstalling the earlier version.
2. Begin a 20-30 minute safe test trip and record 2D and 3D route continuity,
   cost, BOT/payment metadata and GPS response when switching apps.
3. During an active trip, close/restart the app in a controlled parked
   scenario; confirm a paused session returns with identical fare/route and
   no untrusted distance/charge.
4. Resume and finish, then verify complete map and receipt in History.
5. Compare average checkpoint latency and SQLite file growth on a 1-3 hour
   test against the earlier version. No improvement percentages should be
   claimed until measured.

The optimized ARM64 APK remains test-signed until a stable release signing
and verified backup/restore workflow are introduced. Never uninstall an
existing app to solve a signature mismatch without first protecting data.
