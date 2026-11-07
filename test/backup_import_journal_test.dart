import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:ttx_aataximeter/src/data/backup_import_journal.dart';

void main() {
  const hashA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const hashB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const oldName = 'truoc_nhap_1793970000000000.ttxbackup';
  const newName = 'truoc_nhap_1793970000000001.ttxbackup';

  Future<void> safety(Directory support, String filename) async {
    final directory = Directory(
      path.join(support.path, 'ttx_pre_import_safety'));
    await directory.create(recursive: true);
    await File(path.join(directory.path, filename)).writeAsBytes([1, 2, 3]);
  }

  test('fresh journal is absent and completed state survives restart',
      () async {
    final support = await Directory.systemTemp.createTemp('ttx-journal-');
    try {
      expect(await BackupImportJournal.read(support), isNull);
      await safety(support, oldName);
      final entry = await BackupImportJournal.begin(
        support: support, archiveSha256: hashA,
        safetyCopyName: oldName, now: DateTime.utc(2026, 11, 6, 6));
      expect(entry.phase, BackupImportPhase.applying);
      expect((await BackupImportJournal.read(support))!.needsReview, true);
      final complete = await BackupImportJournal.transition(
        support: support, expected: entry,
        phase: BackupImportPhase.completed);
      expect(complete.needsReview, false);
      expect((await BackupImportJournal.read(support))!.phase,
        BackupImportPhase.completed);
      await safety(support, newName);
      final second = await BackupImportJournal.begin(
        support: support, archiveSha256: hashB, safetyCopyName: newName);
      expect(second.safetyCopyName, newName);
      expect(second.archiveSha256, hashB);
    } finally {
      await support.delete(recursive: true);
    }
  });

  test('interrupted operation rejects a different archive and keeps '
      'original safety copy across same-archive retries', () async {
    final support = await Directory.systemTemp.createTemp('ttx-retry-');
    try {
      await safety(support, oldName);
      await safety(support, newName);
      final first = await BackupImportJournal.begin(
        support: support, archiveSha256: hashA, safetyCopyName: oldName);
      await BackupImportJournal.transition(
        support: support, expected: first,
        phase: BackupImportPhase.needsReview);
      await expectLater(BackupImportJournal.begin(
        support: support, archiveSha256: hashB, safetyCopyName: newName),
        throwsStateError);
      final retried = await BackupImportJournal.begin(
        support: support, archiveSha256: hashA, safetyCopyName: newName);
      expect(retried.safetyCopyName, oldName);
      expect(retried.startedAtUtc, first.startedAtUtc);
      expect(retried.phase, BackupImportPhase.applying);
    } finally {
      await support.delete(recursive: true);
    }
  });

  test('missing safety copy aborts before publishing an import journal',
      () async {
    final support = await Directory.systemTemp.createTemp('ttx-missing-');
    try {
      await expectLater(BackupImportJournal.begin(
        support: support, archiveSha256: hashA, safetyCopyName: oldName),
        throwsFormatException);
      expect(await BackupImportJournal.read(support), isNull);
    } finally {
      await support.delete(recursive: true);
    }
  });

  test('invalid or corrupted journal fails closed and is never discarded',
      () async {
    final support = await Directory.systemTemp.createTemp('ttx-corrupt-');
    try {
      final file = File(path.join(support.path,
        BackupImportJournal.fileName));
      await file.writeAsString('{"schema":1,"archiveSha256":"bad"}');
      await expectLater(BackupImportJournal.read(support),
        throwsFormatException);
      await safety(support, oldName);
      await expectLater(BackupImportJournal.begin(
        support: support, archiveSha256: hashA, safetyCopyName: oldName),
        throwsFormatException);
      expect(await file.readAsString(),
        '{"schema":1,"archiveSha256":"bad"}');
    } finally {
      await support.delete(recursive: true);
    }
  });

  test('cannot falsely mark a completed journal as interrupted', () async {
    final support = await Directory.systemTemp.createTemp('ttx-completed-');
    try {
      await safety(support, oldName);
      final entry = await BackupImportJournal.begin(
        support: support, archiveSha256: hashA, safetyCopyName: oldName);
      await BackupImportJournal.transition(
        support: support, expected: entry,
        phase: BackupImportPhase.completed);
      await expectLater(BackupImportJournal.transition(
        support: support, expected: entry,
        phase: BackupImportPhase.needsReview), throwsStateError);
    } finally {
      await support.delete(recursive: true);
    }
  });
}
