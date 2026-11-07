# TTX Driver Pro — UI implementation 0.9.0+20

## Approved visual reference

The user approved the concept image with a navy/black premium dashboard,
cyan GPS/navigation highlights, yellow current fare, large colored primary
controls, status-dependent content, and an inline VietQR completion receipt.

The approved poster is a **static concept mockup**. A Flutter implementation
must preserve actual taximeter and map data; there are no fake map streets,
manufactured routes, decorative QR payloads, or placeholder payment results.

## UI system

- Brand: **TTX DRIVER PRO**, in a compact, italicized wordmark.
- Palette: near-black `#06101F`, navy cards `#0B1B30`, cyan
  `#00D8FC`, blue `#0078F4`, green `#00E669`, amber
  `#FFC107`, red `#FF383E`.
- Buttons: high-contrast, rounded with generous touch targets.
- Controls: dark translucent map overlays and an explicit segmented
  2D / 3D selector. Keep the 2D OSM/OpenFreeMap fallback and light/dark
  switch, plus recenter, compass, zoom and speed-limit display.
- Location arrow: use actual GPS position and heading; show the live
  vector position in native 3D and rotate the 2D GPS marker.
- The original custom greeting and completion message remain available
  via a compact accessible ticker below the status heading.

## Three taximeter phases

| State | Main dashboard | Permanent bottom action |
|---|---|---|
| Idle — SẴN SÀNG | GPS map, selected fare profile, GPS state, 0đ fare, km/speed and price quotation | Large green **Bắt đầu** |
| Active — ĐANG CHẠY / TẠM DỪNG | Map, amber live fare, km/duration/charged waiting minutes, BOT entry, GPS status, expandable tariff breakdown | Large amber **Tạm dừng/Tiếp tục** and red **Kết thúc** |
| Finished — HOÀN THÀNH | Live total, summary, saved fare reference | Green **Chuyến mới** or **THỬ LƯU LẠI CHUYẾN** |

## Completion receipt

- Shows actual **Tổng tiền chuyến** in a highlighted green card.
- Shows real distance, elapsed time, charged waiting minutes, BOT and
  other recorded fees, saved vehicle/fare metadata.
- **Tiền mặt** and **Chuyển khoản** only; no separate card payment action.
- When transfer is selected, renders the existing EMV VietQR payload
  generated from the driver's saved bank account and actual final amount,
  without repainting or inventing a QR code.
- Clearly states that a QR view or method selection does not prove that
  bank funds have arrived.

## Preserved behavior and risk

No changes to the taximeter fare engine, GPS acceptance or segmentation,
waiting grace period, SQLite v3 incremental route journal, trip history,
fare editing/swipe-delete, bank-account management, background service,
2D fallback or 3D MapLibre handling.

Real-world vector building detail depends on connectivity and available
OpenFreeMap tiles: the UI mockup cannot guarantee that every location
has identical geometry. No third-party app assets or trademark artwork
were copied.

## Verification

Run all Flutter unit/widget tests and CI Analyze and APK builds. On a real
phone, verify at least:

1. Display at small/large font scale and narrow screens, with primary
   trip buttons always visible without scrolling.
2. 2D/3D transitions, live GPS marker position/heading, map tile fallback,
   light/dark controls and trip route accuracy.
3. Start, pause, resume, BOT, finish, transfer QR and new-trip flow.
4. Existing history/SQLite records remain intact after update.
5. Clear contrast without glare at night and no tappable controls
   obstructing the map.

The Release ARM64 artifact is still test-signed. Back up trip data before
any uninstall or incompatible-signature update. A passing CI run does not
measure real-device map FPS or payment settlement.
