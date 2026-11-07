import 'dart:convert';

class TollRate {
  const TollRate({required this.id, required this.label, required this.amount});
  final String id, label;
  final double amount;

  void validate() {
    if (id.trim().isEmpty || label.trim().isEmpty ||
        !amount.isFinite || amount <= 0 || amount > 2000000) {
      throw const FormatException('Tên trạm hoặc phí BOT không hợp lệ');
    }
  }
  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'amount': amount,
  };
  factory TollRate.fromJson(Map<String, dynamic> data) {
    final value = data['amount'];
    final result = TollRate(
      id: data['id']?.toString() ?? '',
      label: data['label']?.toString() ?? '',
      amount: value is num ? value.toDouble() : double.nan,
    );
    result.validate();
    return result;
  }
}

class TollSchedule {
  const TollSchedule({this.rates = const []});
  final List<TollRate> rates;

  void validate() {
    if (rates.length > 30) {
      throw const FormatException('Tối đa 30 trạm BOT đã lưu');
    }
    final ids = <String>{};
    for (final rate in rates) {
      rate.validate();
      if (!ids.add(rate.id)) {
        throw const FormatException('Trạm BOT bị trùng mã');
      }
    }
  }

  String encode() {
    validate();
    return jsonEncode({
      'schema': 1,
      'rates': rates.map((r) => r.toJson()).toList(),
    });
  }
  factory TollSchedule.decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map || data['schema'] != 1 || data['rates'] is! List) {
      throw const FormatException('Dữ liệu bảng giá BOT lỗi');
    }
    final schedule = TollSchedule(
      rates: (data['rates'] as List).map((r) =>
          TollRate.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false),
    );
    schedule.validate();
    return schedule;
  }
}
