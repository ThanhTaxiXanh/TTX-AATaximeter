# TTX DRIVER PRO — Fix VietQR account and logo recovery (0.9.12+32)

## Report and inspected evidence

A driver reported that importing `.ttxbackup` restored completed trip
history but not the VietQR payment QR. A privately provided unified archive
was inspected **read-only**, without committing account numbers or image
contents to GitHub.

The provided archive passed SHA-256 and SQLite integrity checks and contained:
- Unified archive schema 2 and valid settings export schema 1;
- One completed trip and a valid SQLite v3 database;
- `ttx_vietqr_bank_book_v1` with one configured VietQR account and a default;
- Two intact, hash-verified PNG logo attachments (center and footer).

The QR is **generated from saved bank account data**; the archive stores
the underlying VietQR recipient configuration and optional logo images,
not a standalone QR bitmap.

## Confirmed code defects

1. In `BackupSettingsImporter.importMissing`, the bank book JSON was
   skipped if the SharedPreferences key already existed — even when it
   represented an empty account list. This could omit all archived accounts
   and both logo attachments.
2. `_bankBook` was loaded into the main Flutter widget state only at
   startup. When the importer persisted the bank book correctly, a still-
   running app could continue displaying an empty recipient/QR until restart.
3. The early return for an archive containing no new **keys or trips**
   ignored new accounts contained inside an already present bank book key.

## Fix

- `VietQrMergePlan` compares archived and device bank accounts by bank BIN
  plus account number, without printing or exporting sensitive values.
- Import accounts not already configured, up to the existing 15-account
  cap. Preserve each existing account's identifier, recipient name and
  bank, and preserve the existing default selection.
- When an archived ID collides with a different existing account, create
  a deterministic, conflict-free new identifier for the archived account.
- Import the center/footer logo bytes into the app-owned logo directory if
  that slot does not already have a configured path. **Never replace a
  currently configured logo path.** Legacy absolute paths from the archive
  are never trusted as portable file paths.
- If the app already contains an empty bank book key, merge archived
  account/brand logo entries instead of treating the key as a complete
  configuration.
- The pre-import preview displays how many VietQR accounts/logos would be
  added and permits an import that consists only of missing VietQR entries.
- After a successful post-import verification, refresh the in-memory
  `_bankBook` immediately so the payment QR can render without restarting
  the app. Even an otherwise no-op repeat import refreshes saved bank
  settings to repair stale UI state.
- Postflight permits only semantic additive changes to VietQR while still
  rejecting any alteration to an existing bank account/default/previously
  configured logo. Other stored settings must remain unchanged.

## How to retry on Android

1. Keep your installed application and your `.ttxbackup` original. Do
   **not** uninstall the app or clear its private data.
2. Install the newly validated build only if its signing identity permits
   an in-place update. If Android rejects the update due to signing keys,
   do not uninstall the existing version merely to install the new one.
3. Open **Cài đặt → Nhập bản sao lưu (.ttxbackup)** and select your original.
4. Confirm the preview listing new VietQR accounts and logo attachments.
   History receipts already present are skipped without modification.
5. After the success dialog, open **Mã QR thanh toán** and verify the
   bank/recipient and center/footer logos. Check with a bank app using a
   safe, non-payment scan before relying on it with a customer.
6. Export and separately validate an updated backup. The previous importer
   preserves existing receipts and a pre-import recovery snapshot.

## Verification status

Automated tests cover empty-key restoration, preserving an existing bank
book, duplicate detection, conflicting archive IDs, both portable logos,
and postflight rejection of changes to pre-existing bank accounts. Release
build and Android device testing must still be confirmed for the final
commit, including Android file picker and QR scanning.

## Boundaries

The importer is additive. It intentionally does NOT overwrite an existing
account or a currently configured logo path with differently valued data.
It is NOT a full destructive restore, automatic rollback or an encrypted
backup system. The draft pull request remains unmerged; main is unchanged.
