import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'package:ttx_aataximeter/src/data/unified_backup_bundle.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';

void main() {
  SettingsBackupBundle settings() => SettingsBackupBundle.fromValues({
    DashboardPreferences.storageKey:
      const DashboardPreferences(darkMap: true).encode(),
  }, exportedAtUtc: DateTime.utc(2026, 11, 6, 0));

  final fakeDb = Uint8List.fromList([
    0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
  ]);

  test('combined container round-trips SQLite and settings bytes', () {
    final input = Uint8List.fromList(fakeDb);
    final bundle = UnifiedBackupBundle.fromParts(
      sqliteBytes: input, settings: settings(),
      createdAtUtc: DateTime.utc(2026, 11, 6, 1));
    input[0] = 0;
    final recovered = UnifiedBackupBundle.decode(bundle.encode());
    expect(recovered.sqliteBytes, fakeDb);
    expect(recovered.settings.settings, settings().settings);
    expect(recovered.createdAtUtc, DateTime.utc(2026, 11, 6, 1));
  });

  test('single-byte corruption is detected before any database inspection', () {
    final bundle = UnifiedBackupBundle.fromParts(
      sqliteBytes: fakeDb, settings: settings());
    final bytes = bundle.encode();
    bytes[bytes.length - 1] ^= 0x01;
    expect(() => UnifiedBackupBundle.decode(bytes), throwsFormatException);
  });

  test('corrupted header and appended bytes are rejected', () {
    final bytes = UnifiedBackupBundle.fromParts(
      sqliteBytes: fakeDb, settings: settings()).encode();
    final wrongMagic = Uint8List.fromList(bytes)..[0] = 0x00;
    expect(() => UnifiedBackupBundle.decode(wrongMagic),
      throwsFormatException);
    final expanded = Uint8List.fromList([...bytes, 0x01]);
    expect(() => UnifiedBackupBundle.decode(expanded),
      throwsFormatException);
    expect(() => UnifiedBackupBundle.decode(
      Uint8List.fromList(bytes.sublist(0, 12))),
      throwsFormatException);
  });

  test('refuses missing or oversized SQLite payload', () {
    expect(
      () => UnifiedBackupBundle.fromParts(
        sqliteBytes: Uint8List(0), settings: settings()),
      throwsFormatException);
    expect(
      () => UnifiedBackupBundle.fromParts(
        sqliteBytes: Uint8List(UnifiedBackupBundle.maxSqliteBytes + 1),
        settings: settings()),
      throwsFormatException);
  });

  test('portable center and footer logos survive archive roundtrip', () {
    final png = Uint8List.fromList(
      const [137, 80, 78, 71, 13, 10, 26, 10, 9]);
    final jpeg = Uint8List.fromList(const [255, 216, 255, 224, 2]);
    final bundle = UnifiedBackupBundle.fromParts(
      sqliteBytes: fakeDb,
      settings: settings(),
      logos: [
        BackupLogoAsset(slot: 'center', extension: 'png', bytes: png),
        BackupLogoAsset(slot: 'footer', extension: 'jpeg', bytes: jpeg),
      ],
    );
    final decoded = UnifiedBackupBundle.decode(bundle.encode());
    expect(decoded.logos, hasLength(2));
    expect(decoded.logos[0].slot, 'center');
    expect(decoded.logos[0].bytes, png);
    expect(decoded.logos[1].slot, 'footer');
    expect(decoded.logos[1].bytes, jpeg);
  });

  test('corrupting a logo is detected without changing SQLite checksum', () {
    final bundle = UnifiedBackupBundle.fromParts(
      sqliteBytes: fakeDb,
      settings: settings(),
      logos: [
        BackupLogoAsset(
          slot: 'center', extension: 'png',
          bytes: Uint8List.fromList(
            const [137, 80, 78, 71, 13, 10, 26, 10, 2]),
        ),
      ],
    );
    final bytes = bundle.encode();
    bytes[bytes.length - 1] ^= 0x01;
    expect(() => UnifiedBackupBundle.decode(bytes), throwsFormatException);
  });

  test('duplicate logo slots cannot be exported', () {
    final png = Uint8List.fromList(
      const [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(
      () => UnifiedBackupBundle.fromParts(
        sqliteBytes: fakeDb,
        settings: settings(),
        logos: [
          BackupLogoAsset(slot: 'center', extension: 'png', bytes: png),
          BackupLogoAsset(slot: 'center', extension: 'png', bytes: png),
        ],
      ),
      throwsFormatException);
  });

  test('legacy version 1 archives without logos remain readable', () {
    final prefs = utf8.encode(settings().encode());
    final db = fakeDb;
    final header = utf8.encode(jsonEncode({
      'format': UnifiedBackupBundle.format,
      'schema': 1,
      'createdAtUtc': '2026-11-06T01:00:00.000Z',
      'settingsLength': prefs.length,
      'sqliteLength': db.length,
      'settingsSha256': sha256.convert(prefs).toString(),
      'sqliteSha256': sha256.convert(db).toString(),
    }));
    final length = ByteData(4)..setUint32(0, header.length, Endian.big);
    final legacy = Uint8List.fromList([
      ...ascii.encode('TTXDRVPROBK1'),
      ...length.buffer.asUint8List(),
      ...header,
      ...prefs,
      ...db,
    ]);
    final checked = UnifiedBackupBundle.decode(legacy);
    expect(checked.logos, isEmpty);
    expect(checked.sqliteBytes, db);
    expect(checked.settings.settings, settings().settings);
  });
}
