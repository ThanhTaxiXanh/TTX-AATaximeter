import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/core/taximeter_engine.dart';
import 'src/ui/reference_speedometer.dart';
import 'src/ui/quote_dialog.dart';
import 'src/data/trip_repository.dart';
import 'src/domain/trip_record.dart';
import 'src/payment/vietqr.dart';
import 'src/ui/payment_dialogs.dart';
import 'src/ui/trip_history_page.dart';
import 'src/ui/trip_receipt_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TtxAATaximeterApp());
}

String vnd(num amount) {
  final value = amount.round().toString();
  return value.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.',
  ) + ' đ';
}

String clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

class TtxAATaximeterApp extends StatelessWidget {
  const TtxAATaximeterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TTX AATaximeter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF4BC28),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF080C18),
          useMaterial3: true,
        ),
        home: const TaximeterHome(),
      );
}

class TaximeterHome extends StatefulWidget {
  const TaximeterHome({super.key});

  @override
  State<TaximeterHome> createState() => _TaximeterHomeState();
}

class _TaximeterHomeState extends State<TaximeterHome> {
  final TaximeterEngine meter = TaximeterEngine(tariff: TariffConfig.demo());
  final SharedPreferencesAsync store = SharedPreferencesAsync();
  final TripRepository repository = TripRepository();
  bool _storageReady = false;
  TripRecord? _pendingUnsaved;
  VietQrAccount? _bank;
  String _tripPickup = '';
  String _tripDropoff = '';
  Timer? _ticker;
  StreamSubscription<Position>? _gps;
  bool _carPreview = false;
  bool _carMirror = false;
  String _gpsStatus = 'Chưa kích hoạt GPS';

