import 'dart:convert';

enum VehicleCategory {
  fiveSeats('Xe 5 chỗ'),
  sevenSeats('Xe 7 chỗ'),
  legacySixteenSeats('Xe 16 chỗ');

  const VehicleCategory(this.label);
  final String label;

  static const selectable = [VehicleCategory.fiveSeats, VehicleCategory.sevenSeats];
  bool get isSelectable => this != VehicleCategory.legacySixteenSeats;
}

/// Data is stored locally. Schema 1 remains readable after upgrading.
class VehicleRegistration {
  VehicleRegistration({
    required this.category,
    required String plate,
    String brand = '',
  }) : plate = normalizePlate(plate),
       brand = normalizeBrand(brand) {
    if (!isValid) throw ArgumentError('Thông tin xe không hợp lệ');
  }

  final VehicleCategory category;
  final String plate;
  final String brand;

  static String normalizePlate(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  static String normalizeBrand(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Empty brand can be read from legacy schema, but must be filled when edited.
  bool get needsDetails => brand.isEmpty || !category.isSelectable;

  bool get isValid =>
      plate.length >= 5 && plate.length <= 16 &&
      RegExp(r'^[A-Z0-9][A-Z0-9.-]*$').hasMatch(plate) &&
      RegExp(r'\d').hasMatch(plate) && brand.length <= 60;

  Map<String, dynamic> toJson() => {
    'schema': 2,
    'category': category.name,
    'plate': plate,
    'brand': brand,
  };

  String encode() => jsonEncode(toJson());

  factory VehicleRegistration.decode(String raw) =>
      VehicleRegistration.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));

  factory VehicleRegistration.fromJson(Map<String, dynamic> map) {
    if (map['schema'] != 1 && map['schema'] != 2) {
      throw const FormatException('Unsupported vehicle registration schema');
    }
    final category = switch (map['category']?.toString()) {
      // Legacy "4 chỗ" means 4 passengers plus the driver.
      'fourSeats' || 'fiveSeats' => VehicleCategory.fiveSeats,
      'sevenSeats' => VehicleCategory.sevenSeats,
      // Preserve an old 16-seat choice until the driver explicitly changes it.
      'sixteenSeats' || 'legacySixteenSeats' =>
          VehicleCategory.legacySixteenSeats,
      _ => null,
    };
    if (category == null) {
      throw const FormatException('Unknown vehicle category');
    }
    return VehicleRegistration(
      category: category,
      plate: map['plate']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
    );
  }
}
