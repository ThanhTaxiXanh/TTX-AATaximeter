/// Product-level Vietnam-facing map labeling policy.
///
/// This is a presentation/content requirement, not a geographic legal
/// adjudication. The three coordinates are approximate *label anchors* for
/// island groups/sea, never survey boundaries or assertions about a point.
/// Third-party base tiles are not certified by this Dart layer.
abstract final class VietnamMapSovereignty {
  static const hoangSa = 'Hoàng Sa (Việt Nam)';
  static const truongSa = 'Trường Sa (Việt Nam)';
  static const bienDong = 'Biển Đông';

  // Keep ALL external base-map endpoints in this reviewed policy module.
  // They remain UNVERIFIED for external publication until actual tile,
  // vector-boundary, search, and screenshot review evidence is supplied.
  static const osmRasterTiles =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const openFreeMapDark =
      'https://tiles.openfreemap.org/styles/dark';
  static const openFreeMapLiberty =
      'https://tiles.openfreemap.org/styles/liberty';

  /// These anchors intentionally do NOT create territorial/border geometry.
  /// Approximate placement only: 3rd-party boundaries must be independently
  /// checked before a published map is certified.
  static const labels = <MapSovereigntyLabel>[
    MapSovereigntyLabel(hoangSa, 16.5, 112.3),
    MapSovereigntyLabel(truongSa, 9.6, 114.2),
    MapSovereigntyLabel(bienDong, 13.5, 114.9),
  ];

  static const _aliases = <(String, String)>[
    ('South China Sea', bienDong),
    ('South China sea', bienDong),
    ('Paracel Islands', hoangSa),
    ('Paracels', hoangSa),
    ('Xisha Islands', hoangSa),
    ('Xisha Qundao', hoangSa),
    ('西沙群岛', hoangSa),
    ('西沙群島', hoangSa),
    ('Spratly Islands', truongSa),
    ('Spratlys', truongSa),
    ('Nansha Islands', truongSa),
    ('Nansha Qundao', truongSa),
    ('南沙群岛', truongSa),
    ('南沙群島', truongSa),
    ('南中国海', bienDong),
    ('南中國海', bienDong),
  ];

  /// Explicitly refuse invalid or incompatible disputed boundary captions;
  /// text replacement is not enough to remove unapproved border geometry.
  static final RegExp _restrictedLines = RegExp(
    r'nine[ -]?dash line|ten[ -]?dash line|eleven[ -]?dash line|'
    r'9[ -]?dash line|10[ -]?dash line|11[ -]?dash line|'
    r'đường lưỡi bò|đường chín đoạn|đường 9 đoạn|'
    r'九段线|九段線|十段线|十段線',
    caseSensitive: false,
  );

  /// Call on any app-owned geographic search/label text BEFORE rendering.
  /// null means the name or claimed boundary text must NOT be published.
  /// Opaque raster/image tiles cannot be sanitized by this function.
  static String? approvedLabel(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty || _restrictedLines.hasMatch(text)) return null;
    for (final (alias, canonical) in _aliases) {
      // Whole words for Latin aliases; explicit strings for CJK aliases.
      final isLatin = RegExp(r'^[a-zA-Z ]+$').hasMatch(alias);
      final rule = isLatin
          ? RegExp('(?<![a-zA-Z])${RegExp.escape(alias)}(?![a-zA-Z])',
              caseSensitive: false)
          : RegExp(RegExp.escape(alias));
      text = text.replaceAll(rule, canonical);
    }
    return text;
  }

  static Map<String, dynamic> geoJsonLabels() => {
    'type': 'FeatureCollection',
    'features': [
      for (final point in labels) {
        'type': 'Feature',
        'properties': {
          'name': point.name,
          'anchor_only': true,
          'policy': 'TTX-VN-MAP-01',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [point.longitude, point.latitude],
        },
      },
    ],
  };
}

class MapSovereigntyLabel {
  const MapSovereigntyLabel(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude, longitude;
}
