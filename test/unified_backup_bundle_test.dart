import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
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
}
