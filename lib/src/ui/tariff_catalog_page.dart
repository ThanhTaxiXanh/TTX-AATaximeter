import 'package:flutter/material.dart';
import '../core/taximeter_engine.dart';
import '../domain/tariff_catalog.dart';
import 'tariff_settings_dialog.dart';

class TariffCatalogPage extends StatefulWidget {
  const TariffCatalogPage({super.key, required this.initial});
  final TariffCatalog initial;

  @override
  State<TariffCatalogPage> createState() => _TariffCatalogPageState();
}

class _TariffCatalogPageState extends State<TariffCatalogPage> {
  late TariffCatalog catalog = widget.initial;

  Future<void> edit(TariffProfile profile) async {
    final source = profile.tariff ??
        TariffConfig.demo().copyWith(
          name: profile.label,
          baseFare: 0,
          perKmRate: 0,
          longDistancePerKmRate: 0,
          waitingFeePerHour: 0,
          fareTiers: const [
            FareTier(upToKm: null, ratePerKm: 0),
          ],
        );
    final config = await showDialog<TariffConfig>(
      context: context,
      builder: (ctx) => TariffSettingsDialog(
        current: source, companyLabel: profile.label,
      ),
    );
    if (!mounted || config == null) return;
    try {
      setState(() => catalog = catalog.save(TariffProfile(
        id: profile.id,
        label: profile.id == 'huong_giang'
            ? 'Taxi Hương Giang' : config.name,
        tariff: config, verifiedByDriver: true,
      )));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cấu hình. Chạm tên để sử dụng.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được: ' + e.toString())));
    }
  }

  Future<void> add() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm bảng giá'),
        content: TextField(controller: controller, maxLength: 72,
          decoration: const InputDecoration(
            labelText: 'Tên hãng / bảng giá')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy')),
          FilledButton(onPressed: () =>
            Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tiếp tục')),
        ]),
    );
    controller.dispose();
    if (!mounted || name == null || name.isEmpty) return;
    await edit(TariffProfile(
      id: 'custom_' + DateTime.now().microsecondsSinceEpoch.toString(),
      label: name, tariff: null,
    ));
  }

  void select(TariffProfile profile) {
    if (!profile.configured) {
      edit(profile);
      return;
    }
    try {
      Navigator.pop(context, catalog.activate(profile.id));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chưa thể sử dụng: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CÁC BẢNG GIÁ TAXI'),
      actions: [
        IconButton(onPressed: add, icon: const Icon(Icons.add_circle),
          tooltip: 'Thêm biểu giá'),
        TextButton(onPressed: () => Navigator.pop(context, catalog),
          child: const Text('Lưu')),
      ]),
    body: ListView(padding: const EdgeInsets.all(12), children: [
      const Text('Chạm hãng taxi để chọn nhanh. Chạm biểu tượng bút '
        'để sửa bảng giá theo các bậc km.',
        style: TextStyle(fontSize: 12, color: Colors.white70)),
      const SizedBox(height: 12),
      for (final profile in catalog.profiles)
        Card(color: profile.id == catalog.activeId
          ? const Color(0xFF363019) : const Color(0xFF111829),
          child: ListTile(
            onTap: () => select(profile),
            leading: Icon(profile.configured
              ? Icons.local_taxi : Icons.edit_note,
              color: profile.configured
                ? const Color(0xFFFFB800) : Colors.orangeAccent),
            title: Text(profile.label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(profile.configured
                ? 'Mở cửa ' +
                    profile.tariff!.baseFare.round().toString() +
                    'đ • ' +
                    profile.tariff!.effectiveFareTiers.length.toString() +
                    ' bậc giá'
                : 'Chưa nhập bảng giá — chạm để cấu hình'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (profile.id == catalog.activeId)
                const Icon(Icons.check_circle,
                  color: Color(0xFF00DA75)),
              IconButton(onPressed: () => edit(profile),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Chỉnh mức giá'),
            ]),
          )),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('THÊM HÃNG / BIỂU GIÁ')),
      const SizedBox(height: 12),
      const Text('Taxi Hương Giang chưa có bảng giá mặc định. '
        'Hãy nhập giá mở cửa, các mốc km và đơn giá theo thông tin '
        'được xác nhận trước khi chọn.',
        style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
    ]),
  );
}
