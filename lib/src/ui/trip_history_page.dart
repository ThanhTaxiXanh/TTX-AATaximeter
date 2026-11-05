import 'package:flutter/material.dart';
import '../data/trip_repository.dart';
import '../domain/revenue_summary.dart';
import '../domain/trip_record.dart';
import '../payment/bank_book.dart';
import 'trip_detail_page.dart';
import 'trip_receipt_dialog.dart';

String _cash(num value) => value.round().toString()
  .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',') + ' đ';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({
    super.key, required this.repository,
    required this.bankBook, required this.onConfigureBank,
  });

  final TripRepository repository;
  final BankBook bankBook;
  final Future<BankBook?> Function() onConfigureBank;

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  List<TripRecord> _trips = [];
  RevenuePeriod _period = RevenuePeriod.today;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.repository.listTrips();
      if (mounted) setState(() {
        _trips = saved;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đọc được lịch sử: ' + error.toString())));
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
    await widget.repository.delete(record.id);
    await _load();
  }

  Future<void> _clear() async {
    if (!await _confirm('Xóa toàn bộ lịch sử?')) return;
    await widget.repository.clearAll();
    await _load();
  }

  Future<void> _openReceipt(TripRecord record) async {
    final selected = await showDialog<PaymentMethod>(
      context: context,
      builder: (ctx) => TripReceiptDialog(
        record: record,
        bankBook: widget.bankBook,
        onConfigureBank: widget.onConfigureBank,
      ),
    );
    if (selected == null || !mounted) return;
    await widget.repository.save(record.copyWith(paymentMethod: selected));
    await _load();
  }

  Widget _periodPicker() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF202023),
      borderRadius: BorderRadius.circular(22),
    ),
    padding: const EdgeInsets.all(3),
    child: Row(children: [
      for (final period in RevenuePeriod.values)
        Expanded(child: InkWell(
          onTap: () => setState(() => _period = period),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: _period == period
                  ? const Color(0xFF5B5B61) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              switch (period) {
                RevenuePeriod.today => 'Hôm nay',
                RevenuePeriod.week => 'Tuần này',
                RevenuePeriod.month => 'Tháng này',
                RevenuePeriod.all => 'Tất cả',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600),
            ),
          ),
        )),
    ]),
  );

  Widget _statCard(IconData icon, Color color, String value, String label) =>
      Container(
        height: 94,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF202023),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                style: const TextStyle(fontSize: 22,
                  color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60,
                fontSize: 11)),
          ],
        ),
      );

  Widget _tripTile(TripRecord trip) {
    final r = trip.receipt;
    final title = trip.fareProfileName.isNotEmpty
        ? trip.fareProfileName : 'Xe taxi';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF202023),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => TripDetailPage(
            record: trip,
            onReceipt: () => _openReceipt(trip),
          ),
        )).then((_) { if (mounted) _load(); }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 8, 15),
          child: Row(children: [
            const Icon(Icons.local_taxi,
              size: 37, color: Color(0xFF168FFF)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(formatTripDate(r.startedAt),
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            )),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_cash(r.totalFare), style: const TextStyle(
                color: Color(0xFF29CF63), fontSize: 17,
                fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(r.distanceKm.toStringAsFixed(1) + ' km • ' +
                    (r.durationSeconds ~/ 60).toString() + ' phút',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn chuyến đi',
              onSelected: (action) {
                if (action == 'delete') _delete(trip);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Xóa chuyến')),
              ],
              icon: const Icon(Icons.more_vert, size: 20,
                color: Colors.white54),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = RevenueSummary.calculate(
      _trips, period: _period, now: DateTime.now());
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090909),
        centerTitle: true,
        title: const Text('Doanh thu',
          style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Quản lý lịch sử',
            enabled: _trips.isNotEmpty,
            onSelected: (action) {
              if (action == 'clear') _clear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Xóa toàn bộ lịch sử')),
            ],
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 22),
            children: [
              _periodPicker(),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: _statCard(Icons.attach_money,
                  const Color(0xFF28CB60),
                  _cash(report.totalFare), 'Tổng doanh thu')),
                const SizedBox(width: 10),
                Expanded(child: _statCard(Icons.local_taxi,
                  const Color(0xFF168FFF),
                  report.tripCount.toString(), 'Tổng số chuyến')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _statCard(Icons.map_outlined,
                  const Color(0xFFFF9731),
                  report.totalDistanceKm.toStringAsFixed(1) + ' km',
                  'Tổng quãng đường')),
                const SizedBox(width: 10),
                Expanded(child: _statCard(Icons.bar_chart,
                  const Color(0xFFD13FEC),
                  _cash(report.averageFare), 'Tiền TB/chuyến')),
              ]),
              const SizedBox(height: 12),
              const Text('Lịch sử chuyến đi',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 13),
              if (report.trips.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Không có chuyến đi trong kỳ',
                    style: TextStyle(color: Colors.white60))),
                )
              else
                for (final trip in report.trips) _tripTile(trip),
              const SizedBox(height: 20),
            ],
          ),
        ),
      bottomNavigationBar: SafeArea(top: false, child: NavigationBar(
        height: 68,
        backgroundColor: const Color(0xFF202023),
        selectedIndex: 1,
        onDestinationSelected: (value) {
          if (value == 0) Navigator.pop(context);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined), label: 'Đồng hồ cước'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart, color: Color(0xFF168FFF)),
            label: 'Doanh thu'),
        ],
      )),
    );
  }
}
