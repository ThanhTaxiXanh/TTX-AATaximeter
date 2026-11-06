import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Persistent, privacy-minimal marker for a user-authorized additive import.
/// No automatic restore, deletion, replacement, or silent dismissal.
enum BackupImportPhase { applying, needsReview, completed }

class BackupImportJournalEntry {
  const BackupImportJournalEntry({
    required this.archiveSha256,
    required this.safetyCopyName,
    required this.startedAtUtc,
    required this.phase,
  });

  final String archiveSha256;
  final String safetyCopyName;
  final DateTime startedAtUtc;
  final BackupImportPhase phase;

  bool get needsReview => phase != BackupImportPhase.completed;

  Map<String, Object> toJson() => {
    'format': 'ttx-additive-import-journal',
    'schema': 1,
    'archiveSha256': archiveSha256,
    'safetyCopyName': safetyCopyName,
    'startedAtUtc': startedAtUtc.toIso8601String(),
    'phase': phase.name,
  };

  factory BackupImportJournalEntry.decode(String text) {
    final value = jsonDecode(text);
    if (value is! Map ||
        value['format'] != 'ttx-additive-import-journal' ||
        value['schema'] != 1 ||
        value['archiveSha256'] is! String ||
        value['safetyCopyName'] is! String ||
        value['startedAtUtc'] is! String ||
        value['phase'] is! String) {
      throw const FormatException('Nhật ký nhập không được hỗ trợ');
    }
    final digest = value['archiveSha256'] as String;
    final file = value['safetyCopyName'] as String;
    final time = DateTime.tryParse(value['startedAtUtc'] as String);
    final phaseName = value['phase'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        !RegExp(r'^truoc_nhap_[0-9]{12,20}\.ttxbackup$').hasMatch(file) ||
        time == null || !time.isUtc ||
        !BackupImportPhase.values.any((p) => p.name == phaseName)) {
      throw const FormatException('Nhật ký nhập có dữ liệu không hợp lệ');
    }
    return BackupImportJournalEntry(
      archiveSha256: digest,
      safetyCopyName: file,
      startedAtUtc: time,
      phase: BackupImportPhase.values.firstWhere(
        (p) => p.name == phaseName),
    );
  }

  BackupImportJournalEntry withPhase(BackupImportPhase next) =>
      BackupImportJournalEntry(
        archiveSha256: archiveSha256,
        safetyCopyName: safetyCopyName,
        startedAtUtc: startedAtUtc,
        phase: next,
      );
}

class BackupImportJournal {
  static const fileName = 'ttx_additive_import_journal_v1.json';
  static const _limit = 2048;

  static File _file(Directory support) =>
      File(path.join(support.path, fileName));

  static Future<BackupImportJournalEntry?> read(Directory support) async {
    final file = _file(support);
    final type = await FileSystemEntity.type(
      file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file ||
        await file.length() > _limit) {
      throw const FormatException('Nhật ký nhập không an toàn');
    }
    return BackupImportJournalEntry.decode(await file.readAsString());
  }

  /// Call AFTER validating/publishing a safety snapshot and immediately
  /// BEFORE making any live database/settings/logo changes.
  /// An unfinished operation may only retry the same archive digest.
  static Future<BackupImportJournalEntry> begin({
    required Directory support,
    required String archiveSha256,
    required String safetyCopyName,
    DateTime? now,
  }) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(archiveSha256) ||
        !RegExp(r'^truoc_nhap_[0-9]{12,20}\.ttxbackup$')
            .hasMatch(safetyCopyName)) {
      throw const FormatException('Mã hoặc tên bản dự phòng không hợp lệ');
    }
    final existing = await read(support);
    if (existing != null && existing.needsReview &&
        existing.archiveSha256 != archiveSha256) {
      throw StateError('Có lần nhập dở dang từ bản sao khác. '
          'Hãy kiểm tra và nhập lại đúng bản sao trước đó.');
    }
    final retainedName = existing != null && existing.needsReview
        ? existing.safetyCopyName : safetyCopyName;
    final safety = File(path.join(
      support.path, 'ttx_pre_import_safety', retainedName));
    if (await FileSystemEntity.type(safety.path, followLinks: false) !=
        FileSystemEntityType.file || await safety.length() == 0) {
      throw const FormatException('Thiếu bản dự phòng gốc trước khi nhập');
    }
    // Keep the ORIGINAL baseline during retry, not a newer snapshot that
    // might already contain some of the previously imported records.
    final entry = existing != null && existing.needsReview
        ? existing.withPhase(BackupImportPhase.applying)
        : BackupImportJournalEntry(
            archiveSha256: archiveSha256,
            safetyCopyName: safetyCopyName,
            startedAtUtc: (now ?? DateTime.now()).toUtc(),
            phase: BackupImportPhase.applying);
    await _publish(support, entry);
    return entry;
  }

  static Future<BackupImportJournalEntry> transition({
    required Directory support,
    required BackupImportJournalEntry expected,
    required BackupImportPhase phase,
  }) async {
    if (phase == BackupImportPhase.applying) {
      throw const FormatException('Không đặt lại trạng thái từ transition');
    }
    final current = await read(support);
    if (current == null ||
        current.archiveSha256 != expected.archiveSha256 ||
        current.safetyCopyName != expected.safetyCopyName ||
        !current.needsReview) {
      throw StateError('Trạng thái nhật ký nhập đã thay đổi');
    }
    final next = current.withPhase(phase);
    await _publish(support, next);
    return next;
  }

  static Future<void> _publish(
      Directory support, BackupImportJournalEntry value) async {
    await support.create(recursive: true);
    final destination = _file(support);
    if (await FileSystemEntity.type(destination.path,
        followLinks: false) == FileSystemEntityType.link) {
      throw const FormatException('Nhật ký nhập không an toàn');
    }
    final temp = File(destination.path + '.tmp');
    if (await FileSystemEntity.type(temp.path,
        followLinks: false) == FileSystemEntityType.link) {
      throw const FormatException('Tệp tạm nhật ký là đường dẫn liên kết');
    }
    final contents = jsonEncode(value.toJson());
    if (utf8.encode(contents).length > _limit) {
      throw const FormatException('Nhật ký nhập quá dung lượng cho phép');
    }
    try {
      await temp.writeAsString(contents, flush: true);
      BackupImportJournalEntry.decode(await temp.readAsString());
      // Atomic replacement of a short file on the same filesystem.
      await temp.rename(destination.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}
