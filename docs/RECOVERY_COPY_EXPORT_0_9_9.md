# TTX DRIVER PRO — Exporting pre-import safety backups (0.9.9+29)

## Problem addressed

The additive import introduced in 0.9.8 created a private copy of the
current trip history, settings and portable VietQR logos before writing
any imported data. Those copies were kept at
`<app-support>/ttx_pre_import_safety/truoc_nhap_<timestamp>.ttxbackup`.

They were not visible in the app and would normally be deleted if Android
uninstalled the application. That is a meaningful recoverability gap.

## New functionality

A **Xuất bản dự phòng trước khi nhập** entry is available in Settings and
the top-right tools menu:

1. Finish any active trip.
2. Open **Cài đặt → Xuất bản dự phòng trước khi nhập**.
3. Select a timestamped private safety copy. The app displays its creation
   time and size without showing sensitive trip/bank data.
4. The app reads and verifies the selected archive's framing, SHA-256
   checksums, settings schema, logo payloads, SQLite integrity and receipt/GPS
   structure before offering the export action.
5. Select **Xuất tệp ra ngoài**, then choose a trusted destination using
   the Android file picker.
6. Keep the exported `.ttxbackup` somewhere safe outside app-private
   storage. The internal original remains untouched.

Files with unexpected names, non-file entries and oversized archives are
not listed. Symbolic links are not followed. Corrupted snapshots are
refused rather than offered as verified exports.

## Atomic publication of safety snapshots

New imports create the private pre-import snapshot in two stages:

- Write all bytes to a temporary `.ttxbackup.tmp` file and flush storage.
- Decode and validate the written archive, then rename it to the final
  `.ttxbackup` filename in the same directory.

The recovery-copy listing ignores temporary files. This avoids
mistaking an interrupted write for an available complete backup. Neither
existing private snapshots nor installed trip records are overwritten by
this feature.

## Additional safeguards

- Starting a fixed-price trip while the import process is busy is blocked,
  complementing the regular fare-start guard.
- The import completion dialog explains where to find the **export pre-import
  safety copy** action.
- This change does not modify fare calculation, GPS measurement, trip route
  checkpoint logic, payment QR generation or SQLite schema.

## Remaining limits

- This is **export**, NOT a built-in rollback or replacement restore.
  A private recovery snapshot is not automatically reapplied after an import
  failure. The additive import may still complete in stages across SQLite,
  SharedPreferences and image files.
- The archive is **not encrypted** or authenticated. Its SHA-256 digests
  detect accidental damage, not malicious alteration. It can contain
  bank details, vehicle information and exact trip GPS coordinates.
- Export uses the same buffered Android picker and file-size limits
  as the unified-backup feature. Physical-device memory and file-provider
  testing is still required.
- Backups retained inside the app consume disk space. This version does not
  automatically delete recovery snapshots; future cleanup must require
  deliberate user approval and a safe external backup.
- The app still uses test-only release signing. Do not uninstall a working
  installation just to test an APK with a different signing key.
- A file successfully exported through the picker has not been separately
  verified *from the external destination* on a real phone. The driver
  should use the existing read-only inspection menu to verify that saved
  external file after export.

## Automated regression

`test/pre_import_backup_vault_test.dart` verifies listing behavior,
  archive validation, SQLite inspection, rejection of altered bytes,
  and that reading/export preparation never deletes the stored snapshot.

## Future implementation

End-to-end real-device verification, encrypted export, streaming
serialization, accessible recovery management and a safe rollback-capable
full restore remain outstanding. The existing additive importer continues
to protect existing trip IDs and does not resume archived active trips.
