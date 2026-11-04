import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/core/taximeter_engine.dart';
import 'src/core/location_tracking_policy.dart';
import 'src/ui/fare_breakdown_section.dart';
import 'src/ui/quote_dialog.dart';
import 'src/data/trip_repository.dart';
import 'src/domain/trip_record.dart';
import 'src/domain/trip_route_point.dart';
import 'src/payment/vietqr.dart';
import 'src/ui/bank_accounts_dialog.dart';
import 'src/ui/vietqr_payment_panel.dart';
import 'src/payment/bank_book.dart';
import 'src/ui/trip_history_page.dart';
import 'src/ui/trip_receipt_dialog.dart';
import 'src/data/tariff_codec.dart';
import 'src/data/trip_session_snapshot.dart';
import 'src/domain/tariff_catalog.dart';
import 'src/ui/tariff_catalog_page.dart';
import 'src/ui/tariff_settings_dialog.dart';
import 'src/ui/dashboard_map.dart';
import 'src/platform/car_state_bridge.dart';
import 'src/domain/vehicle_registration.dart';
import 'src/ui/vehicle_registration_dialog.dart';

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

class _TaximeterHomeState extends State<TaximeterHome> with WidgetsBindingObserver {
  TaximeterEngine meter = TaximeterEngine(tariff: TariffConfig.demo());
  final SharedPreferencesAsync store = SharedPreferencesAsync();
  final TripRepository repository = TripRepository();
  TariffCatalog _tariffCatalog = TariffCatalog.initial();
  double? _mapLat;
  double? _mapLon;
  final List<TripRoutePoint> _routePoints = [];
  int _routeSegment = 0;
  bool _storageReady = false;
  bool _savingNewTrip = false;
  DateTime _lastCheckpoint = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _writeQueue = Future<void>.value();
  String? _checkpointError;
  TripRecord? _pendingUnsaved;
  BankBook _bankBook = const BankBook();
  VehicleRegistration? _vehicle;
  bool _vehicleDialogOpen = false;
  String _tripPickup = '';
  String _tripDropoff = '';
  String _tripVehicleType = '';
  String _tripVehiclePlate = '';
  String _tripFareProfileName = '';
  final TextEditingController _destinationController = TextEditingController();
  Timer? _ticker;
  StreamSubscription<Position>? _gps;
  final LocationTrackingPolicy _trackingPolicy = LocationTrackingPolicy();
  bool _gpsStarting = false;
  bool _appVisible = true;
  bool _mapLocating = false;
  bool _carPreview = false;
  bool _carMirror = false;
  String _gpsStatus = 'Chưa kích hoạt GPS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _meterTick(DateTime.now());
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
      BankBook bankBook = account == null
          ? const BankBook() : BankBook.migrateLegacy(account);
      final savedBankBook = await store.getString('ttx_vietqr_bank_book_v1');
      if (savedBankBook != null) {
        try {
          bankBook = BankBook.decode(savedBankBook);
        } catch (_) {
          // Legacy account is retained if the newer account book is corrupted.
        }
      }
      VehicleRegistration? registration;
      final rawVehicle = await store.getString('ttx_vehicle_v1');
      if (rawVehicle != null) {
        try {
          registration = VehicleRegistration.decode(rawVehicle);
        } catch (_) {
          // Never trust a malformed registration. Re-prompt explicitly.
        }
      }
      final savedTariff = await store.getString('ttx_tariff_v1');
      if (savedTariff != null) {
        try {
          meter.updateTariff(TariffCodec.decode(savedTariff));
        } catch (_) {
          // Invalid stored tariff does not replace the validated preset.
        }
      }
      TariffCatalog catalog = TariffCatalog.initial(existing: meter.tariff);
      final savedCatalog = await store.getString('ttx_tariff_catalog_v1');
      if (savedCatalog != null) {
        try {
          catalog = TariffCatalog.decode(savedCatalog);
          meter.updateTariff(catalog.active.tariff!);
        } catch (_) {
          // Legacy tariff remains valid when catalog JSON is malformed.
        }
      }
      final rawActive = await repository.loadActive();
      if (rawActive != null) {
        final restored = TripSessionSnapshot.decode(rawActive);
        meter = restored.restore();
        _tripPickup = restored.pickup;
        _tripDropoff = restored.dropoff;
        _tripVehicleType = restored.vehicleType;
        _tripVehiclePlate = restored.vehiclePlate;
        _tripFareProfileName = restored.fareProfileName;
        _routePoints.addAll(restored.routePoints);
        _routeSegment = _routePoints.isEmpty ? 0 :
            _routePoints.last.segment + 1;
        _destinationController.text = restored.dropoff;
        _gpsStatus = 'Chuyến cũ đã được tạm ngắt an toàn';
      }
      if (!mounted) return;
      setState(() {
        _bankBook = bankBook;
        _vehicle = registration;
        _tariffCatalog = catalog;
        _storageReady = true;
      });
      await CarStateBridge.publish(meter);
      // Request location at first launch; automatically center the map.
      // Registration comes later so two dialogs never overlap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_initialLocationSetup(
          needsVehicle: registration == null,
        ));
      });
    } catch (error) {
      if (!mounted) return;
      _notify('Lỗi khởi tạo lịch sử SQLite: ' + error.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _gps?.cancel();
    repository.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// First launch: an explanatory, one-time foreground permission request.
  /// Android 11+ grants "Always allow" through app-specific settings after
  /// foreground permission; never combine both runtime permission requests.
  Future<void> _initialLocationSetup({required bool needsVehicle}) async {
    if (!mounted) return;
    try {
      final initial = await Geolocator.checkPermission();
      if (initial == LocationPermission.denied) {
        final asked = await store.getBool('ttx_location_onboarded_v1') ?? false;
        if (!asked && mounted && _appVisible) {
          await store.setBool('ttx_location_onboarded_v1', true);
          if (!mounted) return;
          final approved = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cấp quyền định vị cho đồng hồ taxi'),
              content: const Text('Ứng dụng dùng GPS để hiển thị vị trí và '
                'ghi quãng đường của chuyến bạn chủ động bắt đầu. '
                'Khi chuyến đang chạy, một thông báo theo dõi vị trí sẽ '
                'được hiển thị. Bạn có thể từ chối và cấp lại trong Cài đặt.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Để sau')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Cấp quyền vị trí')),
              ],
            ),
          );
          if (approved == true && mounted && _appVisible) {
            await Geolocator.requestPermission();
          }
        }
      }
      if (!mounted || !_appVisible) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await _refreshMapLocation();
        if (mounted && _appVisible &&
            permission != LocationPermission.always) {
          final askedBackground =
              await store.getBool('ttx_background_explained_v1') ?? false;
          if (!askedBackground && mounted && _appVisible) {
            await store.setBool('ttx_background_explained_v1', true);
            if (mounted) await _explainAlwaysLocation();
          }
        }
      } else if (mounted) {
        setState(() => _gpsStatus = 'Chưa cấp quyền GPS; chạm nút vị trí trên bản đồ');
      }
      if (needsVehicle && mounted && _appVisible && _vehicle == null) {
        await _configureVehicle();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _gpsStatus = 'Không lấy được quyền GPS: ' + error.toString());
      }
    }
  }

  /// Background access is an explicit, separate choice via Android Settings.
  /// Consent does not guarantee that Android/OEM keeps Dart alive if force-stop
  /// or battery optimization kills the process.
  Future<void> _explainAlwaysLocation() async {
    if (!mounted || !_appVisible ||
        defaultTargetPlatform != TargetPlatform.android) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cho phép vị trí mọi lúc'),
        content: const Text('Để hỗ trợ đồng hồ taxi khi chuyển ứng dụng '
          'hoặc khóa màn hình, bạn có thể mở Quyền vị trí rồi chọn '
          '“Luôn cho phép” / “Allow all the time” và “Vị trí chính xác”. '
          'Ứng dụng chỉ tính cước khi bạn bắt đầu chuyến, có thông báo '
          'GPS nền và vẫn có thể tạm ngắt nếu mất tín hiệu. '
          'Thoát bằng Buộc dừng hoặc hệ thống dừng tiến trình không '
          'được bảo đảm tiếp tục tính cước.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mở cài đặt quyền')),
        ],
      ),
    );
    if (go == true && mounted) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _refreshMapLocation() async {
    if (!mounted || _mapLocating || !_appVisible) return;
    // The active trip's GPS stream already supplies live location.
    if (_gps != null) return;
    _mapLocating = true;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsStatus = 'GPS đang tắt trong hệ thống');
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted || !_appVisible) return;
      if (!position.latitude.isFinite || !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) return;
      setState(() {
        _mapLat = position.latitude;
        _mapLon = position.longitude;
        _gpsStatus = 'Đã định vị GPS';
      });
    } catch (error) {
      if (mounted && _appVisible) {
        setState(() => _gpsStatus =
            'GPS chưa xác định được vị trí; thử lại khi tín hiệu tốt');
      }
    } finally {
      _mapLocating = false;
    }
  }

  /// Location FGS can only be started by a visible Activity without a
  /// platform exemption. Background permission is NEVER a workaround for
  /// secretly starting metering when the user has stopped the app.
  Future<bool> _requestLocationReady() async {
    if (!_appVisible || !mounted) return false;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _gpsStatus = 'GPS tắt: vui lòng bật Dịch vụ vị trí');
          _notify('Hãy bật GPS trước khi bắt đầu hoặc tiếp tục chuyến');
        }
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _gpsStatus = 'Chưa có quyền vị trí');
          _notify('Cấp quyền vị trí chính xác trong Cài đặt Android');
        }
        return false;
      }
      return mounted && _appVisible;
    } catch (error) {
      if (mounted) {
        setState(() => _gpsStatus = 'Không kiểm tra được quyền GPS');
        _notify('GPS: $error');
      }
      return false;
    }
  }

  Future<void> _stopGps() async {
    final subscription = _gps;
    _gps = null;
    _trackingPolicy.clear();
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {
        // A broken platform subscription must not affect the final receipt.
      }
    }
  }

  void _suspendForGps(String reason) {
    if (!mounted) return;
    final active = meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused;
    if (active) {
      final now = DateTime.now();
      setState(() {
        meter.skipUntrustedInterval(now);
        meter.suspendForInterruption(at: now);
        _gpsStatus = reason;
      });
      _checkpoint(force: true);
    }
    unawaited(_stopGps());
  }

  void _meterTick(DateTime now) {
    // A manual pause may accrue waiting, but only with reliable GPS.
    // An interruption never adds distance, elapsed time or waiting charges.
    final active = meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused;
    if (!active) return;
    if (!meter.requiresManualResume && _trackingPolicy.shouldSuspend(now)) {
      // Keep the foreground location subscription alive. Canceling it here
      // makes a brief Android screen-off GPS gap permanently stop the ride.
      if (_gps == null) {
        _suspendForGps('Dịch vụ GPS đã dừng: tạm ngắt tính cước');
        return;
      }
      setState(() {
        meter.skipUntrustedInterval(now);
        _gpsStatus = 'GPS gián đoạn: đang chờ tín hiệu, không cộng cước';
      });
      _checkpoint();
      return;
    }
    setState(() {
      if (meter.requiresManualResume) {
        meter.tick(now);
      } else if (_trackingPolicy.hasRecentFix(now)) {
        meter.tick(now);
      } else {
        // Do not charge an unobserved interval in either RUNNING or PAUSED.
        meter.skipUntrustedInterval(now);
      }
    });
    _checkpoint();
  }

  /// Geolocator's AndroidSettings spawns a location-type FGS with a
  /// persistent visible notification when the app moves to background.
  Future<bool> _enableGps() async {
    if (_gps != null) return true;
    if (_gpsStarting) return false;
    _gpsStarting = true;
    try {
      if (!await _requestLocationReady()) {
        _suspendForGps('Không thể bật GPS: thiếu quyền hoặc dịch vụ vị trí');
        return false;
      }
      if (!mounted || !_appVisible) {
        _suspendForGps('Ứng dụng đã ra nền trước khi GPS khởi động');
        return false;
      }
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 1,
              intervalDuration: const Duration(seconds: 2),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'TTX AATaximeter • Đang tính cước',
                notificationText:
                    'GPS đang ghi nhận quãng đường. Mở ứng dụng để kết thúc chuyến.',
                notificationChannelName: 'Đồng hồ taxi - GPS chuyến đi',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 1,
            );
      setState(() => _gpsStatus = 'GPS nền: đang chờ vị trí chính xác...');
      _gps = Geolocator.getPositionStream(locationSettings: settings)
          .listen((position) {
        if (!mounted || meter.requiresManualResume ||
            meter.status == MeterStatus.finished ||
            meter.status == MeterStatus.idle) return;
        final now = DateTime.now();
        // Check the old watchdog state BEFORE refreshing it with this fix.
        // Otherwise a resumed stream could hide a long background GPS gap.
        if (_trackingPolicy.shouldSuspend(now)) {
          // A late but fresh, valid fix may resume tracking with a new
          // baseline. Never bridge a GPS blackout or bill its elapsed time.
          meter.skipUntrustedInterval(now);
          _routeSegment++;
        }
        final age = now.difference(position.timestamp);
        // A cached or future fix must not refresh the GPS watchdog.
        if (age.isNegative && age.abs() > const Duration(seconds: 3)) return;
        if (age > const Duration(seconds: 12)) return;
        final firstFix = !_trackingPolicy.hasTrustedFix;
        if (firstFix) {
          // The time before GPS lock is unobserved, not billable waiting.
          meter.skipUntrustedInterval(now);
        }
        final accepted = meter.acceptGps(GpsFix(
          latitude: position.latitude,
          longitude: position.longitude,
          speedKmh: position.speed * 3.6,
          accuracyMeters: position.accuracy,
          timestamp: position.timestamp,
        ));
        if (!accepted) {
          if (meter.status == MeterStatus.running) {
            setState(() => _gpsStatus = 'GPS yếu / sai số: đang chờ tín hiệu');
          }
          return;
        }
        _trackingPolicy.acceptedFix(now);
        if (meter.status == MeterStatus.running) {
          final last = _routePoints.isEmpty ? null : _routePoints.last;
          if (last == null || last.segment != _routeSegment ||
              now.difference(last.recordedAt) >= const Duration(seconds: 5) ||
              (last.latitude - position.latitude).abs() > 0.00004 ||
              (last.longitude - position.longitude).abs() > 0.00004) {
            _routePoints.add(TripRoutePoint(
              latitude: position.latitude, longitude: position.longitude,
              recordedAt: position.timestamp, accuracyMeters: position.accuracy,
              speedKmh: position.speed * 3.6, segment: _routeSegment,
            ));
          }
        }
        setState(() {
          _mapLat = position.latitude;
          _mapLon = position.longitude;
          _gpsStatus = 'GPS nền ±' +
              position.accuracy.toStringAsFixed(0) + ' m';
        });
        // Also advance on each valid fix: Android may throttle Dart timers
        // during multitasking, but a healthy location stream may continue.
        _meterTick(now);
      }, onError: (Object error) {
        _suspendForGps('Dịch vụ GPS lỗi: $error');
      }, onDone: () {
        if (_gps != null && meter.status == MeterStatus.running) {
          _suspendForGps('Dịch vụ GPS đã dừng ngoài dự kiến');
        }
      });
      return true;
    } catch (error) {
      _suspendForGps('Không khởi động được GPS nền: $error');
      return false;
    } finally {
      _gpsStarting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
    if (state == AppLifecycleState.resumed) {
      // Returning from Android app settings or switching apps auto-refocuses.
      unawaited(_refreshMapLocation());
      return;
    }
    if (state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused) return;
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) return;
    // Geolocator already runs a location-type Android foreground service.
    // Do not cancel it just because we leave while acquiring a GPS fix.
    // The watchdog suppresses untrusted billing; a valid fix may recover.
    if (_gps == null) {
      _suspendForGps('Dịch vụ GPS không hoạt động khi ra nền');
    }
  }

  String _sessionPayload() => TripSessionSnapshot.fromEngine(
    meter, pickup: _tripPickup, dropoff: _tripDropoff,
    vehicleType: _tripVehicleType,
    vehiclePlate: _tripVehiclePlate,
    fareProfileName: _tripFareProfileName,
    routePoints: _routePoints,
  ).encode();

  /// Freeze vehicle and fare profile at trip start.
  void _captureTripMetadata() {
    _tripVehicleType = _vehicle?.category.label ?? '';
    _tripVehiclePlate = _vehicle?.plate ?? '';
    _tripFareProfileName = _tariffCatalog.active.label;
  }

  /// Serialize writes so a slower old checkpoint cannot replace a new one.
  void _checkpoint({bool force = false}) {
    if (!_storageReady || _savingNewTrip) return;
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastCheckpoint).inSeconds < 3) return;
    _lastCheckpoint = now;
    final data = _sessionPayload(); // immutable snapshot at this instant
    _writeQueue = _writeQueue.then((_) async {
      await repository.saveActive(data);
      await CarStateBridge.publish(meter);
    }).catchError((Object error) {
      _checkpointError = error.toString();
    });
  }

  Future<bool> _saveNewTrip() async {
    _savingNewTrip = true;
    try {
      await _writeQueue;
      await repository.saveActive(_sessionPayload());
      await CarStateBridge.publish(meter);
      _lastCheckpoint = DateTime.now();
      _checkpointError = null;
      return true;
    } catch (error) {
      if (mounted) _notify('Không lưu được chuyến mới: ' + error.toString());
      return false;
    } finally {
      _savingNewTrip = false;
    }
  }

  Future<void> _start() async {
    if (meter.status != MeterStatus.idle || !_storageReady) return;
    if (_vehicle == null && !await _configureVehicle()) return;
    if (!mounted || meter.status != MeterStatus.idle) return;
    if (!await _requestLocationReady()) return;
    if (!mounted || !_appVisible || meter.status != MeterStatus.idle) return;
    final now = DateTime.now();
    _tripPickup = '';
    _tripDropoff = _destinationController.text.trim();
    _captureTripMetadata();
    setState(() {
      _routePoints.clear();
      _routeSegment = 0;
      meter.start(at: now);
    });
    _trackingPolicy.begin(now);
    if (!await _saveNewTrip()) {
      if (mounted) setState(meter.reset);
      _trackingPolicy.clear();
      return;
    }
    if (mounted) await _enableGps();
  }

  Future<void> _resumeTrip() async {
    if (meter.status != MeterStatus.paused) return;
    if (!await _requestLocationReady()) return;
    if (!mounted || !_appVisible || meter.status != MeterStatus.paused) return;
    final now = DateTime.now();
    setState(() {
      _routeSegment++; // A pause must not create a fictitious map connection.
      meter.resume(at: now);
    });
    _trackingPolicy.begin(now);
    _checkpoint(force: true);
    if (_gps == null) await _enableGps();
  }

  Future<void> _finish() async {
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) return;
    final finished = meter.finish();
    unawaited(_stopGps());
    final record = TripRecord.fromReceipt(
      finished,
      pickup: _tripPickup, dropoff: _tripDropoff,
      vehicleType: _tripVehicleType,
      vehiclePlate: _tripVehiclePlate,
      fareProfileName: _tripFareProfileName,
      tariffSnapshot: meter.tariff,
      routePoints: _routePoints);
    setState(() => _pendingUnsaved = record);
    await _saveCompletedRecord();
  }

  Future<void> _saveCompletedRecord() async {
    final record = _pendingUnsaved;
    if (record == null) return;
    try {
      await _writeQueue;
      await repository.completeActive(record);
      await CarStateBridge.publish(meter);
      if (!mounted) return;
      setState(() => _pendingUnsaved = null);
      _notify('Đã lưu chuyến: ' + vnd(record.receipt.totalFare));
      final method = await showDialog<PaymentMethod>(
        context: context,
        builder: (dialogContext) => TripReceiptDialog(
          record: record,
          bankBook: _bankBook,
          onConfigureBank: _configureBank,
        ),
      );
      if (method != null) {
        await repository.save(record.copyWith(paymentMethod: method));
        if (mounted) setState(() {
          meter.reset();
          _tripPickup = '';
          _tripDropoff = '';
          _carPreview = false;
          _destinationController.clear();
        });
        await CarStateBridge.publish(meter);
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
    if (_vehicle == null && !await _configureVehicle()) return;
    if (!mounted || meter.status != MeterStatus.idle) return;
    final quote = await showDialog<QuoteResult>(
      context: context,
      builder: (context) => QuoteDialog(tariff: meter.tariff),
    );
    if (!mounted || quote == null || quote.amount <= 0) return;
    if (!await _requestLocationReady()) return;
    if (!mounted || !_appVisible || meter.status != MeterStatus.idle) return;
    final now = DateTime.now();
    _tripPickup = quote.pickup;
    _tripDropoff = quote.dropoff;
    _destinationController.text = quote.dropoff;
    _captureTripMetadata();
    setState(() {
      _routePoints.clear();
      _routeSegment = 0;
      meter.start(at: now, fixedFare: quote.amount);
    });
    _trackingPolicy.begin(now);
    if (!await _saveNewTrip()) {
      if (mounted) setState(meter.reset);
      _trackingPolicy.clear();
      return;
    }
    if (mounted) await _enableGps();
  }

  Future<void> _customTollDialog() async {
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) {
      _notify('Chỉ cộng phí BOT khi đang có chuyến');
      return;
    }
    // No manually disposed TextEditingController: the old modal could be
    // torn down while its route was still animating, triggering framework
    // lifecycle assertions on some Android builds.
    var typed = '';
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nhập phí trạm thu phí (BOT)'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (value) => typed = value,
          decoration: const InputDecoration(
            labelText: 'Phí BOT một lượt (₫)',
            hintText: 'Ví dụ: 35000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                typed.trim().replaceAll('.', '').replaceAll(',', ''));
              if (parsed == null || !parsed.isFinite ||
                  parsed <= 0 || parsed > 2000000) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text(
                    'Nhập phí từ 1 đến 2.000.000 ₫')));
                return;
              }
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Cộng phí BOT')),
        ],
      ),
    );
    if (!mounted || amount == null ||
        (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused)) return;
    setState(() => meter.addToll(amount));
    _checkpoint(force: true);
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
        if (meter.requiresManualResume)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(width: double.infinity,
              child: FilledButton.icon(
                onPressed: _resumeTrip,
                icon: const Icon(Icons.play_circle),
                label: const Text('TIẾP TỤC CHUYẾN ĐÃ TẠM NGẮT'),
              ),
            ),
          ),
        Row(children: [
          for (final amount in [10000, 20000, 50000])
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: active ? () {
                  setState(() => meter.addToll(amount.toDouble()));
                  _checkpoint(force: true);
                } : null,
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

  bool get _canChangeFare => meter.status == MeterStatus.idle;

  Future<void> _applyCatalog(TariffCatalog catalog) async {
    if (!_canChangeFare) {
      _notify('Kết thúc chuyến trước khi thay bảng giá.');
      return;
    }
    try {
      catalog.validate();
      final fare = catalog.active.tariff!;
      // Persist first: a failed write must not silently change live pricing.
      await store.setString('ttx_tariff_catalog_v1', catalog.encode());
      await store.setString('ttx_tariff_v1', TariffCodec.encode(fare));
      if (!mounted || !_canChangeFare) return;
      setState(() {
        meter.updateTariff(fare);
        _tariffCatalog = catalog;
      });
      _notify('Đã chọn bảng giá: ' + catalog.active.label);
    } catch (error) {
      if (mounted) _notify('Không lưu được biểu giá: ' + error.toString());
    }
  }

  Future<void> _tariffDialog() async {
    if (!_canChangeFare) {
      _notify('Không đổi biểu giá khi chuyến đang chạy hoặc chưa tạo cuốc mới.');
      return;
    }
    final chosen = await Navigator.of(context).push<TariffCatalog>(
      MaterialPageRoute(builder: (context) =>
        TariffCatalogPage(initial: _tariffCatalog)),
    );
    if (chosen != null && mounted) await _applyCatalog(chosen);
  }

  Future<void> _showTariffSelector() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151518),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .72),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('CHỌN BẢNG GIÁ CƯỚC',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('Chọn tên cấu hình đã lưu cho chuyến mới.',
              style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 12),
            for (final profile in _tariffCatalog.profiles)
              if (profile.configured)
                ListTile(
                  leading: const Icon(Icons.local_taxi,
                    color: Color(0xFF168FFF)),
                  title: Text(profile.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Giá mở cửa: ' +
                    vnd(profile.tariff!.baseFare)),
                  trailing: profile.id == _tariffCatalog.activeId
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF2DCE65)) : null,
                  onTap: () => Navigator.pop(sheetContext, profile.id),
                ),
            const Divider(),
            TextButton.icon(
              onPressed: () => Navigator.pop(sheetContext, '__manage__'),
              icon: const Icon(Icons.tune),
              label: const Text('Tạo / sửa các bảng giá đã lưu')),
          ]),
        )),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == '__manage__') {
      await _tariffDialog();
      return;
    }
    if (!_canChangeFare) {
      _notify('Chỉ được đổi bảng giá khi chưa bắt đầu chuyến mới.');
      return;
    }
    try {
      await _applyCatalog(_tariffCatalog.activate(chosen));
    } catch (error) {
      if (mounted) _notify('Không chọn được biểu giá: ' + error.toString());
    }
  }

  Future<void> _locateOnMap() async {
    if (!await _requestLocationReady()) return;
    await _refreshMapLocation();
  }

  void _showHistory() {
    if (!_storageReady) {
      _notify('Cơ sở dữ liệu chưa sẵn sàng');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => TripHistoryPage(
        repository: repository,
        bankBook: _bankBook,
        onConfigureBank: _configureBank,
      ),
    ));
  }

  Future<bool> _configureVehicle() async {
    if (!mounted || _vehicleDialogOpen) return false;
    _vehicleDialogOpen = true;
    try {
      final registration = await showDialog<VehicleRegistration>(
        context: context,
        builder: (dialogContext) =>
            VehicleRegistrationDialog(initial: _vehicle),
      );
      if (registration == null || !mounted) return false;
      await store.setString('ttx_vehicle_v1', registration.encode());
      if (!mounted) return false;
      setState(() => _vehicle = registration);
      _notify('Đã lưu thông tin xe: ' + registration.plate);
      return true;
    } catch (error) {
      if (mounted) _notify('Không lưu được thông tin xe: ' + error.toString());
      return false;
    } finally {
      _vehicleDialogOpen = false;
    }
  }

  Future<BankBook?> _configureBank() async {
    final chosen = await showDialog<BankBook>(
      context: context,
      builder: (ctx) => BankAccountsDialog(initial: _bankBook),
    );
    if (chosen == null || !mounted) return _bankBook;
    try {
      // Bank numbers and brand image paths live only in local app storage.
      await store.setString('ttx_vietqr_bank_book_v1', chosen.encode());
      if (mounted) {
        setState(() => _bankBook = chosen);
        _notify('Đã lưu tài khoản ngân hàng và logo QR');
      }
      return chosen;
    } catch (error) {
      if (mounted) _notify('Không lưu được danh sách ngân hàng: ' +
          error.toString());
      return null;
    }
  }

  Future<void> _showQr([int? value]) async {
    final amount = value ?? meter.totalFare.round();
    if (amount < 0) return;
    var book = _bankBook;
    if (book.selected == null) {
      final selected = await _configureBank();
      if (selected == null || !mounted) return;
      book = selected;
    }
    if (book.selected == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => PaymentQrDialog(
        book: book,
        amountVnd: amount,
        memo: 'TTX TAXI',
      ),
    );
  }

  Widget _metricTile({
    required String label, required String value,
    required IconData icon,
  }) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF202023),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 5),
      Row(children: [
        Icon(icon, color: const Color(0xFFFF4549), size: 19),
        const SizedBox(width: 7),
        Expanded(child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(
            fontSize: 25, fontWeight: FontWeight.w800,
            color: Color(0xFFFF4549),
            fontFeatures: [FontFeature.tabularFigures()],
          )),
        )),
      ]),
    ]),
  );

  Widget _selectedCompanyCard(MeterStatus status) {
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    final label = status == MeterStatus.idle ||
            _tripFareProfileName.isEmpty
        ? _tariffCatalog.active.label : _tripFareProfileName;
    final stateText = meter.requiresManualResume
        ? 'Tạm ngắt'
        : status == MeterStatus.running ? 'Đang chạy'
        : status == MeterStatus.paused ? 'Tạm dừng'
        : status == MeterStatus.finished ? 'Hoàn tất' : 'Chờ khách';
    return InkWell(
      key: const Key('fare-profile-selector'),
      onTap: _showTariffSelector,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF202023)
              : const Color(0xFF118BFB),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(children: [
          const Icon(Icons.local_taxi,
            color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              if (!active && status == MeterStatus.idle)
                Text('Mở cửa: ' + vnd(meter.tariff.baseFare),
                  style: const TextStyle(color: Colors.white70)),
              if (active)
                Text(stateText + '  •  ' +
                  (meter.elapsedSeconds ~/ 60).toString() + ' phút',
                  style: TextStyle(color: meter.requiresManualResume
                    ? const Color(0xFFFFA332)
                    : const Color(0xFF26C65A))),
              if (status == MeterStatus.finished)
                const Text('Chuyến đã kết thúc',
                  style: TextStyle(color: Colors.white70)),
            ],
          )),
         ]),
      ),
    );
  }

  Widget _mainFareCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFF202023),
      borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      const Text('Thành tiền', style: TextStyle(
        color: Colors.white60, fontSize: 14)),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(vnd(meter.totalFare),
          key: const Key('live-fare-total'),
          style: const TextStyle(
            color: Color(0xFFFF4549),
            fontSize: 40,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          )),
      ),
    ]),
  );

  void _showTools(String choice) {
    switch (choice) {
      case 'vehicle':
        _configureVehicle();
        return;
      case 'bank':
        _configureBank();
        return;
      case 'quote':
        _flatFareDialog();
        return;
      case 'qr':
        _showQr();
        return;
      case 'car':
        setState(() => _carPreview = true);
        return;
      case 'toll':
        _customTollDialog();
        return;
      case 'locationPermission':
        _explainAlwaysLocation();
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = meter.status;
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    if (_carPreview) return _buildCarMode();

    return Scaffold(
      backgroundColor: const Color(0xFF09090A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080809),
        title: const Text('Đồng hồ cước taxi, xe ôm',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Quản lý bảng giá cước',
            onPressed: _tariffDialog,
          ),
          PopupMenuButton<String>(
            tooltip: 'Tiện ích và cấu hình',
            onSelected: _showTools,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'vehicle',
                child: Text('Cài đặt xe và biển số')),
              PopupMenuItem(value: 'bank',
                child: Text('Tài khoản ngân hàng VietQR')),
              PopupMenuItem(value: 'quote',
                child: Text('Báo giá chuyến đi')),
              PopupMenuItem(value: 'qr',
                child: Text('Mã QR thanh toán')),
              PopupMenuItem(value: 'car',
                child: Text('Chế độ Car Mode / HUD trên điện thoại')),
              PopupMenuItem(value: 'toll',
                child: Text('Nhập phí BOT')),
              PopupMenuItem(value: 'locationPermission',
                child: Text('Quyền định vị “Luôn cho phép”')),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 20),
        children: [
          DashboardMap(
            latitude: _mapLat, longitude: _mapLon,
            routePoints: _routePoints,
            speedKmh: meter.speedKmh,
            speedLimitKmh: meter.tariff.speedLimitKmh,
            onLocate: _locateOnMap,
          ),
          const SizedBox(height: 9),
          _selectedCompanyCard(status),
          const SizedBox(height: 10),
          _mainFareCard(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _metricTile(
              label: 'Quãng đường',
              value: meter.distanceKm.toStringAsFixed(2) + ' km',
              icon: Icons.route)),
            Expanded(child: _metricTile(
              label: 'Tốc độ',
              value: meter.speedKmh.toStringAsFixed(1) + ' km/h',
              icon: Icons.speed)),
          ]),
          const SizedBox(height: 11),
          if (status == MeterStatus.idle)
            Column(children: [
              SizedBox(width: double.infinity, height: 58,
                child: FilledButton(
                  onPressed: _storageReady ? _start : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C953),
                    foregroundColor: Colors.white),
                  child: const Text('Bắt đầu',
                    style: TextStyle(fontSize: 19,
                      fontWeight: FontWeight.w800)),
                )),
              TextButton.icon(
                onPressed: _storageReady ? _flatFareDialog : null,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Báo giá chuyến đi / giá trọn gói')),
            ]),
          if (active) ...[
            Row(children: [
              Expanded(child: SizedBox(height: 58,
                child: FilledButton.icon(
                  onPressed: status == MeterStatus.paused
                      ? _resumeTrip
                      : () {
                          setState(() => meter.pause());
                          _checkpoint(force: true);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF982A),
                    foregroundColor: Colors.white),
                  icon: Icon(status == MeterStatus.paused
                      ? Icons.play_arrow : Icons.pause),
                  label: Text(status == MeterStatus.paused
                      ? 'Tiếp tục' : 'Tạm dừng',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ))),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 58,
                child: FilledButton(
                  onPressed: _finish,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4247),
                    foregroundColor: Colors.white),
                  child: const Text('Dừng lại',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ))),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _customTollDialog,
                  icon: const Icon(Icons.toll),
                  label: const Text('Nhập phí BOT'),
                ),
              ),
            ),
          ],
          if (status == MeterStatus.finished)
            SizedBox(width: double.infinity, height: 54,
              child: FilledButton.icon(
                onPressed: _pendingUnsaved == null
                  ? () {
                      setState(() {
                        meter.reset();
                        _routePoints.clear();
                        _routeSegment = 0;
                        _destinationController.clear();
                      });
                    }
                  : _saveCompletedRecord,
                icon: Icon(_pendingUnsaved == null
                  ? Icons.restart_alt : Icons.save),
                label: Text(_pendingUnsaved == null
                  ? 'Chuyến mới' : 'THỬ LƯU LẠI CHUYẾN'),
              )),
          if (meter.requiresManualResume)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Text('Chuyến đã tạm ngắt an toàn. '
                'Chỉ tiếp tục khi GPS đã sẵn sàng.',
                style: TextStyle(color: Color(0xFFFFA332))),
            ),
          if (active && !_trackingPolicy.hasTrustedFix &&
              !meter.requiresManualResume)
            const Text('Đang xác định GPS; chưa cộng cước chờ khi mất tín hiệu.',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
          if (_checkpointError != null)
            ListTile(
              title: const Text('Lỗi lưu trạng thái chuyến',
                style: TextStyle(color: Colors.redAccent)),
              subtitle: Text(_checkpointError!,
                maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                onPressed: () => setState(() {
                  _checkpointError = null;
                  _checkpoint(force: true);
                }),
                icon: const Icon(Icons.refresh)),
            ),
          if (active) ...[
            const SizedBox(height: 12),
            const Text('Chi tiết tính tiền',
              style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            FareBreakdownSection(
              tariff: meter.tariff,
              distanceKm: meter.distanceKm,
              tripStarted: true,
              showReachedOnly: true,
              totalFare: meter.totalFare,
              isFlatFare: meter.flatFare != null,
              waitingFare: meter.waitingFare,
              tollFee: meter.tollFee,
              surcharge: meter.surcharge,
              discount: meter.discount,
            ),
          ],
          const SizedBox(height: 6),
          const Center(child: Text(
            'Phiên bản thử nghiệm • Chưa sử dụng thu cước thương mại',
            style: TextStyle(color: Colors.white38, fontSize: 10))),
        ],
      )),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          backgroundColor: const Color(0xFF202023),
          indicatorColor: const Color(0xFF101014),
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) _showHistory();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed, color: Color(0xFF168FFF)),
              label: 'Đồng hồ cước',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Doanh thu',
            ),
          ],
        ),
      ),
    );
  }
}
