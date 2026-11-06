# TTX DRIVER PRO — Unified backup v2 with VietQR logos (0.9.6+26)

## Changes since 0.9.5

The export-only `.ttxbackup` container now embeds **actual bytes** for locally
configured VietQR center and footer logos. A copied backup is no longer just
a list of old file paths for these two user-imported images.

- SQLite and settings JSON are still the two core payloads.
- Logo slots are `center` and `footer`, each at most 8 MiB.
- Supported image extensions: PNG, JPEG, WebP, GIF, BMP and SVG.
- Each logo has a manifest entry with slot, extension, byte length and SHA-256.
- The export reads only logo files inside the app's `ttx_qr_logos` support
  directory; it rejects missing files, unexpected file locations, symlinks
  resolving outside that directory, oversized payloads and obvious format
  mismatches. SVG content with script/DOCTYPE/ENTITY/foreignObject/href
  markup is rejected conservatively.
- If a saved logo path is invalid or unreadable, export fails explicitly:
  it does **not** silently claim a complete backup.
- The previous version 1 format remains readable. Version 1 archives have no
  portable logo bytes, even if they contain old paths.
- Logo content is only validated for signature/format hints and checksum.
  This is **not** full image-decoder verification on every Android device.
- The inspector reports how many logo payloads were included and still does
  not write anything into the app's live SQLite or settings.

## Binary format

Version 2 keeps the same prefix:

1. `TTXDRVPROBK1` 12-byte ASCII magic.
2. Manifest length as unsigned 32-bit big-endian.
3. UTF-8 JSON manifest with `schema: 2`, the standard settings and SQLite
   metadata/hashes, and a `logos` array with the fields above.
4. Encoded settings JSON.
5. Verified SQLite snapshot.
6. Zero to two raw logo byte payloads in manifest order.

The reader accepts `schema: 1` and `schema: 2`, checks the exact payload
length and SHA-256 for every section and rejects duplicate logo slots.

## What is *not* covered

- The stored bank book JSON still carries the **old absolute logo paths**.
  Those paths must be mapped to new application-owned paths if a future
  restore is implemented. No restore exists in this version.
- Other app-private files, Android permissions or signing keys are excluded.
- The combined archive is not encrypted or authenticated: bank numbers, GPS
  history, receipts and logos remain readable by anyone with file access.
- File picker export is still buffered in memory and capped by 64 MiB SQLite,
  256 KiB settings and 2 x 8 MiB logo data. Real-device memory tests remain
  necessary, and future streaming export is preferred.
- SQLite and preferences are sampled sequentially. This is not a
  cross-store atomic device snapshot.
- Signing is still test-only. Do not uninstall the current installed APK or
  try a different signature before a tested end-to-end restore exists.

## Regression coverage

- `test/backup_logo_asset_test.dart`: owned-directory captures, missing and
  external paths, invalid image formats, active SVG content and size guards.
- `test/unified_backup_bundle_test.dart`: exact v2 image roundtrip,
  tampered logo SHA-256 rejection, duplicate slot rejection, legacy v1 reader.
- `test/verified_sqlite_backup_test.dart`: real SQLite receipt and route
  checkpoint roundtrip with bundled logo payload and read-only inspection.

## Future

Before enabling restore: introduce an explicit user-approved migration plan
with encrypted backup option, independent integrity checks, comparison UI,
pre-restore rollback snapshot, closed SQLite connection, verified logo
rewriting into app-owned paths, crash/restart tests and a stable private
release keystore. None of those are silently enabled by v0.9.6.