  @override
  void initState() {
    super.initState();
    _initializeData();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => meter.tick(DateTime.now()));
    });
  }

  Future<void> _initializeData() async {
    try {
      await repository.initializeAndMigrate(legacyPreferences: store);
      final encodedBank = await store.getString('ttx_vietqr_account_v1');
      VietQrAccount? account;
      if (encodedBank != null) {
        try {
          final data = Map<String, dynamic>.from(jsonDecode(encodedBank) as Map);
          final found = VietQrAccount.fromJson(data);
          if (found.isValid) account = found;
        } catch (_) {
          // Broken optional bank settings should never block completed trips.
        }
      }
      if (!mounted) return;
      setState(() {
        _bank = account;
        _storageReady = true;
      });
    } catch (error) {
      if (!mounted) return;
      _notify('Lỗi khởi tạo lịch sử SQLite: ' + error.toString());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _gps?.cancel();
    repository.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _enableGps() async {
    if (_gps != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _gpsStatus = 'GPS đang tắt: bật Dịch vụ vị trí');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _gpsStatus = 'Chưa được cấp quyền vị trí');
        return;
      }
      setState(() => _gpsStatus = 'Đang dò tín hiệu GPS...');
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen((position) {
        if (!mounted) return;
        setState(() {
          meter.acceptGps(GpsFix(
            latitude: position.latitude,
            longitude: position.longitude,
            speedKmh: position.speed * 3.6,
            accuracyMeters: position.accuracy,
            timestamp: position.timestamp,
          ));
          _gpsStatus = position.accuracy <= meter.tariff.gpsMaxAccuracyMeters
              ? 'GPS ±${position.accuracy.toStringAsFixed(0)} m'
              : 'GPS yếu ±${position.accuracy.toStringAsFixed(0)} m';
        });
      }, onError: (Object error) {
        if (mounted) setState(() => _gpsStatus = 'Lỗi GPS: $error');
      });
    } catch (e) {
      if (mounted) setState(() => _gpsStatus = 'Không mở được GPS: $e');
    }
  }

  void _start() {
    if (meter.status != MeterStatus.idle || !_storageReady) return;
    _tripPickup = '';
    _tripDropoff = '';
    setState(() => meter.start());
    _enableGps();
  }

  Future<void> _finish() async {
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) return;
    final finished = meter.finish();
    final record = TripRecord.fromReceipt(
      finished, pickup: _tripPickup, dropoff: _tripDropoff);
    setState(() => _pendingUnsaved = record);
    await _saveCompletedRecord();
  }

  Future<void> _saveCompletedRecord() async {
    final record = _pendingUnsaved;
    if (record == null) return;
    try {
      await repository.save(record);
      if (!mounted) return;
      setState(() => _pendingUnsaved = null);
      _notify('Đã lưu chuyến: ' + vnd(record.receipt.totalFare));
      final method = await showDialog<PaymentMethod>(
        context: context,
        builder: (dialogContext) => TripReceiptDialog(
          record: record,
          onQr: () => _showQr(record.receipt.totalFare.round()),
        ),
      );
      if (method != null) {
        await repository.save(record.copyWith(paymentMethod: method));
        if (mounted) setState(() {
          meter.reset();
          _tripPickup = '';
          _tripDropoff = '';
          _carPreview = false;
        });
      }
    } catch (error) {
      if (mounted) {
        _notify('Không lưu được chuyến. Nhấn THỬ LƯU LẠI trước khi tạo cuốc mới: '
          + error.toString());
      }
    }
  }

  Future<void> _flatFareDialog() async {
    if (meter.status != MeterStatus.idle || !_storageReady) {
      _notify('Hoàn thành chuyến hiện tại và chờ dữ liệu sẵn sàng trước khi báo giá');
      return;
    }
    final quote = await showDialog<QuoteResult>(
      context: context,
      builder: (context) => QuoteDialog(tariff: meter.tariff),
    );
    if (!mounted || quote == null || quote.amount <= 0) return;
    _tripPickup = quote.pickup;
    _tripDropoff = quote.dropoff;
    setState(() => meter.start(fixedFare: quote.amount));
    _enableGps();
  }

  Future<void> _customTollDialog() async {
    final input = TextEditingController();
    final amount = await showDialog<double>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm phí BOT / cầu đường'),
        content: TextField(controller: input,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số tiền (đ)', hintText: 'Ví dụ: 35000')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy')),
          FilledButton(onPressed: () =>
            Navigator.pop(dialogContext, double.tryParse(input.text)),
            child: const Text('Cộng phí')),
        ],
      ),
    );
    input.dispose();
    if (!mounted || amount == null || amount < 0) return;
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) {
      _notify('Chỉ cộng phí khi đang có chuyến');
      return;
    }
    setState(() => meter.addToll(amount));
  }

  Widget _buildCarMode() {
    final active = meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused;
    final view = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800),
              borderRadius: BorderRadius.circular(10)),
            child: const Text('CAR MODE',
              style: TextStyle(color: Colors.black,
                fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          Expanded(child: Text(meter.tariff.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60))),
          IconButton(onPressed: () =>
              setState(() => _carMirror = !_carMirror),
              tooltip: 'Lật HUD kính lái',
              icon: const Icon(Icons.flip)),
          IconButton(onPressed: () =>
              setState(() { _carPreview = false; _carMirror = false; }),
              tooltip: 'Thoát Car Mode',
              icon: const Icon(Icons.close)),
        ]),
        const Spacer(),
        Text(meter.speedKmh.round().toString(),
          style: const TextStyle(
            fontSize: 106, height: 1,
            color: Color(0xFF00D8F0), fontWeight: FontWeight.w900)),
        const Text('KM/H', style: TextStyle(
          color: Colors.white60, fontSize: 19, letterSpacing: 2)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111829),
            border: Border.all(color: const Color(0xFFFFB800), width: 2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(children: [
            const Text('CƯỚC TAXI',
              style: TextStyle(color: Colors.white60)),
            FittedBox(child: Text(vnd(meter.totalFare),
              style: const TextStyle(
                color: Color(0xFFFFB800), fontSize: 50,
                fontWeight: FontWeight.w900))),
          ]),
        ),
        const SizedBox(height: 15),
        Container(padding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF1B2437),
          ),
          child: Row(children: [
            Expanded(child: Column(children: [
              const Text('QUÃNG ĐƯỜNG',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
              Text('${meter.distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ])),
            Expanded(child: Column(children: [
              const Text('THỜI GIAN',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
              Text(clock(meter.elapsedSeconds),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ])),
            Expanded(child: Column(children: [
              const Text('GIỜ CHỜ',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
              Text(clock(meter.waitingSeconds),
                style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange)),
            ])),
          ]),
        ),
        const Spacer(),
        Row(children: [
          for (final amount in [10000, 20000, 50000])
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: active ? () =>
                    setState(() => meter.addToll(amount.toDouble())) : null,
                child: Text('BOT +${amount ~/ 1000}k',
                  style: const TextStyle(
                    color: Color(0xFF00D8F0), fontSize: 12)),
              ),
            )),
        ]),
        const SizedBox(height: 7),
        SizedBox(width: double.infinity, height: 64,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: active
                  ? const Color(0xFFFF304C) : const Color(0xFF00DA75),
              foregroundColor: Colors.black),
            onPressed: active ? _finish : (meter.status == MeterStatus.idle
                ? (_storageReady ? _start : null)
                : (_pendingUnsaved == null
                    ? () => setState(meter.reset)
                    : _saveCompletedRecord)),
            child: Text(active ? 'KẾT THÚC' :
                (meter.status == MeterStatus.idle
                    ? 'BẮT ĐẦU CHUYẾN' : 'CUỐC MỚI'),
                style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 20)),
          ),
        ),
      ]),
    );
    return Scaffold(
      body: SafeArea(child: _carMirror
        ? Transform(
            transform: Matrix4.rotationY(3.141592653589793),
            alignment: Alignment.center,
            child: view,
          )
        : view),
    );
  }

  Future<void> _tariffDialog() async {
    final base = TextEditingController(text: meter.tariff.baseFare.toStringAsFixed(0));
    final km = TextEditingController(text: meter.tariff.perKmRate.toStringAsFixed(0));
    final waiting = TextEditingController(text: meter.tariff.waitingFeePerHour.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cấu hình biểu giá'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: base, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá mở cửa (đ)')),
            TextField(controller: km, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cước km (đ/km)')),
            TextField(controller: waiting, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Phí chờ (đ/giờ)')),
            const SizedBox(height: 12),
            const Text('MVP: các ngưỡng quãng đường khác giữ theo biểu giá ví dụ. '
                'Không thay đổi giá khi chuyến đang chạy.'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Áp dụng')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final next = meter.tariff.copyWith(
          baseFare: double.parse(base.text),
          perKmRate: double.parse(km.text),
          waitingFeePerHour: double.parse(waiting.text),
          name: 'Biểu giá của tôi',
        );
        setState(() => meter.updateTariff(next));
        _notify('Đã cập nhật biểu giá phiên làm việc');
      } catch (_) {
        _notify('Chỉ được nhập số hợp lệ; không đổi giá giữa chuyến');
      }
    }
    base.dispose();
    km.dispose();
    waiting.dispose();
  }

  void _showHistory() {
    if (!_storageReady) {
      _notify('Cơ sở dữ liệu chưa sẵn sàng');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => TripHistoryPage(
        repository: repository,
        onQr: (amount) => _showQr(amount),
      ),
    ));
  }

  Future<VietQrAccount?> _configureBank() async {
    final chosen = await showDialog<VietQrAccount>(
      context: context,
      builder: (ctx) => BankAccountDialog(initial: _bank),
    );
    if (chosen == null || !mounted) return _bank;
    try {
      await store.setString('ttx_vietqr_account_v1',
        jsonEncode(chosen.toJson()));
      if (mounted) setState(() => _bank = chosen);
      return chosen;
    } catch (error) {
      if (mounted) _notify('Không lưu được cấu hình ngân hàng: '
          + error.toString());
      return null;
    }
  }

  Future<void> _showQr([int? value]) async {
    final amount = value ?? meter.totalFare.round();
    if (amount <= 0) {
      _notify('Cần có số tiền cước lớn hơn 0 để tạo mã QR động');
      return;
    }
    var account = _bank;
    if (account == null || !account.isValid) {
      account = await _configureBank();
    }
    if (account == null || !mounted) return;
    final memo = 'TTX CUOC ' + DateTime.now()
        .millisecondsSinceEpoch.toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => PaymentQrDialog(
        account: account!,
        amountVnd: amount,
        memo: memo,
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Icon(icon, size: 20, color: Colors.amberAccent),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = meter.status;
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    final statusLabel = switch (status) {
      MeterStatus.idle => 'CHỜ KHÁCH',
      MeterStatus.running => 'ĐANG TÍNH CƯỚC',
      MeterStatus.paused => 'TẠM DỪNG / TÍNH CHỜ',
      MeterStatus.finished => 'HOÀN THÀNH',
    };
    if (_carPreview) return _buildCarMode();
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTX AATaximeter'),
        actions: [
          IconButton(onPressed: _showHistory,
            icon: const Icon(Icons.history), tooltip: 'Lịch sử'),
          IconButton(onPressed: _configureBank,
            icon: const Icon(Icons.account_balance),
            tooltip: 'Tài khoản VietQR'),
          IconButton(onPressed: _tariffDialog,
            icon: const Icon(Icons.tune), tooltip: 'Cài giá'),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Card(child: ListTile(
            leading: const Icon(Icons.gps_fixed, color: Color(0xFF00DA75)),
            title: Text(_gpsStatus, style: const TextStyle(
                fontSize: 12, color: Color(0xFF00DA75))),
            trailing: Text(statusLabel, style: const TextStyle(fontSize: 11)),
          )),
          Card(child: ListTile(
            dense: true,
            leading: const Icon(Icons.campaign_outlined,
                color: Color(0xFFFFB800)),
            title: const Text('● LED   CHÚC QUÝ KHÁCH THƯỢNG LỘ BÌNH AN',
              style: TextStyle(color: Color(0xFFFFB800), fontSize: 12)),
          )),
          const Card(child: ListTile(
            dense: true,
            leading: Icon(Icons.navigation, color: Color(0xFF00D8F0)),
            title: Text('Tên đường: đang cập nhật vị trí...',
              style: TextStyle(fontSize: 12)),
          )),
          ReferenceSpeedometer(
            speedKmh: meter.speedKmh,
            speedLimitKmh: meter.tariff.speedLimitKmh,
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(
                vertical: _carPreview ? 45 : 25, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111829),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amber.shade700, width: 1),
            ),
            child: Column(children: [
              Text('TỔNG TIỀN CƯỚC',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              FittedBox(child: Text(vnd(meter.totalFare),
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              )),
              Text(meter.tariff.name, style: const TextStyle(fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoCard('Tốc độ', '${meter.speedKmh.toStringAsFixed(0)} km/h',
                Icons.speed)),
            Expanded(child: _infoCard('Quãng đường', '${meter.distanceKm.toStringAsFixed(2)} km',
                Icons.route)),
          ]),
          Row(children: [
            Expanded(child: _infoCard('Thời gian', clock(meter.elapsedSeconds),
                Icons.schedule)),
            Expanded(child: _infoCard('Chờ', clock(meter.waitingSeconds),
                Icons.hourglass_bottom)),
          ]),
          if (meter.isOverSpeedLimit)
            const Card(child: ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange),
                title: Text('Vượt ngưỡng tốc độ cài đặt'))),
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _fareRow('Mở cửa', meter.baseFare),
              _fareRow('Cước quãng đường', meter.distanceFare),
              _fareRow('Cước chờ', meter.waitingFare),
              _fareRow('Phí BOT', meter.tollFee),
              _fareRow('Phụ thu', meter.surcharge),
              _fareRow('Giảm giá', -meter.discount),
            ]),
          )),
          const SizedBox(height: 7),
          if (status == MeterStatus.idle)
            Column(children: [
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _storageReady ? _start : null, icon: const Icon(Icons.play_arrow),
                label: const Text('BẮT ĐẦU TÍNH CƯỚC CHUẨN'),
              )),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _storageReady ? _flatFareDialog : null, icon: const Icon(Icons.price_check),
                label: const Text('TÍNH TRƯỚC / BAO GIÁ TRỌN GÓI (1 & 2 CHIỀU)'),
              )),
            ]),
          if (active) ...[
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => setState(() {
                  if (status == MeterStatus.running) {
                    meter.pause();
                  } else {
                    meter.resume();
                  }
                }),
                icon: Icon(status == MeterStatus.running ?
                    Icons.pause : Icons.play_arrow),
                label: Text(status == MeterStatus.running ?
                    'TẠM DỪNG' : 'TIẾP TỤC'),
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                onPressed: _finish, icon: const Icon(Icons.stop),
                label: const Text('KẾT THÚC'),
              )),
            ]),
            Wrap(spacing: 8, children: [
              ActionChip(label: const Text('+10.000đ BOT'), onPressed: () =>
                  setState(() => meter.addToll(10000))),
              ActionChip(label: const Text('+20.000đ BOT'), onPressed: () =>
                  setState(() => meter.addToll(20000))),
              ActionChip(label: const Text('+35.000đ BOT'), onPressed: () =>
                  setState(() => meter.addToll(35000))),
              ActionChip(label: const Text('+50.000đ BOT'), onPressed: () =>
                  setState(() => meter.addToll(50000))),
              ActionChip(label: const Text('✎ Tùy chỉnh'),
                  onPressed: _customTollDialog),
            ]),
          ],
          if (status == MeterStatus.finished)
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _pendingUnsaved == null
                ? () => setState(meter.reset)
                : _saveCompletedRecord,
              icon: Icon(_pendingUnsaved == null
                ? Icons.restart_alt : Icons.save),
              label: Text(_pendingUnsaved == null
                ? 'CHUYẾN MỚI' : 'THỬ LƯU LẠI CHUYẾN'),
            )),
          SwitchListTile(
            title: const Text('Chế độ xe hơi • CAR MODE'),
            subtitle: const Text('Bố cục toàn màn hình trên điện thoại; có HUD lật ngang'),
            value: _carPreview,
            onChanged: (value) => setState(() => _carPreview = value),
          ),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton.icon(onPressed: () => _showQr(),
                icon: const Icon(Icons.qr_code_2), label: const Text('Mã QR')),
            TextButton.icon(onPressed: () => _flatFareDialog(),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Bao giá')),
            TextButton.icon(onPressed: _showHistory,
                icon: const Icon(Icons.history),
                label: const Text('Lịch sử')),
            TextButton.icon(onPressed: _tariffDialog,
                icon: const Icon(Icons.settings),
                label: const Text('Cài đặt')),
          ]),
          const SizedBox(height: 20),
          const Center(child: Text(
            'MVP thử nghiệm • Chưa dùng tính tiền thương mại',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          )),
        ]),
      ),
    );
  }

  Widget _fareRow(String label, double amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(vnd(amount), style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
