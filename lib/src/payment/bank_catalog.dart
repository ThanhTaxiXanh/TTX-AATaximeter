import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class VietQrBank {
  const VietQrBank({
    required this.bin, required this.code, required this.name,
    required this.shortName, required this.transferSupported,
  });
  final String bin, code, name, shortName;
  final bool transferSupported;
  factory VietQrBank.fromJson(Map<String, dynamic> json) {
    final result = VietQrBank(
      bin: json['bin']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['shortName']?.toString() ??
        json['short_name']?.toString() ?? '',
      transferSupported: json['transferSupported'] == 1,
    );
    if (!RegExp(r'^[0-9]{6}$').hasMatch(result.bin) ||
        result.code.isEmpty || result.shortName.isEmpty) {
      throw const FormatException('Ngân hàng / BIN không hợp lệ');
    }
    return result;
  }
}

class BankCatalog {
  const BankCatalog(this.banks);
  final List<VietQrBank> banks;
  List<VietQrBank> search(String text) {
    final query = text.trim().toLowerCase();
    return banks.where((bank) => bank.name.toLowerCase().contains(query) ||
      bank.shortName.toLowerCase().contains(query) ||
      bank.code.toLowerCase().contains(query) ||
      bank.bin.contains(query)).toList();
  }
  factory BankCatalog.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['code'] != '00' || decoded['data'] is! List) {
      throw const FormatException('Danh sách ngân hàng VietQR lỗi');
    }
    final parsed = (decoded['data'] as List).map((e) =>
      VietQrBank.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    if (parsed.length < 10 ||
        parsed.map((e) => e.bin).toSet().length != parsed.length) {
      throw const FormatException('Danh sách ngân hàng thiếu hoặc trùng BIN');
    }
    return BankCatalog(parsed);
  }

  /// Bundled full snapshot (76 BINs); update once/day when data is available.
  static Future<BankCatalog> load({bool refresh = true}) async {
    final asset = await rootBundle.loadString('assets/data/vietqr_banks.json');
    var catalog = BankCatalog.fromJson(asset);
    final dir = await getApplicationSupportDirectory();
    final cache = File(dir.path + '/vietqr_banks.json');
    if (await cache.exists()) {
      try { catalog = BankCatalog.fromJson(await cache.readAsString()); }
      catch (_) { /* Fallback bundled data. */ }
    }
    if (!refresh) return catalog;
    try {
      final age = await cache.exists()
        ? DateTime.now().difference(await cache.lastModified())
        : const Duration(days: 2);
      if (age < const Duration(days: 1)) return catalog;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      try {
        final request = await client.getUrl(
          Uri.parse('https://api.vietqr.io/v2/banks'));
        final response = await request.close()
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return catalog;
        final raw = await utf8.decoder.bind(response).join()
            .timeout(const Duration(seconds: 8));
        final latest = BankCatalog.fromJson(raw);
        if (latest.banks.length < 40) return catalog;
        await cache.writeAsString(raw, flush: true);
        return latest;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return catalog;
    }
  }
}
