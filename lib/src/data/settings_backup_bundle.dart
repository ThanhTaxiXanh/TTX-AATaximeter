import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dashboard_preferences.dart';
import '../domain/tariff_catalog.dart';
import '../domain/vehicle_registration.dart';
import '../payment/bank_book.dart';
import '../payment/vietqr.dart';
import 'tariff_codec.dart';

/// Read-only, versioned export of the user-managed settings that are
/// persisted outside SQLite. This class deliberately NEVER writes preferences.
class SettingsBackupBundle {
  SettingsBackupBundle._({
    required this.exportedAtUtc,
    required Map<String, String> settings,
  }) : settings = Map<String, String>.unmodifiable(settings);

  static const format = 'ttx-driver-pro-settings';
  static const maxExportBytes = 256 * 1024;

  /// Only values that the app itself persists as JSON strings.
  /// Device-specific permission onboarding flags are intentionally excluded.
  static const supportedKeys = <String>[
    DashboardPreferences.storageKey,
    'ttx_tariff_v1',
    'ttx_tariff_catalog_v1',
    'ttx_vehicle_v1',
    'ttx_vietqr_bank_book_v1',
    'ttx_vietqr_account_v1',
  ];

  final DateTime exportedAtUtc;
  final Map<String, String> settings;

  bool get includesVietQr =>
      settings.containsKey('ttx_vietqr_bank_book_v1') ||
      settings.containsKey('ttx_vietqr_account_v1');

  static Future<SettingsBackupBundle> capture(
    SharedPreferencesAsync preferences,
  ) async {
    final values = <String, String>{};
    for (final key in supportedKeys) {
      final raw = await preferences.getString(key);
      if (raw != null) values[key] = raw;
    }
    return SettingsBackupBundle.fromValues(values);
  }

  /// Exposed separately for deterministic unit tests and future dry-run
  /// migration checks; never mutates the original map or user preferences.
  factory SettingsBackupBundle.fromValues(
    Map<String, String> values, {
    DateTime? exportedAtUtc,
  }) {
    _validate(values);
    final at = (exportedAtUtc ?? DateTime.now()).toUtc();
    return SettingsBackupBundle._(
      exportedAtUtc: at,
      settings: values,
    );
  }

  String encode() {
    final encoded = jsonEncode({
      'format': format,
      'schema': 1,
      'exportedAtUtc': exportedAtUtc.toIso8601String(),
      'settings': settings,
    });
    if (utf8.encode(encoded).length > maxExportBytes) {
      throw const FormatException('Tệp sao lưu cấu hình vượt quá 256 KB');
    }
    return encoded;
  }

  factory SettingsBackupBundle.decode(String source) {
    if (utf8.encode(source).length > maxExportBytes) {
      throw const FormatException('Tệp sao lưu cấu hình quá lớn');
    }
    final parsed = jsonDecode(source);
    if (parsed is! Map ||
        parsed['format'] != format ||
        parsed['schema'] != 1 ||
        parsed['settings'] is! Map) {
      throw const FormatException('Không nhận diện được bản sao cấu hình TTX');
    }
    final rawDate = parsed['exportedAtUtc'];
    if (rawDate is! String) {
      throw const FormatException('Thiếu ngày tạo bản sao cấu hình');
    }
    final at = DateTime.tryParse(rawDate);
    if (at == null || !at.isUtc) {
      throw const FormatException('Ngày tạo bản sao không hợp lệ (UTC)');
    }
    final raw = parsed['settings'] as Map;
    final values = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Kiểu dữ liệu cấu hình không hợp lệ');
      }
      values[entry.key as String] = entry.value as String;
    }
    return SettingsBackupBundle.fromValues(
      values, exportedAtUtc: at);
  }

  static void _validate(Map<String, String> values) {
    for (final entry in values.entries) {
      if (!supportedKeys.contains(entry.key)) {
        throw FormatException('Khóa cấu hình không được hỗ trợ: ${entry.key}');
      }
      try {
        switch (entry.key) {
          case DashboardPreferences.storageKey:
            DashboardPreferences.decode(entry.value);
          case 'ttx_tariff_v1':
            TariffCodec.decode(entry.value);
          case 'ttx_tariff_catalog_v1':
            TariffCatalog.decode(entry.value);
          case 'ttx_vehicle_v1':
            VehicleRegistration.decode(entry.value);
          case 'ttx_vietqr_bank_book_v1':
            BankBook.decode(entry.value);
          case 'ttx_vietqr_account_v1':
            final data = jsonDecode(entry.value);
            if (data is! Map) {
              throw const FormatException('Dữ liệu VietQR cũ không hợp lệ');
            }
            final account = VietQrAccount.fromJson(
              Map<String, dynamic>.from(data));
            if (!account.isValid) {
              throw const FormatException('Tài khoản VietQR cũ không hợp lệ');
            }
        }
      } catch (error) {
        throw FormatException(
          'Cấu hình ${entry.key} không hợp lệ: $error');
      }
    }
  }
}
