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
