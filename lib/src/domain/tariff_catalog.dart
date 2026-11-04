import 'dart:convert';
import '../core/taximeter_engine.dart';
import '../data/tariff_codec.dart';

/// Taxi companies are local user-managed profiles, never inferred fares.
class TariffProfile {
  const TariffProfile({
    required this.id,
    required this.label,
    required this.tariff,
    this.verifiedByDriver = false,
  });

  final String id, label;
  final TariffConfig? tariff;
  final bool verifiedByDriver;

  bool get configured => tariff != null && verifiedByDriver &&
      tariff!.baseFare > 0 &&
      tariff!.effectiveFareTiers.every((tier) => tier.ratePerKm > 0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'verifiedByDriver': verifiedByDriver,
    'tariff': tariff == null ? null : jsonDecode(TariffCodec.encode(tariff!)),
  };

  factory TariffProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['tariff'];
    return TariffProfile(
      id: json['id'] as String,
      label: json['label'] as String,
      tariff: raw is Map
          ? TariffCodec.decode(jsonEncode(raw))
          : null,
      verifiedByDriver: json['verifiedByDriver'] == true,
    );
  }
}

class TariffCatalog {
  const TariffCatalog({
    required this.profiles, required this.activeId,
  });

  final List<TariffProfile> profiles;
  final String activeId;

  factory TariffCatalog.initial({TariffConfig? existing}) {
    final demo = existing ?? TariffConfig.demo();
    return TariffCatalog(
      activeId: 'urban',
      profiles: [
        TariffProfile(
          id: 'urban', label: demo.name,
          tariff: demo, verifiedByDriver: true,
        ),
        const TariffProfile(
          id: 'huong_giang',
          label: 'Taxi Hương Giang',
          tariff: null,
          verifiedByDriver: false,
        ),
      ],
    );
  }

  TariffProfile get active =>
      profiles.firstWhere((p) => p.id == activeId);

  TariffProfile? find(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  void validate() {
    if (profiles.isEmpty || profiles.length > 16) {
      throw const FormatException('Số lượng biểu giá không hợp lệ');
    }
    final ids = <String>{};
    for (final p in profiles) {
      if (!ids.add(p.id) || p.id.isEmpty || p.label.trim().isEmpty) {
        throw const FormatException('Tên/mã biểu giá trống hoặc trùng');
      }
      p.tariff?.validate();
    }
    if (find(activeId)?.configured != true) {
      throw const FormatException('Biểu giá đang chọn chưa cấu hình');
    }
  }

  TariffCatalog save(TariffProfile update) {
    update.tariff?.validate();
    final existing = find(update.id);
    if (existing == null && profiles.length >= 16) {
      throw StateError('Tối đa 16 bảng giá');
    }
    final next = <TariffProfile>[
      for (final p in profiles)
        if (p.id == update.id) update else p,
      if (existing == null) update,
    ];
    final catalog = TariffCatalog(profiles: next, activeId: activeId);
    catalog.validate();
    return catalog;
  }

  TariffCatalog activate(String id) {
    final chosen = find(id);
    if (chosen?.configured != true) {
      throw StateError('Biểu giá chưa được tài xế cấu hình');
    }
    final next = TariffCatalog(profiles: profiles, activeId: id);
    next.validate();
    return next;
  }

  String encode() {
    validate();
    return jsonEncode({
      'schema': 1,
      'activeId': activeId,
      'profiles': profiles.map((p) => p.toJson()).toList(),
    });
  }

  factory TariffCatalog.decode(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map || raw['schema'] != 1 ||
        raw['profiles'] is! List) {
      throw const FormatException('Bản ghi biểu giá không hợp lệ');
    }
    final parsed = TariffCatalog(
      activeId: raw['activeId'] as String,
      profiles: (raw['profiles'] as List)
          .map((e) => TariffProfile.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    parsed.validate();
    return parsed;
  }
}
