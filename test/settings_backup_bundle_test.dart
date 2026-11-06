import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/tariff_codec.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';
import 'package:ttx_aataximeter/src/domain/tariff_catalog.dart';
import 'package:ttx_aataximeter/src/domain/vehicle_registration.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('settings export preserves user configuration and VietQR exactly',
      () {
    final account = const VietQrAccount(
      bankBin: '970407',
      accountNumber: '123456789',
      accountName: 'TEST DRIVER',
    );
    final book = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'account-a', bankName: 'Test Bank', account: account),
      ],
      defaultId: 'account-a',
    );
    final vehicle = VehicleRegistration(
      category: VehicleCategory.fiveSeats,
      plate: '30A-12345', brand: 'VinFast');
    final original = <String, String>{
      DashboardPreferences.storageKey:
        const DashboardPreferences(darkMap: true, pitchDegrees: 70).encode(),
      'ttx_tariff_v1': TariffCodec.encode(TariffConfig.demo()),
      'ttx_vehicle_v1': vehicle.encode(),
      'ttx_vietqr_bank_book_v1': book.encode(),
      'ttx_vietqr_account_v1': jsonEncode(account.toJson()),
    };
    final backup = SettingsBackupBundle.fromValues(
      original,
      exportedAtUtc: DateTime.utc(2026, 11, 6, 8, 30));
    final decoded = SettingsBackupBundle.decode(backup.encode());

    expect(decoded.settings, original);
    expect(decoded.includesVietQr, true);
    expect(decoded.exportedAtUtc, DateTime.utc(2026, 11, 6, 8, 30));
    // The snapshot must not be backed by the original mutable map.
    original.clear();
    expect(decoded.settings, hasLength(5));
    expect(() => decoded.settings.clear(), throwsUnsupportedError);
  });

  test('blank device settings are a valid, explicitly empty snapshot', () {
    final backup = SettingsBackupBundle.fromValues(const {});
    expect(SettingsBackupBundle.decode(backup.encode()).settings, isEmpty);
    expect(backup.includesVietQr, false);
  });

  test('rejects unknown settings keys without importing anything', () {
    expect(
      () => SettingsBackupBundle.fromValues(
        const {'ttx_unrecognized_key': 'something'}),
      throwsFormatException,
    );
  });

  test('rejects malformed account book and malformed export schema', () {
    expect(
      () => SettingsBackupBundle.fromValues(
        const {'ttx_vietqr_bank_book_v1': '{"version":1,"accounts":[{}]}'}),
      throwsFormatException,
    );
    expect(
      () => SettingsBackupBundle.decode(
        '{"format":"ttx-driver-pro-settings","schema":99,'
        '"exportedAtUtc":"2026-11-06T00:00:00.000Z","settings":{}}'),
      throwsFormatException,
    );
  });

  test('rejects non-string settings and unexpected timezone', () {
    expect(
      () => SettingsBackupBundle.decode(
        '{"format":"ttx-driver-pro-settings","schema":1,'
        '"exportedAtUtc":"2026-11-06T00:00:00.000Z",'
        '"settings":{"ttx_tariff_v1":42}}'),
      throwsFormatException,
    );
    expect(
      () => SettingsBackupBundle.decode(
        '{"format":"ttx-driver-pro-settings","schema":1,'
        '"exportedAtUtc":"2026-11-06T08:00:00",'
        '"settings":{}}'),
      throwsFormatException,
    );
  });

  test('rejects unexpectedly large backup payloads', () {
    final huge = 'x' * SettingsBackupBundle.maxExportBytes;
    expect(
      () => SettingsBackupBundle.decode(huge),
      throwsFormatException,
    );
  });

  test('all registered user configuration categories are included in a '
      'complete portable snapshot, excluding Android permission flags',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesAsync();
    final account = const VietQrAccount(
      bankBin: '970407', accountNumber: '123456789',
      accountName: 'DRIVER TEST');
    final settings = <String, String>{
      DashboardPreferences.storageKey:
          const DashboardPreferences(default3D: true, darkMap: true,
            showCurrentRoadName: false).encode(),
      'ttx_tariff_v1': TariffCodec.encode(TariffConfig.demo()),
      'ttx_tariff_catalog_v1': TariffCatalog.initial().encode(),
      'ttx_vehicle_v1': VehicleRegistration(
          category: VehicleCategory.fiveSeats, brand: 'VinFast',
          plate: '98G-001.07').encode(),
      'ttx_vietqr_bank_book_v1': BankBook(accounts: [
        SavedBankAccount(id: 'one', bankName: 'Test Bank',
          account: account),
      ], defaultId: 'one').encode(),
      'ttx_vietqr_account_v1': jsonEncode(account.toJson()),
    };
    for (final entry in settings.entries) {
      await prefs.setString(entry.key, entry.value);
    }
    await prefs.setBool('ttx_location_onboarded_v1', true);
    await prefs.setBool('ttx_background_explained_v1', true);
    expect(
      SettingsBackupBundle.configurationGroups.values
        .expand((list) => list).toSet(),
      SettingsBackupBundle.supportedKeys.toSet(),
    );
    final backup = await SettingsBackupBundle.capture(prefs);
    final restored = SettingsBackupBundle.decode(backup.encode());
    expect(restored.settings, settings);
    expect(restored.capturedGroups, {
      'Xe & hồ sơ': 1,
      'Cước phí & chuyến đi': 2,
      'Bản đồ, lời chào & HUD': 1,
      'Thanh toán VietQR': 2,
    });
    expect(restored.settings.containsKey('ttx_location_onboarded_v1'),
      isFalse);
    expect(restored.settings.containsKey('ttx_background_explained_v1'),
      isFalse);
  });

  test('new unknown TTX preference cannot be silently left out of backups',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesAsync();
    await prefs.setString('ttx_future_user_option', 'value');
    await expectLater(SettingsBackupBundle.capture(prefs),
      throwsFormatException);
  });
}
