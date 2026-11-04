import 'dart:convert';

enum VehicleCategory {
  fourSeats('Xe 4 Chỗ'),
  sevenSeats('Xe 7 Chỗ'),
  sixteenSeats('Xe 16 Chỗ');

  const VehicleCategory(this.label);
  final String label;
}

/// Driver-entered, local-only vehicle registration (no network submission).
class VehicleRegistration {
  VehicleRegistration({
    required this.category,
    required String plate,
  }) : plate = normalizePlate(plate) {
    if (!isValid) throw ArgumentError('Biển số xe không hợp lệ');
  }

  final VehicleCategory category;
  final String plate;

  static String normalizePlate(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// Accept Vietnamese-style plates without claiming legal validation.
  /// Plate formats vary by vehicle class/province and change over time.
  bool get isValid =>
      plate.length >= 5 &&
      plate.length <= 16 &&
      RegExp(r'^[A-Z0-9][A-Z0-9.-]*$').hasMatch(plate) &&
      RegExp(r'\d').hasMatch(plate);

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'category': category.name,
    'plate': plate,
  };

  String encode() => jsonEncode(toJson());

  factory VehicleRegistration.decode(String raw) =>
      VehicleRegistration.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));

  factory VehicleRegistration.fromJson(Map<String, dynamic> map) {
    if (map['schema'] != 1) {
      throw const FormatException('Unsupported vehicle registration schema');
    }
    final kind = map['category']?.toString();
    final category = VehicleCategory.values
        .where((v) => v.name == kind)
        .firstOrNull;
    if (category == null) {
      throw const FormatException('Unknown vehicle category');
    }
    return VehicleRegistration(
      category: category,
      plate: map['plate']?.toString() ?? '',
    );
  }
}
