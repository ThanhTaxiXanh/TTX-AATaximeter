import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/road_label_style.dart';

void main() {
  test('Liberty road names are selectable without shields or road arrows', () {
    final style = jsonEncode({
      'version': 8,
      'layers': [
        {
          'id': 'highway-name-path',
          'type': 'symbol',
          'source-layer': 'transportation_name',
          'layout': {'symbol-placement': 'line',
            'text-rotation-alignment': 'map'},
        },
        {
          'id': 'highway-name-minor',
          'type': 'symbol',
          'source-layer': 'transportation_name',
        },
        {
          'id': 'highway-name-major',
          'type': 'symbol',
          'source-layer': 'transportation_name',
        },
        {
          'id': 'highway-shield-non-us',
          'type': 'symbol',
          'source-layer': 'transportation_name',
        },
        {
          'id': 'road_one_way_arrow',
          'type': 'symbol',
          'source-layer': 'transportation',
        },
        {
          'id': 'poi-label',
          'type': 'symbol',
          'source-layer': 'poi',
        },
      ],
    });
    expect(roadNameSymbolLayerIds(style),
      ['highway-name-path', 'highway-name-minor', 'highway-name-major']);
  });

  test('Dark street-name layers are selected without non-label features', () {
    final style = jsonEncode({
      'layers': [
        {'id': 'highway_name_other', 'type': 'symbol',
          'source-layer': 'transportation_name'},
        {'id': 'highway_name_motorway', 'type': 'symbol',
          'source-layer': 'transportation_name'},
        {'id': 'street_name', 'type': 'line',
          'source-layer': 'transportation_name'},
        {'id': 'road_shield_us', 'type': 'symbol',
          'source-layer': 'transportation_name'},
      ],
    });
    expect(roadNameSymbolLayerIds(style),
      ['highway_name_other', 'highway_name_motorway']);
  });

  test('real OpenFreeMap Dark labels and road paints are selected', () {
    final style = jsonEncode({'layers': [
      {'id': 'background', 'type': 'background'},
      {'id': 'highway_name_other', 'type': 'symbol',
        'source-layer': 'transportation_name'},
      {'id': 'highway_name_motorway', 'type': 'symbol',
        'source-layer': 'transportation_name'},
      {'id': 'highway_minor', 'type': 'line',
        'source-layer': 'transportation'},
      {'id': 'highway_major_inner', 'type': 'line',
        'source-layer': 'transportation'},
      {'id': 'railway', 'type': 'line',
        'source-layer': 'transportation'},
      {'id': 'building', 'type': 'fill',
        'source-layer': 'building'},
      {'id': 'highway-shield-non-us', 'type': 'symbol',
        'source-layer': 'transportation_name'},
    ]});
    expect(roadNameSymbolLayerIds(style),
      ['highway_name_other', 'highway_name_motorway']);
    final colors = darkRoadLayerColors(style);
    expect(colors.keys, containsAll(['highway_minor', 'highway_major_inner']));
    expect(colors.containsKey('railway'), isFalse);
    expect(colors.containsKey('building'), isFalse);
    expect(colors['highway_minor'], isNot('#181818'));
  });

  test('navy day/night reference recolors real dark surfaces without '
      'altering POI symbols or navigation arrow', () {
    final style = jsonEncode({'layers': [
      {'id': 'background', 'type': 'background'},
      {'id': 'landuse_residential', 'type': 'fill',
        'source-layer': 'landuse'},
      {'id': 'water', 'type': 'fill', 'source-layer': 'water'},
      {'id': 'building', 'type': 'fill', 'source-layer': 'building'},
      {'id': 'highway_minor', 'type': 'line',
        'source-layer': 'transportation'},
      {'id': 'poi_label', 'type': 'symbol',
        'source-layer': 'poi'},
    ]});
    final surfaces = darkSurfaceLayerColors(style);
    expect(surfaces['landuse_residential'], '#1B2B49');
    expect(surfaces['building'], '#344461');
    expect(surfaces.containsKey('background'), false);
    expect(surfaces.containsKey('poi_label'), false);
    expect(darkRoadLayerColors(style)['highway_minor'], '#7E99B9');
  });

  test('unknown provider labels are left untouched, invalid style rejected',
      () {
    expect(roadNameSymbolLayerIds(
      jsonEncode({'layers': [
        {'id': 'park-label', 'type': 'symbol',
         'source-layer': 'park'},
      ]})), isEmpty);
    expect(() => roadNameSymbolLayerIds('{"layers":{}}'),
      throwsFormatException);
  });
}
