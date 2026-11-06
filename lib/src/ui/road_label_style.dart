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
    'highway_path': '#647D9D',
    'highway_minor': '#7E99B9',
    'highway_major_casing': '#324666',
    'highway_major_inner': '#91A9C9',
    'highway_major_subtle': '#667E9F',
    'highway_motorway_casing': '#354F71',
    'highway_motorway_inner': '#B1C6DE',
    'highway_motorway_subtle': '#8AA6C7',
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

 /// Road fills and landscape colors tuned to the user's deep-navy
 /// reference screenshot. Only exact native Dark layer IDs are touched.
Map<String, String> darkSurfaceLayerColors(String styleJson) {
  final root = jsonDecode(styleJson);
  if (root is! Map || root['layers'] is! List) {
    throw const FormatException('Invalid MapLibre style layers');
  }
  const palette = <String, String>{
    'water': '#122A4B',
    'landcover_ice_shelf': '#1C2C4A',
    'landcover_glacier': '#202E4A',
    'landuse_residential': '#1B2B49',
    'landcover_wood': '#223956',
    'landuse_park': '#263A55',
    'building': '#344461',
    'road_area_pier': '#263958',
    'aeroway-area': '#22324F',
  };
  final found = <String, String>{};
  for (final item in root['layers'] as List) {
    if (item is! Map || item['type'] != 'fill') continue;
    final id = item['id'];
    if (id is String && palette.containsKey(id)) {
      found[id] = palette[id]!;
    }
  }
  return found;
}
