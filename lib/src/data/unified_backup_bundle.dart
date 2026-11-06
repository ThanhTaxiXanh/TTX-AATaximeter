import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'backup_logo_asset.dart';
import 'settings_backup_bundle.dart';

/// Export-only container with integrity checks, never a restore operation.
///
/// V1: magic + manifest length + JSON manifest + settings + SQLite.
/// V2: same prefix + settings + SQLite + zero/two tagged logo payloads.
/// Version 1 remains readable for previously exported files.
class UnifiedBackupBundle {
  UnifiedBackupBundle._({
    required this.createdAtUtc,
    required this.settings,
    required this.sqliteBytes,
    required this.logos,
  });

  static const format = 'ttx-driver-pro-combined';
  static const schema = 2;
  static const maxSqliteBytes = 64 * 1024 * 1024;
  static const maxManifestBytes = 4096;
  static const _magic = 'TTXDRVPROBK1';
  static const maxBundleBytes =
      maxSqliteBytes + SettingsBackupBundle.maxExportBytes +
      2 * BackupLogoAsset.maxBytes + maxManifestBytes + 16;

  final DateTime createdAtUtc;
  final SettingsBackupBundle settings;
  final Uint8List sqliteBytes;
  final List<BackupLogoAsset> logos;

  factory UnifiedBackupBundle.fromParts({
    required SettingsBackupBundle settings,
    required Uint8List sqliteBytes,
    List<BackupLogoAsset> logos = const [],
    DateTime? createdAtUtc,
  }) {
    if (sqliteBytes.isEmpty || sqliteBytes.length > maxSqliteBytes) {
      throw const FormatException('Dung lượng SQLite không hợp lệ');
    }
    if (logos.length > 2 ||
        logos.map((logo) => logo.slot).toSet().length != logos.length) {
      throw const FormatException('Logo VietQR bị trùng hoặc quá số lượng');
    }
    return UnifiedBackupBundle._(
      createdAtUtc: (createdAtUtc ?? DateTime.now()).toUtc(),
      settings: settings,
      sqliteBytes: Uint8List.fromList(sqliteBytes),
      logos: List<BackupLogoAsset>.unmodifiable([
        for (final asset in logos) BackupLogoAsset(
          slot: asset.slot, extension: asset.extension, bytes: asset.bytes),
      ]),
    );
  }

  Uint8List encode() {
    final preferences = Uint8List.fromList(utf8.encode(settings.encode()));
    final manifest = utf8.encode(jsonEncode({
      'format': format,
      'schema': schema,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'settingsLength': preferences.length,
      'sqliteLength': sqliteBytes.length,
      'settingsSha256': sha256.convert(preferences).toString(),
      'sqliteSha256': sha256.convert(sqliteBytes).toString(),
      'logos': [
        for (final asset in logos) {
          'slot': asset.slot,
          'extension': asset.extension,
          'length': asset.bytes.length,
          'sha256': sha256.convert(asset.bytes).toString(),
        },
      ],
    }));
    if (manifest.isEmpty || manifest.length > maxManifestBytes) {
      throw const FormatException('Thông tin gói sao lưu quá lớn');
    }
    final size = ByteData(4)..setUint32(0, manifest.length, Endian.big);
    final builder = BytesBuilder(copy: false)
      ..add(ascii.encode(_magic))
      ..add(size.buffer.asUint8List())
      ..add(manifest)
      ..add(preferences)
      ..add(sqliteBytes);
    for (final asset in logos) {
      builder.add(asset.bytes);
    }
    final bytes = builder.takeBytes();
    if (bytes.length > maxBundleBytes) {
      throw const FormatException('Gói sao lưu vượt dung lượng cho phép');
    }
    return bytes;
  }

