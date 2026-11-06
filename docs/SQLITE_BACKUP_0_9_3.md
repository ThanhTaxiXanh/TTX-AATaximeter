# TTX DRIVER PRO — SQLite backup (0.9.3+23)

## Scope and safety

- The app stores completed fares, receipts, and active-trip checkpoints/GPS route
  in `ttx_aataximeter_v1.db` (SQLite schema version 3).
- **Sao lưu lịch sử chuyến (SQLite)** is a manual, **export-only** action.
  It does **not** delete, import, replace, merge, or edit any live records.
- The snapshot is created with SQLite `VACUUM INTO`. Copying the live
  `.db` alone is unsafe when transactions may be in a `-wal` file.
- The newly created database is opened read-only and must pass
  `PRAGMA integrity_check` and table checks for `trips`, `active_trip`
  and `active_trip_route` **before** it is offered for export.
- The temporary file is deleted after saving/cancelling. On any error while
  building the snapshot, the temporary file is deleted; the live DB is never
  mutated by this backup operation.
- The UI only allows export after a trip is finished and persisted (or while
  idle), and drains the pending checkpoint queue first.
- A backup may contain sensitive trip locations, times, plate information and
  fare records. Store it only in a trusted location, not a public repository.
- The SQLite snapshot **does not include** settings saved in
  `SharedPreferencesAsync` (VietQR bank account book, fare presets,
  registration, map preferences). It is not a complete device migration.
- Because `FilePicker.saveFile` currently accepts all file bytes in memory,
  the export UI rejects SQLite backups over **64 MiB** rather than risk
  an out-of-memory crash. A streaming SAF export is a future improvement.
- If the device SQLite library does not support `VACUUM INTO`, export fails
  safely. There is intentionally no live-file-copy fallback.
- An exported file has **not** been tested as a restore artifact on a real
  phone. In-app restore is deliberately not implemented yet; no claim of
  end-to-end restore readiness should be made.

## Driver workflow

1. Complete and save any current trip. Open the top-right menu, choose
   **Sao lưu lịch sử (SQLite)** (also available from Settings).
2. Read the privacy/scope notice, select **Chọn nơi lưu**.
3. Choose a trusted destination in Android's file picker and keep the
   `TTX_DriverPro_SQLite_YYYYMMDD_HHMMSS.db` file somewhere safe.
4. If the picker is cancelled or an error appears, the current history stays
   unchanged. Do not uninstall the app before confirming a tested recovery
   procedure for that particular device and signature.

## Release signing plan — NOT configured

The CI-generated ARM64 APK is still **TEST ONLY**, signed with a temporary
debug signing key. A stable release key must be generated and held securely
by the project owner, backed up independently, and supplied to GitHub Actions
via **encrypted secrets**. Never commit the `.jks` file, passwords,
base64 keystore contents, or keys to Git or logs.

Before a production update:

- Audit the Android application ID and signature of the currently installed
  APK; changing the signing key can block in-place installation.
- Provide a verified, full backup and restore path for SQLite **and**
  separate SharedPreferences settings, with real-device migration tests.
- Add a release-only CI job with fixed keystore secrets; verify APK signature
  and `applicationId`, and keep debug builds separately.
- Validate restore after process kill, crash, reinstall on test hardware and
  with an app upgrade before publishing instructions to end users.

## Automated regression

`test/verified_sqlite_backup_test.dart` creates a live SQLite v3 store,
writes a completed receipt and a segmented active-trip GPS journal,
exports a verified backup, opens it independently, then mutates the original
database to confirm the snapshot remains intact.
