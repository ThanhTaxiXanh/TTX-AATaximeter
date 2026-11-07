import 'package:flutter/material.dart';
import '../domain/toll_schedule.dart';

String _fmt(num n) => n.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.',
) + ' ₫';

class TollScheduleDialog extends StatefulWidget {
  const TollScheduleDialog({super.key, required this.initial});
  final TollSchedule initial;
  @override
  State<TollScheduleDialog> createState() => _TollScheduleDialogState();
}

class _TollScheduleDialogState extends State<TollScheduleDialog> {
  late List<TollRate> _rates = List.of(widget.initial.rates);

  Future<void> _addOrEdit({TollRate? existing}) async {
    final name = TextEditingController(text: existing?.label ?? '');
    final fee = TextEditingController(text:
        existing == null ? '' : existing.amount.round().toString());
    final result = await showDialog<TollRate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'Thêm biểu giá trạm BOT' : 'Sửa giá trạm BOT'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name, maxLength: 70,
            decoration: const InputDecoration(
              labelText: 'Tên trạm thu phí',
              hintText: 'VD: Trạm thu phí A')),
          TextField(
            controller: fee, keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tiền một lượt (₫)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                  fee.text.trim().replaceAll('.', ''));
              if (name.text.trim().isEmpty ||
                  amount == null || !amount.isFinite ||
                  amount <= 0 || amount > 2000000) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Nhập tên trạm và phí trong 1–2.000.000 ₫')));
                return;
              }
              Navigator.pop(ctx, TollRate(
                id: existing?.id ??
                    'bot_' + DateTime.now().microsecondsSinceEpoch.toString(),
                label: name.text.trim(), amount: amount,
              ));
            },
            child: const Text('Lưu giá BOT'),
          ),
        ],
      ),
    );
    name.dispose();
    fee.dispose();
    if (!mounted || result == null) return;
    setState(() {
      if (existing == null) {
        if (_rates.length < 30) _rates.add(result);
      } else {
        _rates = _rates.map((r) =>
            r.id == existing.id ? result : r).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('CẤU HÌNH BIỂU GIÁ BOT'),
    content: SizedBox(width: 480, child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Lưu tên trạm và phí một lượt. Giá này chỉ cộng '
            'vào chuyến khi bạn chọn trạm, không tự thu theo GPS.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 10),
          if (_rates.isEmpty)
            const Text('Chưa lưu trạm thu phí nào.'),
          for (final rate in _rates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(rate.label,
                maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(_fmt(rate.amount)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Sửa phí BOT',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _addOrEdit(existing: rate)),
                IconButton(
                  tooltip: 'Xóa trạm',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() =>
                      _rates.removeWhere((r) => r.id == rate.id))),
              ]),
            ),
          OutlinedButton.icon(
            onPressed: _rates.length < 30 ? () => _addOrEdit() : null,
            icon: const Icon(Icons.add), label: const Text('Thêm trạm BOT')),
        ]),
      )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Hủy')),
      FilledButton.icon(
        icon: const Icon(Icons.save),
        label: const Text('Lưu bảng giá BOT'),
        onPressed: () {
          final schedule = TollSchedule(rates: List.unmodifiable(_rates));
          try {
            schedule.validate();
            Navigator.pop(context, schedule);
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Giá BOT không hợp lệ: ' + error.toString())));
          }
        },
      ),
    ],
  );
}