  factory UnifiedBackupBundle.decode(Uint8List input) {
    final magic = ascii.encode(_magic);
    if (input.length <= magic.length + 4 || input.length > maxBundleBytes) {
      throw const FormatException('Dung lượng gói sao lưu không hợp lệ');
    }
    for (var i = 0; i < magic.length; i++) {
      if (input[i] != magic[i]) {
        throw const FormatException('Không phải gói TTX Driver Pro');
      }
    }
    final manifestLength = ByteData.sublistView(
      input, magic.length, magic.length + 4).getUint32(0, Endian.big);
    if (manifestLength == 0 || manifestLength > maxManifestBytes ||
        magic.length + 4 + manifestLength >= input.length) {
      throw const FormatException('Header gói sao lưu không hợp lệ');
    }
    final payloadStart = magic.length + 4 + manifestLength;
    final manifest = jsonDecode(utf8.decode(
      Uint8List.sublistView(input, magic.length + 4, payloadStart),
      allowMalformed: false));
    if (manifest is! Map || manifest['format'] != format ||
        (manifest['schema'] != 1 && manifest['schema'] != schema)) {
      throw const FormatException('Phiên bản gói sao lưu không được hỗ trợ');
    }
    final settingsLength = manifest['settingsLength'];
    final sqliteLength = manifest['sqliteLength'];
    if (settingsLength is! int || settingsLength <= 0 ||
        settingsLength > SettingsBackupBundle.maxExportBytes ||
        sqliteLength is! int || sqliteLength <= 0 ||
        sqliteLength > maxSqliteBytes) {
      throw const FormatException('Dung lượng thành phần không hợp lệ');
    }
    final shaPrefs = manifest['settingsSha256'];
    final shaSqlite = manifest['sqliteSha256'];
    final digestPattern = RegExp(r'^[a-f0-9]{64}$');
    if (shaPrefs is! String || shaSqlite is! String ||
        !digestPattern.hasMatch(shaPrefs) ||
        !digestPattern.hasMatch(shaSqlite)) {
      throw const FormatException('Thiếu mã kiểm tra SHA-256');
    }
    final dateText = manifest['createdAtUtc'];
    if (dateText is! String) {
      throw const FormatException('Thiếu thời điểm sao lưu');
    }
    final created = DateTime.tryParse(dateText);
    if (created == null || !created.isUtc) {
      throw const FormatException('Thời điểm sao lưu không hợp lệ');
    }

    final descriptions = <Map<String, Object?>>[];
    if (manifest['schema'] == schema) {
      final records = manifest['logos'];
      if (records is! List || records.length > 2) {
        throw const FormatException('Danh sách logo không hợp lệ');
      }
      final slots = <String>{};
      for (final entry in records) {
        if (entry is! Map) {
          throw const FormatException('Mô tả logo không hợp lệ');
        }
        final slot = entry['slot'];
        final extension = entry['extension'];
        final count = entry['length'];
        final checksum = entry['sha256'];
        if (slot is! String || !BackupLogoAsset.supportedSlots.contains(slot) ||
            !slots.add(slot) || extension is! String ||
            !BackupLogoAsset.allowedExtensions.contains(extension) ||
            count is! int || count <= 0 ||
            count > BackupLogoAsset.maxBytes ||
            checksum is! String || !digestPattern.hasMatch(checksum)) {
          throw const FormatException('Logo không hợp lệ trong manifest');
        }
        descriptions.add({
          'slot': slot, 'extension': extension,
          'length': count, 'sha256': checksum,
        });
      }
    }
    final logoTotal = descriptions.fold<int>(
      0, (sum, record) => sum + (record['length']! as int));
    if (payloadStart + settingsLength + sqliteLength + logoTotal !=
        input.length) {
      throw const FormatException('Độ dài dữ liệu sao lưu không khớp');
    }
    final prefsStart = payloadStart;
    final sqliteStart = prefsStart + settingsLength;
    final logoStart = sqliteStart + sqliteLength;
    final preferences = Uint8List.sublistView(input, prefsStart, sqliteStart);
    final database = Uint8List.sublistView(input, sqliteStart, logoStart);
    if (sha256.convert(preferences).toString() != shaPrefs ||
        sha256.convert(database).toString() != shaSqlite) {
      throw const FormatException('Gói sao lưu bị thay đổi hoặc hỏng dữ liệu');
    }
    final assets = <BackupLogoAsset>[];
    var offset = logoStart;
    for (final record in descriptions) {
      final count = record['length']! as int;
      final payload = Uint8List.sublistView(input, offset, offset + count);
      if (sha256.convert(payload).toString() != record['sha256']) {
        throw const FormatException('Logo bị thay đổi hoặc hỏng dữ liệu');
      }
      assets.add(BackupLogoAsset(
        slot: record['slot']! as String,
        extension: record['extension']! as String,
        bytes: payload,
      ));
      offset += count;
    }
    return UnifiedBackupBundle._(
      createdAtUtc: created,
      settings: SettingsBackupBundle.decode(
        utf8.decode(preferences, allowMalformed: false)),
      sqliteBytes: Uint8List.fromList(database),
      logos: List<BackupLogoAsset>.unmodifiable(assets),
    );
  }
}
