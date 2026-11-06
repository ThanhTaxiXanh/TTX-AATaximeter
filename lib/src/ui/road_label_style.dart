import 'dart:convert';

/// OpenFreeMap Liberty / Dark use symbol layers from the
/// "transportation_name" vector source layer for street and road names.
/// Restrict changes to those labels: road shields, one-way arrows and
/// business icons must keep their original map-oriented styling.
///
/// The returned IDs can be passed once per style load to
/// MapLibreMapController.setLayerProperties with viewport-aligned text.
List<String> roadNameSymbolLayerIds(String styleJson) {
  final parsed = jsonDecode(styleJson);
  if (parsed is! Map || parsed['layers'] is! List) {
    throw const FormatException('Invalid MapLibre style layers');
  }
  final ids = <String>[];
  for (final raw in parsed['layers'] as List) {
    if (raw is! Map || raw['type'] != 'symbol' ||
        raw['source-layer'] != 'transportation_name' ||
        raw['id'] is! String) continue;
    final id = raw['id'] as String;
    final name = id.toLowerCase();
    if ((name.contains('highway-name') ||
         name.contains('highway_name') ||
         name.contains('road-name') ||
         name.contains('road_name') ||
         name.contains('street-name') ||
         name.contains('street_name')) &&
        !name.contains('shield') && !name.contains('ref')) {
      ids.add(id);
    }
  }
  return List<String>.unmodifiable(ids);
}
