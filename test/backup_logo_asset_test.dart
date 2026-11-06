import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';

void main() {
  final png = Uint8List.fromList(
    const [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);

  test('captures only configured app-owned logo with portable bytes',
      () async {
    final root = await Directory.systemTemp.createTemp('ttx-logo-test-');
    try {
      final logos = Directory(path.join(root.path, 'ttx_qr_logos'));
      await logos.create();
      final source = File(path.join(logos.path, 'center.png'));
      await source.writeAsBytes(png);
      final book = BankBook(centerLogoPath: source.path);
      final captures = await BackupLogoCapture.fromBankBook(
        bankBook: book, appSupportDirectory: root);
      expect(captures, hasLength(1));
      expect(captures.single.slot, 'center');
      expect(captures.single.extension, 'png');
      expect(captures.single.bytes, png);

      await source.delete(); // The archive owns a copy, not a path.
      expect(captures.single.bytes, png);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('refuses missing and externally located logos', () async {
    final root = await Directory.systemTemp.createTemp('ttx-logo-root-');
    final outside = await Directory.systemTemp.createTemp('ttx-logo-outside-');
    try {
      final logos = Directory(path.join(root.path, 'ttx_qr_logos'));
      await logos.create();
      final external = File(path.join(outside.path, 'center.png'));
      await external.writeAsBytes(png);
      await expectLater(
        BackupLogoCapture.fromBankBook(
          bankBook: BankBook(centerLogoPath: external.path),
          appSupportDirectory: root),
        throwsFormatException);
      await expectLater(
        BackupLogoCapture.fromBankBook(
          bankBook: BankBook(
            footerLogoPath: path.join(logos.path, 'footer.png')),
          appSupportDirectory: root),
        throwsFormatException);
    } finally {
      await root.delete(recursive: true);
      await outside.delete(recursive: true);
    }
  });

  test('logo signatures, slots, sizes and active SVG content are rejected',
      () {
    expect(
      () => BackupLogoAsset(
        slot: 'unknown', extension: 'png', bytes: png),
      throwsFormatException);
    expect(
      () => BackupLogoAsset(
        slot: 'center', extension: 'png',
        bytes: Uint8List.fromList(const [0, 1, 2])),
      throwsFormatException);
    expect(
      () => BackupLogoAsset(
        slot: 'footer', extension: 'svg',
        bytes: Uint8List.fromList(
          '<svg><script>alert(1)</script></svg>'.codeUnits)),
      throwsFormatException);
    expect(
      () => BackupLogoAsset(
        slot: 'footer', extension: 'gif',
        bytes: Uint8List(BackupLogoAsset.maxBytes + 1)),
      throwsFormatException);
  });
}
