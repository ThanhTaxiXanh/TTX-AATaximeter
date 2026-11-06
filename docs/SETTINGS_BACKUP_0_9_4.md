# TTX DRIVER PRO — Backing up settings and previewing a backup (0.9.4+24)

## Status and limits

Version 0.9.4 adds a **separate** manual JSON settings export and read-only
JSON inspection. It does **NOT** implement settings restoration or an atomic
full-app backup. The SQLite export from 0.9.3 remains available.

These two exports are required to retain most of a user's app data:

| Export menu | Contents | Not included |
| --- | --- | --- |
| **Sao lưu lịch sử (SQLite)** | Completed trip records, receipts, active checkpoint, saved GPS route | SharedPreferences settings, attached logo images |
| **Sao lưu cấu hình (JSON)** | Saved tariff and tariff catalog, vehicle registration, map/LED preferences, VietQR bank book, legacy VietQR settings | SQLite history, Android permissions, logo file contents, permission onboarding flags |

The JSON file includes **bank numbers and payee information in plaintext**.
There is no password/encryption. Do not upload it to public GitHub repos or
send it in a support screenshot. Choose private storage and apply device/file
encryption where available. The `centerLogoPath` / `footerLogoPath` fields
in bank preferences are local file paths, not a portable image backup.

## Driver workflow

1. End the trip and verify that it has been saved.
2. Export **Sao lưu lịch sử (SQLite)** to a trusted location.
3. Export **Sao lưu cấu hình (JSON)** from Settings or the top-right menu.
   Keep this JSON file privately alongside the SQLite file.
4. Optional: use **Kiểm tra tệp sao lưu cấu hình** in the top-right menu.
   It reads the JSON without editing settings and displays its UTC timestamp,
   number of configuration groups, and whether VietQR settings are present.
5. **Do not uninstall, change APK signing identity, or attempt to replace
   app-private database files** merely because a backup file was exported.
   Neither the full restore path nor migration between different APK
   signing keys has passed real-device tests.

The JSON file only includes values actually stored in preferences at backup
time. An unconfigured setting may be absent: this is not a promise that it
will be recreated or restored to another installation.

## Validation and file format

`SettingsBackupBundle` encodes
`{ "format": "ttx-driver-pro-settings", "schema": 1,
  "exportedAtUtc": "...Z", "settings": { "...": "raw JSON" } }`.

- Only six explicitly allowlisted SharedPreferences JSON string keys can be
  exported and accepted by the inspector.
- Each value is parsed through the corresponding domain codec/validator.
  Malformed bank accounts, unsupported schemas and unknown keys are rejected.
- Max JSON file size is **256 KiB**; the picker checks size before reading.
- Invalid or unsupported files are rejected; a successful dry-run means only
  that **the inspected JSON settings have a recognizable format**.
- The inspector never invokes `setString`, writes SQLite, creates accounts
  or changes an active fare.

## Automated tests

`test/settings_backup_bundle_test.dart` covers export/import round trips
(with no application to preferences), independence of the source map,
bank-account data, empty settings, invalid bank data, unsupported schema,
unknown keys, invalid field types, timestamp requirements and size limits.

## Future — restore and stable signing (not implemented)

A real restore workflow needs a recoverability model before accepting any
user file: authenticate backup provenance, validate database and settings
together, display preflight differences, protect current data with a fresh
rollback snapshot, replace files only when the SQLite connection is closed
and while no trip is running, and verify the result after process restart.
A self-contained backup archive should include portable logo bytes as well
as preferences and SQLite data, with a versioned manifest and checksums.
Release signing must use a stable private keystore held only in encrypted
GitHub secrets; changing signing keys risks preventing an in-place update.
