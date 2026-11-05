# APK size optimization — 0.8.4+14

## Baseline from GitHub Actions (ZIP artifact, not APK)
- Build #67 before MapLibre 3D: 87,964,346 bytes archived.
- Build #85 with MapLibre 3D and universal DEBUG APK: 100,626,844 bytes archived.
- This is **not** the installed size, nor evidence that an AOT release is the same size. Check the CI size reports for raw APK bytes and native library ABI breakdown.

## Production features preserved
- Keep Flutter GPS preview/Android FGS, taximeter engine, fare policies, SQLite checkpoint/history, OpenStreetMap 2D, MapLibre 3D, VietQR and payment, vehicle registration, receipts and revenue.
- Do not remove MapLibre simply to make the APK smaller.
- Experimental Android Auto **source stays in** `tool/android_templates` and docs. It is not registered in AndroidManifest. The unused AndroidX Car libraries and unregistered service/screens are excluded from default phone builds. To compile those sources for future development, set `TTX_INCLUDE_CAR_SCAFFOLD=1` before invoking `tool/bootstrap_android.py`. This **does not** enable Android Auto.

## Build variants
1. `ttx-aataximeter-mvp-debug`: universal debug APK and size report. For inspecting program behavior; contains debug/JIT tooling, multiple native ABIs, and therefore is intentionally much larger.
2. `ttx-aataximeter-arm64-optimized-test-only`: AOT release, ARM64 only with Flutter icon tree-shaking and Android R8 optimization. Intended for Android ARM64 devices only. It cannot run on 32-bit-only devices or x86. The 2D/3D maps remain intact. Release builds enable R8 by default; do not add unsafe unconditional keep rules.
3. The second APK is **NOT production-signed**. The generated Flutter Android Gradle template uses a temporary debug signing configuration. Do not rely on in-place upgrades from previously installed APKs with different signatures; never uninstall the user's existing app or erase its SQLite data merely to install this test package. A stable release keystore/signing workflow and on-device regression testing are required before distributing an upgrade.

## Measurement
The CI prints `build/debug-size.txt` and `build/arm64-size.txt` with raw APK size, uncompressed ZIP contents grouped into native libraries, Flutter assets, DEX and resources, and ABIs. Compare the **raw APK sizes**, not simply the GitHub artifact ZIP size. The installed size may differ due to extraction, caches and runtime data.

## Reproduction
```sh
flutter create . --platforms=android --project-name ttx_aataximeter --org vn.thanhtaxixanh
python3 tool/bootstrap_android.py
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release --split-per-abi --target-platform android-arm64
python3 tool/apk_size_report.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
