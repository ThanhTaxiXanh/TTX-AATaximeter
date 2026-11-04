import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/tariff_catalog.dart';

void main() {
  test('Taxi Hương Giang starts unconfigured; no invented rates', () {
    final catalog = TariffCatalog.initial();
    expect(catalog.activeId, 'urban');
    expect(catalog.find('huong_giang')!.configured, false);
    expect(() => catalog.activate('huong_giang'), throwsStateError);
  });

  test('user supplied multi-tier profile survives storage and quick switch', () {
    final rate = TariffConfig.demo().copyWith(
      name: 'Taxi Hương Giang - do tài xế nhập',
      baseFare: 13000,
      baseDistanceKm: 0.8,
      fareTiers: const [
        FareTier(upToKm: 10, ratePerKm: 16000),
        FareTier(upToKm: 25, ratePerKm: 14500),
        FareTier(upToKm: null, ratePerKm: 12000),
      ],
    );
    final edited = TariffCatalog.initial().save(TariffProfile(
      id: 'huong_giang', label: 'Taxi Hương Giang',
      tariff: rate, verifiedByDriver: true,
    ));
    final chosen = TariffCatalog.decode(
      edited.activate('huong_giang').encode());
    expect(chosen.active.label, 'Taxi Hương Giang');
    expect(chosen.active.tariff!.distanceChargeForKm(26),
        closeTo(9.2 * 16000 + 15 * 14500 + 12000, .0001));
    expect(chosen.profiles.length, 2);
    expect(chosen.active.tariff!.fareTiers!.length, 3);
  });

  test('tier boundaries must be strictly increasing', () {
    final t = TariffConfig.demo().copyWith(fareTiers: const [
      FareTier(upToKm: 10, ratePerKm: 14000),
      FareTier(upToKm: 9, ratePerKm: 12000),
      FareTier(upToKm: null, ratePerKm: 10000),
    ]);
    expect(() => t.validate(), throwsArgumentError);
  });

  test('progressive pricing charges only each range, not entire trip', () {
    final tariff = TariffConfig.demo().copyWith(
      baseFare: 10000, baseDistanceKm: 1,
      fareTiers: const [
        FareTier(upToKm: 3, ratePerKm: 16000),
        FareTier(upToKm: 10, ratePerKm: 14000),
        FareTier(upToKm: null, ratePerKm: 12000),
      ],
    );
    tariff.validate();
    expect(tariff.distanceChargeForKm(.5), 0);
    expect(tariff.distanceChargeForKm(3), 2 * 16000);
    expect(tariff.distanceChargeForKm(5), 2 * 16000 + 2 * 14000);
    expect(tariff.distanceChargeForKm(11),
        2 * 16000 + 7 * 14000 + 12000);
  });
}
