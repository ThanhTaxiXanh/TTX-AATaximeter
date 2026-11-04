import 'package:flutter/material.dart';
import '../data/trip_repository.dart';
import '../domain/trip_record.dart';
import 'trip_receipt_dialog.dart';

String _cash(num n) => n.round().toString()
  .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({
    super.key, required this.repository, required this.onQr,
  });
  final TripRepository repository;
  final Future<void> Function(int amountVnd) onQr;

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  List<TripRecord> _trips = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final result = await widget.repository.listTrips();
      if (mounted) setState(() { _trips = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đọc được lịch sử: ' + e.toString())));
    }
  }

  Future<bool> _confirm(String title) async => await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text('Thao tác này không thể hoàn tác.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xóa')),
      ],
    ),
  ) ?? false;

  Future<void> _delete(TripRecord record) async {
    if (!await _confirm('Xóa chuyến đã chọn?')) return;
    try { await widget.repository.delete(record.id); await _load(); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa chuyến: ' + e.toString())));
    }
  }

  Future<void> _clear() async {
    if (!await _confirm('Xóa toàn bộ lịch sử?')) return;
    try { await widget.repository.clearAll(); await _load(); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa lịch sử: ' + e.toString())));
    }
  }

  Future<void> _openReceipt(TripRecord r) async {
    final selected = await showDialog<PaymentMethod>(
      context: context, builder: (ctx) => TripReceiptDialog(
        record: r,
        onQr: () => widget.onQr(r.receipt.totalFare.round()),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await widget.repository.save(r.copyWith(paymentMethod: selected));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu phương thức: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _trips.fold<double>(0,
      (v, r) => v + r.receipt.totalFare);
    final km = _trips.fold<double>(0,
      (v, r) => v + r.receipt.distanceKm);
    return Scaffold(
      appBar: AppBar(
        title: const Text('LỊCH SỬ CHUYẾN ĐI'),
        actions: [
          IconButton(onPressed: _trips.isEmpty ? null : _clear,
            tooltip: 'Xóa toàn bộ', icon: const Icon(Icons.delete_sweep)),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            Padding(padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(label: Text('Số chuyến: ' + _trips.length.toString())),
                Chip(label: Text('Doanh thu: ' + _cash(total))),
                Chip(label: Text('Tổng: ' + km.toStringAsFixed(2) + ' km')),
              ]),
            ),
            Expanded(child: _trips.isEmpty
              ? const Center(child: Text('Chưa có chuyến đi'))
              : ListView.builder(
                  itemCount: _trips.length,
                  itemBuilder: (ctx, i) {
                    final r = _trips[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                      child: ListTile(
                        leading: const Icon(Icons.local_taxi,
                          color: Color(0xFF00D8F0)),
                        title: Text(_cash(r.receipt.totalFare),
                          style: const TextStyle(
                            color: Color(0xFFFFB800),
                            fontWeight: FontWeight.bold)),
                        subtitle: Text(r.receipt.startedAt.toLocal()
                            .toString().substring(0, 16) +
                          ' • ' +
                          r.receipt.distanceKm.toStringAsFixed(2) +
                          ' km\n' +
                          (r.pickup.isEmpty ? 'Không ghi điểm đón'
                            : r.pickup) +
                          ' → ' +
                          (r.dropoff.isEmpty ? 'Không ghi điểm trả'
                            : r.dropoff)),
                        isThreeLine: true,
                        onTap: () => _openReceipt(r),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(r)),
                      ),
                    );
                  },
                )),
          ]),
    );
  }
}
