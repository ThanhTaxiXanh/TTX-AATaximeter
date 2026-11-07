import 'package:flutter/material.dart';
import '../data/trip_repository.dart';
import '../domain/revenue_summary.dart';
import '../domain/trip_record.dart';
import '../payment/bank_book.dart';
import 'trip_detail_page.dart';
import 'trip_receipt_dialog.dart';
import 'driver_pro_design.dart';

String _cash(num value) => value.round().toString()
  .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

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
  TripHistoryStats _stats = const TripHistoryStats(
    tripCount: 0, totalFare: 0, totalDistanceKm: 0);
  RevenuePeriod _period = RevenuePeriod.today;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextRawOffset = 0;
  int _requestGeneration = 0;

  static const _pageSize = 25;

  /// Automatically skip hidden zero/zero/zero test receipts when the next
  /// physical SQLite page contains no business trips.
  Future<TripHistorySlice> _visiblePage({
    required RevenuePeriod period,
    required DateTime now,
    required int rawOffset,
  }) async {
    var page = await widget.repository.listTripsPage(
      period: period, now: now,
      rawOffset: rawOffset, pageSize: _pageSize);
    while (page.trips.isEmpty && page.hasMore) {
      page = await widget.repository.listTripsPage(
        period: period, now: now,
        rawOffset: page.nextRawOffset, pageSize: _pageSize);
    }
    return page;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;
    final period = _period;
    final now = DateTime.now();
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
    try {
      // Stats include every completed trip in the selected period.
      // Only 25 raw rows are decoded at a time for the visible history.
      final stats = await widget.repository.readTripHistoryStats(
        period: period, now: now);
      final page = await _visiblePage(
        period: period, now: now, rawOffset: 0);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _stats = stats;
        _trips = page.trips;
        _nextRawOffset = page.nextRawOffset;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đọc được lịch sử: $error')));
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _requestGeneration;
    final period = _period;
    final offset = _nextRawOffset;
    setState(() => _loadingMore = true);
    try {
      final page = await _visiblePage(
        period: period, now: DateTime.now(), rawOffset: offset);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _trips = [..._trips, ...page.trips];
        _nextRawOffset = page.nextRawOffset;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được trang tiếp theo: $error')));
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
      color: DriverProColors.panel,
      border: Border.all(color: DriverProColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    padding: const EdgeInsets.all(3),
    child: Row(children: [
      for (final period in RevenuePeriod.values)
        Expanded(child: InkWell(
          onTap: () {
            if (_period == period) return;
            setState(() => _period = period);
            _load();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: _period == period
                  ? DriverProColors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
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
          color: DriverProColors.panel,
          border: Border.all(color: DriverProColors.border),
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
        color: DriverProColors.panel,
        border: Border.all(color: DriverProColors.border),
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
              size: 37, color: DriverProColors.cyan),
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
                color: DriverProColors.green, fontSize: 17,
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

  Widget _reportHeader(TripHistoryStats report) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
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
      if (_trips.isEmpty && !_hasMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Không có chuyến đi trong kỳ',
            style: TextStyle(color: Colors.white60))),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverProColors.background,
      appBar: AppBar(
        backgroundColor: DriverProColors.backgroundDeep,
        centerTitle: true,
        title: const Text('Doanh thu',
          style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Quản lý lịch sử',
            enabled: _stats.tripCount > 0 || _trips.isNotEmpty,
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
        : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 22),
            itemCount: _trips.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _reportHeader(_stats);
              if (index <= _trips.length) return _tripTile(_trips[index - 1]);
              if (!_hasMore) return const SizedBox(height: 20);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: _loadingMore
                  ? const CircularProgressIndicator(
                      color: DriverProColors.cyan)
                  : OutlinedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Tải thêm chuyến đi'),
                    )),
              );
            },
          ),
        ),
      bottomNavigationBar: SafeArea(top: false, child: NavigationBar(
        height: 68,
        backgroundColor: DriverProColors.backgroundDeep,
        selectedIndex: 1,
        onDestinationSelected: (value) {
          if (value == 0) Navigator.pop(context);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined), label: 'Đồng hồ cước'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart, color: DriverProColors.cyan),
            label: 'Doanh thu'),
        ],
      )),
    );
  }
}
