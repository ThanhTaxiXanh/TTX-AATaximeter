/// Owner-supplied, provisional map-sign codebook V1 (2026-11-21).
///
/// Identifies the TYPE of a recorded point, not the legal validity or
/// present-day enforcement status of a physical road sign. Unknown codes
/// MUST remain unknown until the owner supplies their meanings.
class TrafficSignCodeInfo {
  const TrafficSignCodeInfo(this.name, this.mapLabel);
  final String name;
  final String mapLabel;
}

abstract final class TrafficSignCatalog {
  static const Map<int, TrafficSignCodeInfo> knownCodes = {
    1: TrafficSignCodeInfo('Biển báo tốc độ', 'TĐ'),
    2: TrafficSignCodeInfo('Vào khu dân cư', 'KDC'),
    3: TrafficSignCodeInfo('Hết khu dân cư', 'H.KDC'),
    4: TrafficSignCodeInfo('Camera giao thông', 'CAM'),
    5: TrafficSignCodeInfo('Cấm vượt', 'CV'),
    6: TrafficSignCodeInfo('Hết cấm vượt', 'HCV'),
    10: TrafficSignCodeInfo('Camera AI', 'AI'),
    32: TrafficSignCodeInfo('Đèn đỏ', 'ĐỎ'),
    36: TrafficSignCodeInfo('Cấm ô tô rẽ phải', 'C.P'),
    38: TrafficSignCodeInfo('Cấm rẽ trái và quay đầu', 'C.TQ'),
    40: TrafficSignCodeInfo('Cấm rẽ trái', 'C.T'),
    // 50 and 51 have the same provisional label; we do NOT invent which
    // means no stopping versus no parking.
    50: TrafficSignCodeInfo('Cấm dừng/đỗ', 'D/Đ'),
    51: TrafficSignCodeInfo('Cấm dừng/đỗ', 'D/Đ'),
  };

  static String description(int typeCode) =>
      knownCodes[typeCode]?.name ?? 'Chưa xác định (mã $typeCode)';

  static String filterTitle(int typeCode) =>
      '$typeCode · ${description(typeCode)}';

  /// Confirmed by dataset owner: positive value_raw on TYPE 1 records is
  /// the number printed on the speed sign at that coordinate.
  ///
  /// Some other types have nonzero raw values too, likely unmatched raw
  /// attributes. Do not reclassify such entries as speed signs.
  static int? postedSpeedNumber(int typeCode, int rawValue) =>
      typeCode == 1 && rawValue > 0 ? rawValue : null;

  /// Compact on-map label for a single point, not a legal speed alert.
  static String markerLabel(int? typeCode, int? rawValue,
      {int? legacyInferredSpeed}) {
    if (typeCode != null) {
      final number = postedSpeedNumber(typeCode, rawValue ?? 0);
      if (number != null) return '$number';
      final known = knownCodes[typeCode];
      if (known != null) return known.mapLabel;
      return '?';
    }
    return legacyInferredSpeed == null ? '?' : '~$legacyInferredSpeed';
  }
}
