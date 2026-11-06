# TTX DRIVER PRO — Verified import postflight (0.9.10+30)

## Summary

This release hardens the existing **additive** `.ttxbackup` importer. No
destructive restore, automatic rollback, signature migration, or changes to
taximeter/GPS billing were introduced.

## Main improvements

1. **Freeze screen interaction while importing.** The taximeter route displays
   a non-dismissible progress overlay on the home screen while backup import
   is active. New trips, fare profile changes, history navigation, and tools
   are explicitly guarded to prevent concurrent edits.
2. **Preserve imported original receipt JSON.** A verified archived
   `TripRecord` is decoded and validated, but the exact raw JSON payload from
   the archive is stored for a missing trip. This preserves legacy fields and
   field ordering so the new record's receipt SHA-256 matches the original.
   Existing trip IDs are still never replaced.
3. **Remove cross-database reads from the SQLite write transaction.** The
   archived active-trip status now comes from the completed preflight,
   avoiding querying a different SQLite connection during the live insert
   transaction.
4. **Run a read-only post-import verification.** After successful receipt and
   settings writes, the app reopens the current inventory and verifies:
   - Every pre-existing trip ID retains exactly the same payload digest.
   - Every archive-only completed receipt is present with the archive digest.
   - Every previously stored settings value remains byte-for-byte identical.
   - Every archive-only settings key is now present. Portable VietQR logo
     paths may legitimately differ between devices.
   - No unfinished live trip appeared during the operation, and the expected
     receipt/settings counts match.

A discrepancy causes an explicit import error rather than falsely reporting
success. No rollback or deletion is attempted automatically. The existing
private pre-import recovery archive is preserved, and import remains safe to
retry for missing records.

## What happens on Android

Open **Cài đặt → Nhập bản sao lưu (.ttxbackup)** and select a saved archive.
After SHA-256, SQLite/schema and overlap checks, review the counts and
explicitly confirm. A progress overlay prevents editing the screen while
the operation is running. The completion dialog includes the number of
new records and settings groups rechecked after writing.

## Regression tests

- `test/backup_import_postflight_test.dart` covers unchanged existing
  records, archive-only receipts, same-ID conflicts, missing settings,
  changed existing settings and unfinished trip guards.
- `test/import_completed_trips_test.dart` covers legacy JSON field
  reordering: imported bytes are preserved exactly, retries classify records
  as identical, and real SQLite snapshots pass the postflight check.
- Existing SQLite backup, combined archive, stored-logo, and driver UI
  tests continue to run.

## Remaining limitations

- SharedPreferences settings and image files are not in the same atomic
  transaction as SQLite receipts; an interrupted import may be partial.
- Private pre-import recovery archives are not encrypted; export them only
  to a private trusted destination and inspect after saving.
- An archive's SHA-256 does not prove provenance or prevent deliberate
  tampering followed by recalculation.
- Actual Android Storage Access Framework behavior and interruption
  scenarios require validation on a spare physical device.
- APK release signing is still test-only. Do not uninstall the existing
  app or switch signing keys before verifying a complete recovery path.
- No single-action rollback exists. A future phase may implement durable
  import journaling and an explicit, fully tested recovery procedure.

## Repository boundaries

Only the branch `feature/flutter-taximeter-foundation` is modified.
PR #1 remains draft/unmerged. Never merge or modify `main` without explicit
authorization.
