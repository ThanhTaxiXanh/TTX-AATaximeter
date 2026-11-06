# TTX DRIVER PRO — Restore preflight comparison (0.9.7+27)

## Purpose

This iteration does not perform restore, file replacement, credential changes,
or migration. It adds a **read-only comparison** of the selected `.ttxbackup`
against records already stored on the device, before any future restore UI
may be considered.

## Flow

1. The driver opens **Kiểm tra gói dữ liệu (.ttxbackup)**.
2. The previously implemented archive reader checks the format,
   payload sizes, SHA-256 and settings schema.
3. Its SQLite bytes are copied to a disposable temporary file and opened
   read-only for `PRAGMA integrity_check` and SQLite schema v3 checks.
4. The inspector validates every completed receipt's ID against its
   database row and checks each active GPS journal sample's sequencing,
   coordinates, time, accuracy and speed.
5. The currently installed SQLite database is examined within a read-only
   transaction (no writes to live receipts). Current settings are captured
   through the existing allowlisted JSON export parser.
6. The app shows aggregate differences, then discards temporary files.
   There is **no "Restore" button**, and no replacement or merge action.

## Comparison outcomes

- Trips found only in the archive.
- Trips found only on the device (**must not be silently deleted**).
- Trips sharing an ID but with different serialized receipt payload hashes
  (**must not be silently replaced**).
- Trips whose ID and receipt payload hash match.
- Settings groups present only in the archive, only on the device, or with
  different values.
- Whether unfinished trip checkpoints are present on either side.

The comparison uses SHA-256 of the raw receipt JSON to detect different
contents of records sharing the same ID; this may report differences
caused solely by JSON formatting, which is intentionally conservative.
It never shows raw IDs, bank account numbers, trip locations or saved
JSON payloads in the UI. A matching hash does **not** authenticate who
created the record or guarantee the future restore process is safe.

If the device contains a trip absent from the archive, a changed same-ID
receipt, or an unfinished checkpoint, the comparison reports a data-loss
warning. Even when the warning does not trigger, **restore is still
unsupported** and no migration-readiness claim is made.

## Regression tests

- `test/backup_difference_preview_test.dart`: missing trips, differing
  same-ID receipts, matching records, settings differences and active trips.
- `test/verified_sqlite_backup_test.dart`: verified SQLite snapshot remains
  independent of later live data changes; corrupted GPS samples and receipt
  ID/payload mismatches are rejected.
- All existing archive/logo tests remain in the Flutter test suite.

## Next requirements before real restore

- Tested on-device export and file-picker inspection, including restart and
  crash scenarios.
- Stable release signing identity, securely held outside Git.
- Independent, verifiable pre-restore rollback copy of current SQLite,
  settings, and logo files.
- Explicit driver approval, conflict-resolution policy, and no writes when
  a trip is active, unsaved or pending a queued checkpoint.
- Durable two-phase restore/rollback journal with automatic recovery if the
  process dies mid-restore.
- Rewriting old absolute logo paths to validated app-owned destination paths.
- End-to-end restore tests across devices, Android versions and upgrades.
- Protection of exported secrets/GPS records (current archive has SHA-256
  integrity only, **not** encryption or authenticated provenance).
