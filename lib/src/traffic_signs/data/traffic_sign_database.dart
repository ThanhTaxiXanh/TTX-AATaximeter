import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'traffic_sign_repository.dart';

/// The source database is generated at build time, never on GPS updates.
abstract final class TrafficSignDatabase {
  static const assetPath = 'assets/data/traffic_signs/traffic_signs.sqlite';
  static const expectedSha256 =
      'a8dc5b6f3b09546604a395d3236a9a9b12872cc81162e86db9f2a878e5319ec7';
  static const trafficSourceSha =
      '20f59d11fc0f98df3f7c830165ce14684915fa98b2054d017cc09fcab017d5ff';
  static const speedSourceSha =
      '77142d75a7f03cd3ada06804743e55ed49c5ab3ceb0e8dca0afe95616f481dc7';

  // Share the immutable database across 2D/3D map remounts instead of
  // repeatedly copying assets or running a 21 MB SQLite quick_check.
  static Future<TrafficSignRepository?>? _opened;

  static Future<TrafficSignRepository?> openOptional() =>
      _opened ??= _openOnce();

  /// Returns null when no verified bundled/previously imported dataset exists.
  static Future<TrafficSignRepository?> _openOnce() async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory(path.join(root.path, 'traffic_signs'));
    await folder.create(recursive: true);
    final target = File(path.join(folder.path, 'traffic_signs_v1.sqlite'));
    final marker = File('${target.path}.sha256');
    // Recover an interrupted atomic swap of this standalone sign cache.
    final previous = File('${target.path}.previous');
    if (!await target.exists() && await previous.exists()) {
      await previous.rename(target.path);
    }

    if (await target.exists() && await marker.exists() &&
        (await marker.readAsString()).trim() == expectedSha256) {
      try {
        // The marker is not a checksum of today's bytes. Verify the actual
        // cache once per app process before accepting it as owner data.
        // The shared _opened future prevents this 21 MB stream from being
        // repeated every time the driver changes between 2D and 3D.
        final digest = await sha256.bind(target.openRead()).first;
        if (digest.toString() != expectedSha256) {
          throw StateError('Cached traffic-sign SQLite SHA-256 mismatch');
        }
        final existing = await openDatabase(target.path, readOnly: true);
        try {
          await _verifyMetadata(existing);
          return TrafficSignRepository(existing);
        } catch (_) {
          await existing.close();
          rethrow;
        }
      } catch (error) {
        debugPrint('Traffic-sign cache rejected: $error');
        // Damaged cache can be recovered only from a verified bundled
        // asset or a new owner-selected import; never trust the marker.
      }
    }

    ByteData bytes;
    try {
      bytes = await rootBundle.load(assetPath);
    } on FlutterError {
      // GitHub must bundle the real 151228-record database separately;
      // a successfully compiled app does not imply that it has sign data.
      return null;
    }
    final temporary = File('${target.path}.installing');
    try {
      await temporary.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      final digest = await sha256.bind(temporary.openRead()).first;
      if (digest.toString() != expectedSha256) {
        throw StateError('Bundled traffic-sign database SHA-256 mismatch');
      }
      final candidate = await openDatabase(temporary.path, readOnly: true);
      try {
        await _verifyMetadata(candidate);
      } finally {
        await candidate.close();
      }
      await _promoteChecked(temporary, target, marker);
      final installed = await openDatabase(target.path, readOnly: true);
      return TrafficSignRepository(installed);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Import the owner-verified database selected in Android's file picker.
  /// Never writes to the separate taxi trip database or parses fake signs.
  static Future<TrafficSignRepository> installFromFile(File source) async {
    if (!await source.exists() || await source.length() != 21090304) {
      throw StateError('Tệp không khớp dung lượng database biển báo');
    }
    final root = await getApplicationSupportDirectory();
    final folder = Directory(path.join(root.path, 'traffic_signs'));
    await folder.create(recursive: true);
    final target = File(path.join(folder.path, 'traffic_signs_v1.sqlite'));
    final marker = File('${target.path}.sha256');
    final temporary = File('${target.path}.importing');
    try {
      if (await temporary.exists()) await temporary.delete();
      await source.copy(temporary.path);
      final digest = await sha256.bind(temporary.openRead()).first;
      if (digest.toString() != expectedSha256) {
        throw StateError('SHA-256 không khớp database biển báo đã duyệt');
      }
      final candidate = await openDatabase(temporary.path, readOnly: true);
      try {
        await _verifyMetadata(candidate);
      } finally {
        await candidate.close();
      }
      // Old cache is never removed until the replacement has passed checks.
      await _promoteChecked(temporary, target, marker);
      final database = await openDatabase(target.path, readOnly: true);
      final repository = TrafficSignRepository(database);
      _opened = Future.value(repository);
      return repository;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Android/iOS file-picker flow. Streams SAF/Files content to a staging
  /// file, preserving memory, then validates exact owner database SHA-256.
  /// A cancelled picker does not change the existing database.
  static Future<TrafficSignRepository?> pickAndInstall() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return null;
    final reportedSize = picked.lengthSync() ?? await picked.length();
    if (reportedSize != null && reportedSize != 21090304) {
      throw StateError('Dung lượng tệp không khớp dữ liệu thật');
    }
    final tempDirectory = await getTemporaryDirectory();
    final temporary = File(path.join(
      tempDirectory.path,
      'ttx_sign_import_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ));
    try {
      await picked.readAsByteStream()
          .cast<List<int>>()
          .pipe(temporary.openWrite());
      return await installFromFile(temporary);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// A replacement of the isolated traffic-sign cache is rollback-safe.
  /// The trip/billing SQLite database and user settings are untouched.
  static Future<void> _promoteChecked(
      File temporary, File target, File marker) async {
    final previous = File('${target.path}.previous');
    if (await previous.exists() && !await target.exists()) {
      await previous.rename(target.path);
    }
    if (await previous.exists()) await previous.delete();
    if (await target.exists()) await target.rename(previous.path);
    try {
      await temporary.rename(target.path);
      await marker.writeAsString(expectedSha256, flush: true);
      final verified = await openDatabase(target.path, readOnly: true);
      try {
        await _verifyMetadata(verified);
      } finally {
        await verified.close();
      }
    } catch (_) {
      if (await target.exists()) await target.delete();
      if (await previous.exists()) await previous.rename(target.path);
      rethrow;
    }
    if (await previous.exists()) await previous.delete();
  }

  static Future<void> _verifyMetadata(Database db) async {
    final rows = await db.query('metadata');
    final values = <String, String>{
      for (final row in rows)
        row['key'] as String: row['value'] as String,
    };
    if (values['schema_version'] != '1' ||
        values['traffic_sha256'] != trafficSourceSha ||
        values['speed_sha256'] != speedSourceSha ||
        values['traffic_count'] != '151228' ||
        values['inferred_count'] != '38757' ||
        values['verification_status'] != 'unverified') {
      throw StateError('Traffic sign database metadata mismatch');
    }
    final consistency = await db.rawQuery('PRAGMA quick_check');
    if (consistency.isEmpty ||
        consistency.first.values.first.toString() != 'ok') {
      throw StateError('Traffic sign database integrity check failed');
    }
    final rowsExist = await db.rawQuery(
      'SELECT sign_id FROM traffic_sign_rtree LIMIT 1',
    );
    if (rowsExist.isEmpty) throw StateError('Missing spatial index');
  }
}
