import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/traffic_sign.dart';

/// LOCAL QA workflow: NOT shared between drivers or authenticated by a server.
/// A future multiuser rollout must authorize approval on a trusted backend.
enum SignChangeOperation { add, edit, delete }

class SignChangeDraft {
  const SignChangeDraft({
    required this.operation,
    required this.latitude,
    required this.longitude,
    required this.typeCode,
    required this.valueRaw,
    required this.directionRaw,
    required this.note,
    this.targetSignId,
  });

  final SignChangeOperation operation;
  final double latitude, longitude;
  final int typeCode, valueRaw, directionRaw;
  final int? targetSignId;
  final String note;

  void validate() {
    if (!latitude.isFinite || latitude < -90 || latitude > 90 ||
        !longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError('Tọa độ GPS không hợp lệ');
    }
    if (typeCode < 0 || typeCode > 100000 ||
        valueRaw < 0 || valueRaw > 1000000 ||
        directionRaw < 0 || directionRaw > 360 && directionRaw != 255) {
      throw ArgumentError('Mã biển/giá trị/hướng không hợp lệ');
    }
    if (note.trim().isEmpty || note.trim().length > 500) {
      throw ArgumentError('Cần ghi chú báo cáo (1–500 ký tự)');
    }
    if (operation == SignChangeOperation.add && targetSignId != null) {
      throw ArgumentError('Báo cáo thêm mới không có sign_id gốc');
    }
    if (operation != SignChangeOperation.add && targetSignId == null) {
      throw ArgumentError('Sửa/xóa phải chỉ rõ sign_id gốc');
    }
  }
}

class SignChangeReport {
  const SignChangeReport({
    required this.id,
    required this.draft,
    required this.status,
    required this.expectedRevision,
    required this.createdAt,
    this.reviewedAt,
    this.reviewerNote,
  });

  final int id, expectedRevision;
  final SignChangeDraft draft;
  final String status, createdAt;
  final String? reviewedAt, reviewerNote;

  factory SignChangeReport.fromRow(Map<String, Object?> row) {
    return SignChangeReport(
      id: row['id'] as int,
      draft: SignChangeDraft(
        operation: SignChangeOperation.values.byName(row['operation'] as String),
        targetSignId: row['target_sign_id'] as int?,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        typeCode: row['sign_type_code'] as int,
        valueRaw: row['value_raw'] as int,
        directionRaw: row['direction_raw'] as int,
        note: row['note'] as String,
      ),
      status: row['status'] as String,
      expectedRevision: row['expected_revision'] as int,
      createdAt: row['created_at'] as String,
      reviewedAt: row['reviewed_at'] as String?,
      reviewerNote: row['reviewer_note'] as String?,
    );
  }
}

/// Effective local overlay, isolated from the immutable 151,228-row base DB.
/// A delete is a tombstone, never a destructive edit of the owner's source.
class ApprovedSignPatch {
  const ApprovedSignPatch({
    required this.signId,
    required this.latitude,
    required this.longitude,
    required this.typeCode,
    required this.valueRaw,
    required this.directionRaw,
    required this.deleted,
    required this.revision,
  });
  final int signId, typeCode, valueRaw, directionRaw, revision;
  final double latitude, longitude;
  final bool deleted;

  factory ApprovedSignPatch.fromRow(Map<String, Object?> row) =>
      ApprovedSignPatch(
        signId: row['sign_id'] as int,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        typeCode: row['sign_type_code'] as int,
        valueRaw: row['value_raw'] as int,
        directionRaw: row['direction_raw'] as int,
        deleted: (row['deleted'] as int) == 1,
        revision: row['revision'] as int,
      );

  TrafficSign toTrafficSign() => TrafficSign(
    signId: signId, latitude: latitude, longitude: longitude,
    signTypeCode: typeCode, valueRaw: valueRaw, directionRaw: directionRaw,
    speedKmhInferred: null, sourceDataset: 'local_owner_approved',
    verificationStatus: 'local_owner_approved_unverified_road',
  );

  bool visibleIn(SignViewport bounds, TrafficSignFilter filter) =>
      !deleted && bounds.isValid &&
      latitude >= bounds.south && latitude <= bounds.north &&
      longitude >= bounds.west && longitude <= bounds.east &&
      (!filter.speedOnly || typeCode == 1 && valueRaw > 0) &&
      (filter.typeCode == null || filter.typeCode == typeCode);

  SignMapItem toMapItem() => SignMapItem(
    signId: signId, longitude: longitude, latitude: latitude, count: 1,
    signTypeCode: typeCode, valueRaw: valueRaw,
  );
}

/// In a local QA build the current operator may explicitly review proposals.
/// No passwords, fake roles or remote approval are implied. In production
/// `TTX_LOCAL_APPROVAL_QA` defaults false: review is disabled until a
/// separate authenticated moderation backend is supplied.
const bool localApprovalQaEnabled =
    bool.fromEnvironment('TTX_LOCAL_APPROVAL_QA', defaultValue: false);

class SignReviewStore extends ChangeNotifier {
  SignReviewStore._();
  static final SignReviewStore instance = SignReviewStore._();

  Future<Database>? _database;
  int _revision = 0;
  int get revision => _revision;

  Future<Database> get _db => _database ??= _open();

