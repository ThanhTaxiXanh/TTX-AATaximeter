import 'dart:convert';

/// Presentation preferences. They never affect the taximeter engine.
class DashboardPreferences {
  const DashboardPreferences({
    this.welcome = 'Chúc quý khách thượng lộ bình an',
    this.thanks = 'Cảm ơn quý khách, chúc quý khách một ngày tràn đầy năng lượng',
    this.default3D = false,
    this.auto3DOnStart = true,
    this.darkMap = false,
    this.pitchDegrees = 60.0,
  });
  static const storageKey = 'ttx_dashboard_preferences_v1';
  final String welcome, thanks;
  final bool default3D, auto3DOnStart, darkMap;
  final double pitchDegrees;

  /// MapLibre pitch currently reaches 60 degrees, even when 70-80 is saved.
  double get renderedPitch => pitchDegrees.clamp(50.0, 60.0).toDouble();

  DashboardPreferences copyWith({
    String? welcome, String? thanks,
    bool? default3D, bool? auto3DOnStart, bool? darkMap,
    double? pitchDegrees,
  }) => DashboardPreferences(
    welcome: welcome ?? this.welcome,
    thanks: thanks ?? this.thanks,
    default3D: default3D ?? this.default3D,
    auto3DOnStart: auto3DOnStart ?? this.auto3DOnStart,
    darkMap: darkMap ?? this.darkMap,
    pitchDegrees: pitchDegrees ?? this.pitchDegrees,
  );

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'welcome': welcome, 'thanks': thanks,
    'default3D': default3D, 'auto3DOnStart': auto3DOnStart,
    'darkMap': darkMap, 'pitchDegrees': pitchDegrees,
  };
  String encode() => jsonEncode(toJson());

  factory DashboardPreferences.decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map || data['schema'] != 1) {
      throw const FormatException('Unsupported dashboard settings');
    }
    const defaults = DashboardPreferences();
    String phrase(Object? value, String fallback) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty || text.length > 180 ? fallback : text;
    }
    final rawPitch = data['pitchDegrees'];
    final pitch = rawPitch is num && rawPitch.toDouble().isFinite
        ? rawPitch.toDouble().clamp(50.0, 80.0).toDouble() : 60.0;
    return DashboardPreferences(
      welcome: phrase(data['welcome'], defaults.welcome),
      thanks: phrase(data['thanks'], defaults.thanks),
      default3D: data['default3D'] == true,
      auto3DOnStart: data['auto3DOnStart'] != false,
      darkMap: data['darkMap'] == true,
      pitchDegrees: pitch,
    );
  }
}
