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

/// Reveals the two actions instead of immediately dismissing the record.
class _SwipeTariffCard extends StatefulWidget {
  const _SwipeTariffCard({
    super.key, required this.profile, required this.selected,
    required this.onSelect, required this.onEdit, required this.onDelete,
  });

  final TariffProfile profile;
  final bool selected;
  final VoidCallback onSelect, onEdit, onDelete;

  @override
  State<_SwipeTariffCard> createState() => _SwipeTariffCardState();
}

class _SwipeTariffCardState extends State<_SwipeTariffCard> {
  bool _revealed = false;
  double _dragDistance = 0;

  Widget _action(String label, IconData icon, Color color, VoidCallback tap) =>
      Expanded(child: Material(color: color,
        child: InkWell(onTap: () {
          setState(() => _revealed = false);
          tap();
        }, child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ))),
      ));

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    clipBehavior: Clip.hardEdge,
    color: const Color(0xFF111829),
    child: LayoutBuilder(builder: (context, size) => Stack(children: [
      Positioned(top: 0, bottom: 0, right: 0,
        child: SizedBox(width: 144, child: Row(children: [
          _action('Sửa', Icons.edit_outlined,
            const Color(0xFF226CB8), widget.onEdit),
          _action('Xóa', Icons.delete_outline,
            const Color(0xFFC43E44), widget.onDelete),
        ]))),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _dragDistance = 0,
        onHorizontalDragUpdate: (details) =>
            _dragDistance += details.delta.dx,
        onHorizontalDragEnd: (_) {
          if (_dragDistance < -25) {
            setState(() => _revealed = true);
          } else if (_dragDistance > 25) {
            setState(() => _revealed = false);
          }
        },
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: Offset(_revealed ? -144 / size.maxWidth : 0, 0),
          child: ColoredBox(
            color: widget.selected
                ? const Color(0xFF363019) : const Color(0xFF111829),
            child: ListTile(
              onTap: () {
                if (_revealed) {
                  setState(() => _revealed = false);
                } else {
                  widget.onSelect();
                }
              },
              leading: Icon(widget.profile.configured
                  ? Icons.local_taxi : Icons.edit_note,
                color: widget.profile.configured
                  ? const Color(0xFFFFB800) : Colors.orangeAccent),
              title: Text(widget.profile.label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(widget.profile.configured
                  ? 'Mở cửa ${widget.profile.tariff!.baseFare.round()}đ'
                    ' • ${widget.profile.tariff!.effectiveFareTiers.length} bậc giá'
                  : 'Chưa nhập bảng giá — chạm để cấu hình'),
              trailing: widget.selected
                  ? const Icon(Icons.check_circle, color: Color(0xFF00DA75))
                  : null,
            ),
          ),
        ),
      ),
    ])),
  );
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

  Future<void> delete(TariffProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bảng giá?'),
        content: Text('Xóa "${profile.label}" khỏi danh sách bảng giá? '
          'Các hóa đơn và chuyến đi đã lưu sẽ không bị xóa.'
          '${profile.id == catalog.activeId ? ' Bảng giá khác sẽ được chọn để thay thế.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      setState(() => catalog = catalog.remove(profile.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bảng giá khỏi danh sách. Nhấn Lưu để áp dụng.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa: $e')));
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
      const Text('Chạm bảng giá để chọn. Vuốt một dòng từ phải sang trái '
        'để hiện Sửa và Xóa, rồi nhấn Lưu để áp dụng.',
        style: TextStyle(fontSize: 12, color: Colors.white70)),
      const SizedBox(height: 12),
      for (final profile in catalog.profiles)
        _SwipeTariffCard(
          key: ValueKey(profile.id),
          profile: profile,
          selected: profile.id == catalog.activeId,
          onSelect: () => select(profile),
          onEdit: () => edit(profile),
          onDelete: () => delete(profile),
        ),
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
