import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  /// Returns null when no *real* bundled dataset exists. Never creates a
  /// placeholder traffic sign or modifies the independent trip database.
  static Future<TrafficSignRepository?> openOptional() async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory(path.join(root.path, 'traffic_signs'));
    await folder.create(recursive: true);
    final target = File(path.join(folder.path, 'traffic_signs_v1.sqlite'));
    final marker = File('${target.path}.sha256');

    if (await target.exists() && await marker.exists() &&
        (await marker.readAsString()).trim() == expectedSha256) {
      try {
        final existing = await openDatabase(target.path, readOnly: true);
        try {
          await _verifyMetadata(existing);
          return TrafficSignRepository(existing);
        } catch (_) {
          await existing.close();
        }
      } catch (_) {
        // Damaged cache can be recovered from the owner-approved asset.
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
      // Existing database is a disposable cache, not taxi trip storage.
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      await marker.writeAsString(expectedSha256, flush: true);
      final installed = await openDatabase(target.path, readOnly: true);
      return TrafficSignRepository(installed);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
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
