import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ttx_aataximeter/src/traffic_signs/data/traffic_sign_repository.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';
import 'package:ttx_aataximeter/src/traffic_signs/moderation/sign_review_store.dart';

void main() {
  sqfliteFfiInit();
  late Database base, edits;
  late SignReviewStore review;
  late TrafficSignRepository repo;
  const view = SignViewport(west: 105, east: 107, south: 20, north: 22);
  const filter = TrafficSignFilter(enabled: true);

  setUp(() async {
    base = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
    edits = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
    await SignReviewStore.initializeSchema(edits);
    review = SignReviewStore.testing(edits);
    await base.execute('''
      CREATE TABLE traffic_signs(
        sign_id INTEGER PRIMARY KEY, longitude REAL, latitude REAL,
        sign_type_code INTEGER, value_raw INTEGER, direction_raw INTEGER,
        speed_kmh_inferred INTEGER, source_dataset TEXT,
        verification_status TEXT)
    ''');
    await base.execute('''
      CREATE VIRTUAL TABLE traffic_sign_rtree USING rtree(
        sign_id, min_longitude, max_longitude, min_latitude, max_latitude)
    ''');
    for (final (id, lon, lat, code, raw) in <(int, double, double, int, int)>[
      (0, 105.8, 21.0, 4, 0),
      (1, 106.1, 21.2, 1, 80),
    ]) {
      await base.insert('traffic_signs', {
        'sign_id': id, 'longitude': lon, 'latitude': lat,
        'sign_type_code': code, 'value_raw': raw,
        'direction_raw': 255,
        'speed_kmh_inferred': code == 1 ? raw : null,
        'source_dataset': 'owner_test_fixture',
        'verification_status': 'unverified',
      });
      await base.insert('traffic_sign_rtree', {
        'sign_id': id, 'min_longitude': lon, 'max_longitude': lon,
        'min_latitude': lat, 'max_latitude': lat,
      });
    }
    repo = TrafficSignRepository(base, moderation: review);
  });

  tearDown(() async {
    review.dispose();
    await base.close();
    await edits.close();
  });

  SignChangeDraft draft(SignChangeOperation action, {
    int? target, int type = 10, int raw = 0,
    double lon = 105.9, double lat = 21.1,
    String note = 'Tài xế ghi nhận biển/camera thực địa',
  }) => SignChangeDraft(
    operation: action, targetSignId: target,
    longitude: lon, latitude: lat,
    typeCode: type, valueRaw: raw, directionRaw: 255, note: note);

  test('add report is NOT visible until explicit owner QA approval', () async {
    final before = await repo.viewport(view, filter);
    expect(before.total, 2);
    final id = await review.submit(draft(SignChangeOperation.add));
    expect((await review.reports(status: 'pending')).single.id, id);
    expect((await review.approved()), isEmpty);
    expect((await repo.viewport(view, filter)).total, 2);

    await expectLater(review.review(id, approve: true,
        reviewerNote: 'Đồng ý'), throwsStateError); // no server/QA gate
    expect((await repo.viewport(view, filter)).total, 2);

    await review.review(id, approve: true,
        reviewerNote: 'Đã đối chiếu', localQaAuthorized: true);
    final after = await repo.viewport(view, filter);
    expect(after.total, 3);
    expect(after.items.any((p) => p.signId == -id), isTrue);
    expect((await repo.byId(-id))!.signTypeCode, 10);
    expect((await review.reports(status: 'approved')).length, 1);
    await expectLater(review.review(id, approve: true,
        reviewerNote: 'Không thể duyệt lại', localQaAuthorized: true),
        throwsStateError);
  });

  test('reject never changes map or the source database', () async {
    final id = await review.submit(draft(SignChangeOperation.add));
    await review.review(id, approve: false,
      reviewerNote: 'Không thấy biển tại tọa độ', localQaAuthorized: true);
    expect((await repo.viewport(view, filter)).total, 2);
    expect(await review.approved(), isEmpty);
    expect((await review.reports(status: 'rejected')).single.id, id);
    expect((await base.query('traffic_signs')).length, 2);
  });

  test('edit and delete update only approval overlay, preserve owner rows',
      () async {
    final editId = await review.submit(
      draft(SignChangeOperation.edit, target: 0, type: 32,
        lon: 105.82, lat: 21.02));
    expect((await repo.byId(0))!.signTypeCode, 4);
    await review.review(editId, approve: true,
      reviewerNote: 'Duyệt sửa loại camera sang đèn', localQaAuthorized: true);
    expect((await repo.byId(0))!.signTypeCode, 32);
    expect((await repo.viewport(view, filter)).total, 2);
    expect((await base.query('traffic_signs',
      where: 'sign_id = ?', whereArgs: [0])).single['sign_type_code'], 4);

    final deleteId = await review.submit(
      draft(SignChangeOperation.delete, target: 0));
    expect((await repo.viewport(view, filter)).total, 2);
    await review.review(deleteId, approve: true,
      reviewerNote: 'Đã tháo biển', localQaAuthorized: true);
    expect((await repo.viewport(view, filter)).total, 1);
    expect(await repo.byId(0), isNull);
    expect((await base.query('traffic_signs')).length, 2);
    expect((await edits.query('review_audit')).length, 2);
  });

  test('competing edits cannot overwrite an approved newer revision', () async {
    final first = await review.submit(
      draft(SignChangeOperation.edit, target: 1, type: 1, raw: 60));
    final stale = await review.submit(
      draft(SignChangeOperation.delete, target: 1));
    await review.review(first, approve: true,
      reviewerNote: 'Duyệt cập nhật', localQaAuthorized: true);
    await expectLater(review.review(stale, approve: true,
      reviewerNote: 'Báo cáo cũ', localQaAuthorized: true), throwsStateError);
    expect((await repo.byId(1))!.valueRaw, 60);
    expect((await review.reports(status: 'pending')).length, 1);
  });

  test('report validation rejects invalid coordinates and empty reasons', () {
    expect(() => draft(SignChangeOperation.add, lon: 200).validate(),
      throwsArgumentError);
    expect(() => draft(SignChangeOperation.add, note: '').validate(),
      throwsArgumentError);
    expect(() => draft(SignChangeOperation.edit).validate(),
      throwsArgumentError);
  });

  test('approved speed-only view filters raw speed signs not cameras',
      () async {
    final addSpeed = await review.submit(
      draft(SignChangeOperation.add, type: 1, raw: 70));
    await review.review(addSpeed, approve: true,
      reviewerNote: 'Duyệt dữ liệu thử', localQaAuthorized: true);
    final addCamera = await review.submit(
      draft(SignChangeOperation.add, type: 4, raw: 80));
    await review.review(addCamera, approve: true,
      reviewerNote: 'Duyệt dữ liệu thử', localQaAuthorized: true);
    final speed = await repo.viewport(view,
      const TrafficSignFilter(enabled: true, speedOnly: true));
    expect(speed.total, 2); // Original speed 80 plus new speed 70.
    expect(speed.items.any((p) => p.signId == -addCamera), isFalse);
    expect(speed.items.any((p) => p.signId == -addSpeed), isTrue);
  });
}
