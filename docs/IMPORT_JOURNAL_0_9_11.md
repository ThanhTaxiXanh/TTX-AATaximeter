# TTX DRIVER PRO — Durable additive-import journal (0.9.11+31)

## Objective

Detect an additive `.ttxbackup` import interrupted by a process crash,
force-stop, storage failure or failed post-import verification without
silently modifying or deleting any original fare data.

This iteration adds a **durable journal and explicit retry checks**.
It does **not** implement automatic rollback, destructive import, automatic
background processing, or commercial APK release signing.

## State machine

`lib/src/data/backup_import_journal.dart` owns one small JSON file:
`<app-support>/ttx_additive_import_journal_v1.json`.

- `applying` — the driver confirmed import, a private pre-import safety
  snapshot is already published, and changes may be in progress.
- `needsReview` — a caught error happened after import began. The safety
  copy remains untouched and the UI warns the user.
- `completed` — verified archive-only receipts/settings were found,
  all pre-existing data matched the original baseline, and the
  post-import check passed.

The file contains only `format`, `schema`, selected archive SHA-256,
**basename** of the original safety copy, UTC start time, and phase.
It never stores GPS coordinates, payment/bank details or entire receipts.
The marker is written to a temporary file and published with a rename on
the same filesystem. A leftover temporary marker is not treated as
a committed journal.

## After interruption

On each successful application startup, the app reads the journal separately
from SQLite initialization. An unfinished or unreadable journal produces
a visible warning on the home screen. **No automatic rollback or import**
occurs. The app keeps its ability to display GPS/fare records; the warning
does not authorize a silent change to a running trip.

To review a prior import:

1. Stop the trip (if one is running) and **export the private safety copy**
   using `Cài đặt → Xuất bản dự phòng trước khi nhập`.
2. Select **Nhập bản sao lưu (.ttxbackup)** and choose the **same archive
   bytes** as the unfinished attempt. A different SHA-256 is refused while
   the previous journal requires review.
3. The application verifies the archive, asks for approval, creates a
   fresh private safety copy (without overwriting the first), loads the
   **original** safety copy named by the journal, and checks its SQLite data.
4. It reruns the additive import, which skips existing IDs and settings,
   and verifies the final device state **against the first pre-import state**.
5. Only after this full postflight can the journal become `completed`.
   If verification fails, it stays `needsReview` and requires manual
   attention. No original record is deleted, restored or overwritten.

If the first safety file, journal or original archive cannot be verified,
the import fails closed. Export existing private safety snapshots and seek
manual inspection; do not delete the journal or reinstall the app to bypass
protection.

## Failure and privacy boundaries

- A completed journal does **not** prove that every third-party file or
  Android permission has been restored; the importer is additive and skips
  unfinished trips and same-ID conflicting receipts.
- SQLite inserts are transactional, but settings and logo writes are
  separate. A power interruption can still leave partial new data.
- Journal durability reduces ambiguity but is not a two-phase,
  crash-atomic transaction across all stores.
- A same-archive retry may fail if other trip/settings edits occurred after
  interruption; this is deliberate fail-closed behavior.
- The safety copy and original archive contain **unencrypted** bank/GPS
  information. Export only to a trusted private destination.
- Keep the original installed application's signing identity; the
  CI ARM64 APK is still test-only signed and may not install over the
  currently installed app.
- File picker, process-kill and reboot tests on a physical Android phone
  are still required before production use.

## Regression coverage

- `test/backup_import_journal_test.dart`: new, applying, interrupted,
  completed, hash mismatch, missing safety file, corrupted journal,
  original baseline retention and invalid state transitions.
- `test/backup_import_postflight_test.dart`: original receipt and settings
  preservation, missing imported records and conflicting same-ID receipts.
- `test/import_completed_trips_test.dart`: additive SQLite transaction and
  exact payload preservation; all existing route, logo and archive tests
  remain in CI.

## Repository and workflow

Only `feature/flutter-taximeter-foundation` is modified.
PR #1 remains Draft and unmerged; do not change `main`.
Confirm unit tests, Flutter Analyze, GPS manifest validation and debug/ARM64
artifacts on the final commit's GitHub Actions run before device testing.
