import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'settings_backup_bundle.dart';

/// Portable *export-only* container for the two primary app data stores.
///
/// Binary layout (version 1):
///   ASCII magic (12 bytes) + manifest length (4-byte unsigned big-endian)
///   + UTF-8 JSON manifest + settings JSON bytes + SQLite snapshot bytes.
///
/// SHA-256 detects accidental corruption; it does NOT authenticate provenance
/// or encrypt bank account / GPS data. No restore/write method is provided.
class UnifiedBackupBundle {
  UnifiedBackupBundle._({
    required this.createdAtUtc,
    required this.settings,
    required this.sqliteBytes,
  });

  static const format = 'ttx-driver-pro-combined';
  static const schema = 1;
  static const maxSqliteBytes = 64 * 1024 * 1024;
  static const maxManifestBytes = 4096;
  static const _magic = 'TTXDRVPROBK1';
  static const maxBundleBytes =
      maxSqliteBytes + SettingsBackupBundle.maxExportBytes +
      maxManifestBytes + 16;

  final DateTime createdAtUtc;
  final SettingsBackupBundle settings;
  final Uint8List sqliteBytes;

  factory UnifiedBackupBundle.fromParts({
    required SettingsBackupBundle settings,
    required Uint8List sqliteBytes,
    DateTime? createdAtUtc,
  }) {
    if (sqliteBytes.isEmpty || sqliteBytes.length > maxSqliteBytes) {
      throw const FormatException('Dung lượng SQLite không hợp lệ');
    }
    // Own a private copy so caller mutations cannot silently change what is
    // exported after checksums have been computed.
    return UnifiedBackupBundle._(
      createdAtUtc: (createdAtUtc ?? DateTime.now()).toUtc(),
      settings: settings,
      sqliteBytes: Uint8List.fromList(sqliteBytes),
    );
  }

  Uint8List encode() {
    final preferencesBytes = Uint8List.fromList(
      utf8.encode(settings.encode()));
    final manifestBytes = utf8.encode(jsonEncode({
      'format': format,
      'schema': schema,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'settingsLength': preferencesBytes.length,
      'sqliteLength': sqliteBytes.length,
      'settingsSha256': sha256.convert(preferencesBytes).toString(),
      'sqliteSha256': sha256.convert(sqliteBytes).toString(),
    }));
    if (manifestBytes.length > maxManifestBytes) {
      throw const FormatException('Thông tin gói sao lưu quá lớn');
    }
    final length = ByteData(4)..setUint32(
        0, manifestBytes.length, Endian.big);
    final output = BytesBuilder(copy: false)
      ..add(ascii.encode(_magic))
      ..add(length.buffer.asUint8List())
      ..add(manifestBytes)
      ..add(preferencesBytes)
      ..add(sqliteBytes);
    final result = output.takeBytes();
    if (result.length > maxBundleBytes) {
      throw const FormatException('Gói sao lưu vượt dung lượng cho phép');
    }
    return result;
  }

  factory UnifiedBackupBundle.decode(Uint8List fileBytes) {
    final magic = ascii.encode(_magic);
    if (fileBytes.length <= magic.length + 4 ||
        fileBytes.length > maxBundleBytes) {
      throw const FormatException('Dung lượng gói sao lưu không hợp lệ');
    }
    for (var i = 0; i < magic.length; i++) {
      if (fileBytes[i] != magic[i]) {
        throw const FormatException('Không phải gói TTX Driver Pro');
      }
    }
    final manifestLength = ByteData.sublistView(
      fileBytes, magic.length, magic.length + 4).getUint32(0, Endian.big);
    if (manifestLength == 0 ||
        manifestLength > maxManifestBytes ||
        magic.length + 4 + manifestLength >= fileBytes.length) {
      throw const FormatException('Header gói sao lưu không hợp lệ');
    }
    final payloadStart = magic.length + 4 + manifestLength;
    final manifest = jsonDecode(utf8.decode(
      Uint8List.sublistView(fileBytes, magic.length + 4, payloadStart),
      allowMalformed: false));
    if (manifest is! Map ||
        manifest['format'] != format ||
        manifest['schema'] != schema) {
      throw const FormatException('Phiên bản gói sao lưu không được hỗ trợ');
    }
    final settingsLength = manifest['settingsLength'];
    final sqliteLength = manifest['sqliteLength'];
    if (settingsLength is! int || settingsLength < 0 ||
        settingsLength > SettingsBackupBundle.maxExportBytes ||
        sqliteLength is! int || sqliteLength <= 0 ||
        sqliteLength > maxSqliteBytes ||
        payloadStart + settingsLength + sqliteLength != fileBytes.length) {
      throw const FormatException('Độ dài dữ liệu sao lưu không khớp');
    }
    final settingsDigest = manifest['settingsSha256'];
    final sqliteDigest = manifest['sqliteSha256'];
    if (settingsDigest is! String || sqliteDigest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(settingsDigest) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sqliteDigest)) {
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
    final preferences = Uint8List.sublistView(
      fileBytes, payloadStart, payloadStart + settingsLength);
    final database = Uint8List.sublistView(
      fileBytes, payloadStart + settingsLength, fileBytes.length);
    if (sha256.convert(preferences).toString() != settingsDigest ||
        sha256.convert(database).toString() != sqliteDigest) {
      throw const FormatException('Gói sao lưu bị thay đổi hoặc hỏng dữ liệu');
    }
    return UnifiedBackupBundle._(
      createdAtUtc: created,
      settings: SettingsBackupBundle.decode(
        utf8.decode(preferences, allowMalformed: false)),
      sqliteBytes: Uint8List.fromList(database),
    );
  }
}
