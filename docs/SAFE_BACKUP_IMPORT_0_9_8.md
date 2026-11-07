# TTX DRIVER PRO — Safe additive backup import (0.9.8+28)

## What has been implemented

The **Nhập bản sao lưu (.ttxbackup)** action is available in Settings and the
top-right tools menu. It accepts the unified backup format from 0.9.5+
(schema 1) or 0.9.6+ (schema 2), verifies it and offers a user-approved,
**additive** import on devices without an ongoing/unsaved trip.

This is NOT a destructive full restore and NOT an automatic rollback system.
The user can migrate completed trips and previously unset app settings to a
fresh installation without deleting their existing trips.

## Import procedure

1. Finish and save the current trip. Open **Nhập bản sao lưu (.ttxbackup)**.
2. Choose a private `.ttxbackup` file. The parser checks framing, version,
   SHA-256 for all sections, saved settings JSON, logo signatures and length.
3. Open the bundled SQLite copy **read-only** to verify database integrity,
   schema v3, complete receipt records and active GPS checkpoint sequencing.
4. Compare the archive against the device. The driver sees the number of
   missing, conflicting and device-only records **before** deciding to import.
5. Confirm **Xác nhận nhập bổ sung**. The app rechecks that a current trip
   has not started and that SQLite has no unfinished active checkpoint.
6. The app stores a timestamped private pre-import `.ttxbackup` under
   `<app-support>/ttx_pre_import_safety/`. This includes a SQLite snapshot,
   previously saved settings and app-managed VietQR logo files. The safety
   file is validated before any live data is modified. If the safety
   backup cannot be built/validated, import is aborted.
7. Missing **completed** receipts are inserted in a single SQLite
   transaction. Existing receipt IDs, including same-ID records with
   different values, are skipped and left unchanged. Retrying is idempotent.
8. Only missing SharedPreferences JSON settings keys are added. Existing
   tariff, bank book, registration and map preferences are **never**
   overwritten. If a missing bank book is restored, the included portable
   logos are saved in the app-owned logo directory with collision-resistant
   filenames, and the bank book is updated with new local paths.
9. The import summary reports added/skipped records. Restart the application
   to apply new preferences to the in-memory UI.

## Important exclusions

- A trip **in progress at backup time is NOT imported**, to avoid overwriting
  the current meter or resuming billing with an unverifiable GPS clock.
- Same-ID conflicting receipts are NOT overwritten or merged. The UI reports
  their count so the driver can investigate manually.
- Existing preferences are NOT overwritten even if the archive differs. On
  an already configured phone, this can mean some archived settings remain
  unimported. That is intentional.
- The stand-alone SQLite `.db` and settings `.json` exports are not accepted
  by this combined import action. Use a unified `.ttxbackup` file.
- The pre-import recovery archive is kept in **private app storage**, not
  automatically uploaded, exported or applied. It is **not** a one-click
  rollback: uninstalling the app can delete this safety archive.
- SQLite receipt imports are atomic. Settings and logo creation are separate
  additive steps, not one cross-store transaction. An error or process
  termination after the SQLite step can leave a **partial import**; repeating
  the same file continues remaining missing entries without replacing
  existing values. There is no claim of atomic end-to-end restore.
- The backup format uses SHA-256 for corruption detection, but no encryption
  or authenticated digital signature. These files contain bank account
  details and sensitive GPS/receipt data in plaintext. Store privately.
- The app still uses test-only APK signing; changing installed APK signing
  keys can block in-place updates. Do not uninstall a working install before
  testing the entire migration path on a spare Android device.

## Regression tests

- `test/import_completed_trips_test.dart`: missing records, conflict
  non-overwrite, repeat import, atomic active-trip guard.
- `test/backup_settings_importer_test.dart`: preferences skip existing,
  portable logo path replacement, repeat import, legacy path sanitization.
- Existing SQLite, unified archive, logo and inspection tests remain active.

## Before production deployment

A full replacement/rollback restore would still require a durable recovery
journal and an automatically tested, crash-safe recovery mechanism spanning
SQLite, preferences, and images, plus encrypted file handling and stable
release signing. The additive importer must be tested with Android's
Storage Access Framework and real device storage before being considered
release ready.
