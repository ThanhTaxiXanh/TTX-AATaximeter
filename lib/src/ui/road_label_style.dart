import 'dart:convert';

/// Match actual OpenFreeMap Dark and Liberty street labels, not POI icons,
/// shields or transport arrows. Dark uses highway_name_* rather than
/// highway-name-*; older implementations failed to style the dark names.
List<String> roadNameSymbolLayerIds(String styleJson) {
  final root = jsonDecode(styleJson);
  if (root is! Map || root['layers'] is! List) {
    throw const FormatException('Invalid MapLibre style layers');
  }
  final ids = <String>[];
  for (final raw in root['layers'] as List) {
    if (raw is! Map || raw['type'] != 'symbol' ||
        raw['source-layer'] != 'transportation_name' ||
        raw['id'] is! String) continue;
    final id = raw['id'] as String;
    final name = id.toLowerCase();
    if ((name.contains('highway-name') ||
         name.contains('highway_name') ||
         name.contains('road-name') ||
         name.contains('road_name') ||
         name.contains('road labels') ||
         name.contains('street-name') ||
         name.contains('street_name')) &&
        !name.contains('shield') && !name.contains('arrow') &&
        !name.contains('ref') && !name.contains('sign')) {
      ids.add(id);
    }
  }
  return List<String>.unmodifiable(ids);
}

/// Dark native OpenFreeMap road paints are close to black (#181818).
/// These targeted colors brighten roads without modifying railway, tunnel
/// or building/POI geometry, and preserve existing zoom-based line widths.
Map<String, String> darkRoadLayerColors(String styleJson) {
  final root = jsonDecode(styleJson);
  if (root is! Map || root['layers'] is! List) {
    throw const FormatException('Invalid MapLibre style layers');
  }
  const palette = <String, String>{
    'highway_path': '#344A5C',
    'highway_minor': '#536E82',
    'highway_major_casing': '#2F4358',
    'highway_major_inner': '#819DB4',
    'highway_major_subtle': '#52758E',
    'highway_motorway_casing': '#47627B',
    'highway_motorway_inner': '#9EC8E8',
    'highway_motorway_subtle': '#6B8DA7',
  };
  final found = <String, String>{};
  for (final item in root['layers'] as List) {
    if (item is! Map || item['type'] != 'line' ||
        item['source-layer'] != 'transportation') continue;
    final id = item['id'];
    if (id is String && palette.containsKey(id)) {
      found[id] = palette[id]!;
    }
  }
  return found;
}
