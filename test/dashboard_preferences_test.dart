import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';

void main() {
  test('2D, auto 3D on trip, and light map are defaults', () {
    const p = DashboardPreferences();
    expect(p.default3D, false);
    expect(p.auto3DOnStart, true);
    expect(p.darkMap, false);
    expect(p.showCurrentRoadName, true);
    expect(p.carHudMirror, false);
    expect(p.renderedPitch, 60);
  });
  test('custom messages and presentation persist', () {
    final p = const DashboardPreferences().copyWith(
      welcome: 'Xin chào', thanks: 'Xin cảm ơn',
      darkMap: true, default3D: true, auto3DOnStart: false,
      pitchDegrees: 75, showCurrentRoadName: false,
      carHudMirror: true);
    final restored = DashboardPreferences.decode(p.encode());
    expect(restored.welcome, 'Xin chào');
    expect(restored.thanks, 'Xin cảm ơn');
    expect(restored.darkMap, true);
    expect(restored.carHudMirror, true);
    expect(restored.showCurrentRoadName, false);
    expect(restored.default3D, true);
    expect(restored.auto3DOnStart, false);
    expect(restored.pitchDegrees, 75);
    expect(restored.renderedPitch, 60);
  });
  test('bad values fallback safely', () {
    final p = DashboardPreferences.decode(
      '{"schema":1,"welcome":"","thanks":"","pitchDegrees":999}');
    expect(p.pitchDegrees, 80);
    expect(p.welcome, isNotEmpty);
    // Older saved settings have no road-name key: it must default to on.
    expect(p.showCurrentRoadName, true);
    expect(p.carHudMirror, false);
    expect(() => DashboardPreferences.decode('{"schema":3}'),
      throwsFormatException);
  });
}
