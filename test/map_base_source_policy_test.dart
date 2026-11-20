import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/map_base_source_policy.dart';

void main() {
  test('2D map source cycles without unsupported offline tile download', () {
    var source = Map2DBaseSource.raster;
    expect(source.fetchesRasterTiles, isTrue);
    expect(source.usesVectorStyle, isFalse);
    source = source.next;
    expect(source, Map2DBaseSource.vector);
    expect(source.usesVectorStyle, isTrue);
    source = source.next;
    expect(source, Map2DBaseSource.offlineSigns);
    expect(source.referenceOnly, isTrue);
    expect(source.fetchesRasterTiles, isFalse);
    expect(source.usesVectorStyle, isFalse);
    expect(source.sourceDescription, contains('không có bản đồ nền'));
    expect(source.next, Map2DBaseSource.raster);
  });

  test('offline source is never described as a road basemap', () {
    const source = Map2DBaseSource.offlineSigns;
    expect(source.sourceDescription, contains('Chỉ GPS và biển báo'));
    expect(source.sourceDescription, isNot(contains('bản đồ ngoại tuyến')));
  });
}
