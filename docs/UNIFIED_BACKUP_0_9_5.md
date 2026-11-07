# TTX DRIVER PRO — Verified unified export, version 0.9.5+25

## Purpose and status

A new manual **Sao lưu gộp SQLite + cấu hình** action exports one
`.ttxbackup` file, combining the existing SQLite v3 snapshot with a
versioned settings JSON snapshot. The source application database and
preferences are **never overwritten** by this operation.

**This is a custom binary format, not ZIP.** It is an export + read-only
inspection milestone. It is NOT a validated restore method or a complete
device migration solution.

## Container version 1

The file contains:

1. ASCII magic `TTXDRVPROBK1`
2. 4-byte big-endian unsigned manifest length
3. UTF-8 JSON manifest:
   - `format`: `ttx-driver-pro-combined`
   - `schema`: `1`
   - `createdAtUtc`
   - `settingsLength` and `sqliteLength`
   - `settingsSha256` and `sqliteSha256`
4. JSON settings bytes from `SettingsBackupBundle`
5. Verified SQLite v3 snapshot bytes from `TripRepository.createVerifiedBackup`

Checksums detect accidental damage and mismatches. **They do not prove
authenticity**: an attacker could modify data and recalculate hashes.
This format offers **no password protection or encryption**.

## What's in and out

| Included | Excluded |
| --- | --- |
| SQLite completed fares, receipts, route history, active trip checkpoint | Android OS permissions and onboarding flags |
| App settings JSON: saved fare profile/catalog, driver vehicle, map appearance and LED messages | Brand logo image bytes stored outside preferences |
| Saved VietQR account book where configured | All other application-private files outside the allowlisted stores |
| Manifest and integrity checks | Provenance signatures, passwords and key migration |

The saved bank book may refer to device-local logo paths: those references
are **not** equivalent to embedding the images. The SQLite and settings
stores are sampled sequentially, not in one cross-store transaction. This
archive should not be described as a perfectly atomic snapshot of every
application file.

## Safety design

- Export is only accessible through the UI after a trip is no longer running
  and pending writes have drained.
- SQLite is copied using `VACUUM INTO`, not by copying an open `.db`.
- Integrity and required tables are checked when creating SQLite copies.
- An archive has a 64 MiB SQLite payload limit and 256 KiB settings limit.
  The export uses an in-memory file picker and cannot safely support larger
  databases without streaming storage.
- **Kiểm tra gói dữ liệu (.ttxbackup)** opens a selected archive without
  importing it. It verifies format, lengths, SHA-256 values and settings
  data types. The SQLite payload is written to a disposable temporary file
  and opened **read-only** for `PRAGMA integrity_check`, schema v3,
  receipt parsing, active checkpoint and route-count consistency checks.
- Temporary files are removed after use or cancellation. No method accepts
  arbitrary paths for writing to the live SQLite database.

## Privacy warning

The `.ttxbackup` file contains bank account details and trip locations
**in plaintext**. Store privately, ideally in encrypted device/cloud
storage. Do not attach it to a public GitHub issue or repository.

## Files changed

- `lib/src/data/unified_backup_bundle.dart` — binary archive framing,
  bounded parsing and per-payload SHA-256 verification
- `lib/src/data/trip_repository.dart` — read-only SQLite preflight
- `lib/main.dart` — export and read-only inspection controls
- `test/unified_backup_bundle_test.dart` — archive integrity and
  corruption tests
- `test/verified_sqlite_backup_test.dart` — SQLite read-only inspection
  after real archive roundtrip
- `pubspec.yaml` — direct `crypto` dependency and version bump

## Future work — NOT implemented yet

1. Add portable logo image contents with explicit file-format verification,
   rather than relying on old absolute device file paths.
2. Add streaming export to avoid allocating large databases in RAM.
3. Design a read-only preview of conflicts against current user data.
4. Implement full **transactional restore** and rollback with a verified
   pre-restore safety copy, closed SQLite connections, explicit user approval
   and crash/restart recovery tests. Neither JSON settings nor SQLite
   can be overwritten by the present build's import/inspection UI.
5. Configure a stable release keystore through protected GitHub secrets.
   Never commit secret material; do not change APK signing identity on
   a device holding irreplaceable history without an end-to-end tested
   restore procedure.
6. Verify file picker, memory usage, backup and preflight on a physical
   Android device before release. GitHub Actions tests/build are necessary
   but not sufficient for this claim.