  Future<Database> _open() async {
    final support = await getApplicationSupportDirectory();
    final filename = path.join(support.path, 'sign_moderation_v1.sqlite');
    return openDatabase(filename, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL CHECK(operation IN ('add','edit','delete')),
          status TEXT NOT NULL CHECK(status IN ('pending','approved','rejected')),
          target_sign_id INTEGER,
          latitude REAL NOT NULL, longitude REAL NOT NULL,
          sign_type_code INTEGER NOT NULL,
          value_raw INTEGER NOT NULL, direction_raw INTEGER NOT NULL,
          note TEXT NOT NULL,
          expected_revision INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          reviewed_at TEXT,
          reviewer_note TEXT
        )
      ''');
      await db.execute('CREATE INDEX reports_status_idx ON reports(status,id)');
      await db.execute('''
        CREATE TABLE approved_signs (
          sign_id INTEGER PRIMARY KEY,
          latitude REAL NOT NULL, longitude REAL NOT NULL,
          sign_type_code INTEGER NOT NULL,
          value_raw INTEGER NOT NULL, direction_raw INTEGER NOT NULL,
          deleted INTEGER NOT NULL CHECK(deleted IN (0,1)),
          revision INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE review_audit (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          action TEXT NOT NULL,
          at_utc TEXT NOT NULL,
          reviewer_note TEXT NOT NULL
        )
      ''');
    });
  }

  /// All proposals remain PENDING. No map mutation occurs on submission.
  Future<int> submit(SignChangeDraft draft) async {
    draft.validate();
    final db = await _db;
    final revision = draft.targetSignId == null ? 0
        : await _revisionOf(db, draft.targetSignId!);
    final reportId = await db.insert('reports', <String, Object?>{
      'operation': draft.operation.name,
      'status': 'pending',
      'target_sign_id': draft.targetSignId,
      'latitude': draft.latitude, 'longitude': draft.longitude,
      'sign_type_code': draft.typeCode,
      'value_raw': draft.valueRaw, 'direction_raw': draft.directionRaw,
      'note': draft.note.trim(), 'expected_revision': revision,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    _revision++;
    notifyListeners();
    return reportId;
  }

  static Future<int> _revisionOf(DatabaseExecutor db, int signId) async {
    final rows = await db.query('approved_signs', columns: ['revision'],
        where: 'sign_id = ?', whereArgs: [signId], limit: 1);
    return rows.isEmpty ? 0 : rows.first['revision'] as int;
  }

  Future<List<SignChangeReport>> reports({String? status}) async {
    final db = await _db;
    final rows = await db.query('reports',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'id DESC', limit: 500);
    return rows.map(SignChangeReport.fromRow).toList(growable: false);
  }

  Future<List<ApprovedSignPatch>> approved() async {
    final db = await _db;
    final rows = await db.query('approved_signs', orderBy: 'sign_id');
    return rows.map(ApprovedSignPatch.fromRow).toList(growable: false);
  }

  Future<ApprovedSignPatch?> approvedById(int id) async {
    final db = await _db;
    final rows = await db.query('approved_signs',
      where: 'sign_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : ApprovedSignPatch.fromRow(rows.first);
  }

  /// Explicit review can change the published overlay ONLY in QA mode.
  /// Pending/rejected reports are NEVER returned by approved().
  /// A true production workflow must enforce reviewer authentication on a
  /// trusted backend instead of trusting this device or a client-side flag.
  Future<void> review(int reportId, {
    required bool approve,
    required String reviewerNote,
    bool localQaAuthorized = localApprovalQaEnabled,
  }) async {
    if (!localQaAuthorized) {
      throw StateError('Phê duyệt cần máy chủ quản trị xác thực');
    }
    final note = reviewerNote.trim();
    if (note.isEmpty || note.length > 500) {
      throw ArgumentError('Cần ghi chú quyết định phê duyệt/từ chối');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query('reports', where: 'id = ?',
          whereArgs: [reportId], limit: 1);
      if (rows.isEmpty) throw StateError('Không tìm thấy báo cáo');
      final report = SignChangeReport.fromRow(rows.first);
      if (report.status != 'pending') {
        throw StateError('Báo cáo đã được xử lý');
      }
      if (approve) {
        final id = report.draft.operation == SignChangeOperation.add
            ? -report.id : report.draft.targetSignId!;
        final latest = await _revisionOf(txn, id);
        if (latest != report.expectedRevision) {
          throw StateError('Báo cáo đã cũ, dữ liệu biển đã thay đổi');
        }
        // Bound this local-only overlay before moving to a reviewed server
        // projection. Prevent huge SQL NOT IN lists on old Android SQLite.
        final rowsCount = await txn.rawQuery(
          'SELECT COUNT(*) AS n FROM approved_signs');
        if ((rowsCount.first['n'] as num).toInt() >= 750 &&
            latest == 0) {
          throw StateError('Đã đạt 750 thay đổi; cần đồng bộ quản trị');
        }
        await txn.insert('approved_signs', {
          'sign_id': id,
          'latitude': report.draft.latitude,
          'longitude': report.draft.longitude,
          'sign_type_code': report.draft.typeCode,
          'value_raw': report.draft.valueRaw,
          'direction_raw': report.draft.directionRaw,
          'deleted': report.draft.operation == SignChangeOperation.delete ? 1 : 0,
          'revision': report.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final status = approve ? 'approved' : 'rejected';
      await txn.update('reports', {
        'status': status, 'reviewed_at': now, 'reviewer_note': note,
      }, where: 'id = ? AND status = ?', whereArgs: [reportId, 'pending']);
      await txn.insert('review_audit', {
        'report_id': reportId, 'action': status,
        'at_utc': now, 'reviewer_note': note,
      });
    });
    _revision++;
    notifyListeners();
  }
}
