import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import 'src/core/taximeter_engine.dart';
import 'src/core/location_tracking_policy.dart';
import 'src/ui/fare_breakdown_section.dart';
import 'src/ui/quote_dialog.dart';
import 'src/data/trip_repository.dart';
import 'src/data/settings_backup_bundle.dart';
import 'src/data/unified_backup_bundle.dart';
import 'src/data/backup_difference_preview.dart';
import 'src/data/backup_settings_importer.dart';
import 'src/data/vietqr_merge_plan.dart';
import 'src/data/backup_import_postflight.dart';
import 'src/data/backup_import_journal.dart';
import 'src/data/pre_import_backup_vault.dart';
import 'src/data/backup_logo_asset.dart';
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
import 'src/ui/led_marquee_title.dart';
import 'src/ui/driver_pro_design.dart';
import 'src/ui/dashboard_preferences_dialog.dart';
import 'src/domain/dashboard_preferences.dart';
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
        title: 'TTX Driver Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: DriverProColors.cyan,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: DriverProColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: DriverProColors.backgroundDeep,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: DriverProColors.backgroundDeep,
            indicatorColor: const Color(0xFF0C3550),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: Colors.white)),
          ),
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
  double _headingDegrees = 0;
  DashboardPreferences _dashboardPrefs = const DashboardPreferences();
  bool _is3D = false;
  bool _enableSaved3DAfterFirstMapFrame = false;
  String? _startupError;
  final List<TripRoutePoint> _routePoints = [];
  int _routeSegment = 0;
  // Last successfully committed point count; may lag queued checkpoints.
  // Retrying from this index is idempotent because SQLite keys points by
  // sequence. Never advance it before the atomic transaction succeeds.
  int _persistedRouteCount = 0;
  bool _storageReady = false;
  bool _exportingBackup = false;
  bool _settingsBackupBusy = false;
  bool _unifiedBackupBusy = false;
  bool _importBackupBusy = false;
  bool _vaultExportBusy = false;
  String? _interruptedImportWarning;
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
  String _tripVehicleBrand = '';
  String _tripFareProfileName = '';
  final TextEditingController _destinationController = TextEditingController();
  Timer? _ticker;
  StreamSubscription<Position>? _gps;
  StreamSubscription<Position>? _previewGps;
  bool _previewGpsStarting = false;
  int _previewGpsGeneration = 0;
  DateTime _lastPreviewGpsAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  double _previewSpeedKmh = 0;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startPreviewGps());
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      _meterTick(now);
      _retryPreviewGpsIfNeeded(now);
    });
  }

  /// The preview is a foreground-only map aid, never a billing source.
  /// After a platform stream error, reattach periodically while idle and
  /// visible. Do not restart location tracking for a backgrounded activity.
  void _retryPreviewGpsIfNeeded(DateTime now) {
    if (!_appVisible || !_storageReady || _gps != null ||
        _previewGps != null || _previewGpsStarting ||
        (meter.status != MeterStatus.idle &&
         meter.status != MeterStatus.finished)) return;
    if (now.difference(_lastPreviewGpsAttempt) <
        const Duration(seconds: 15)) return;
    unawaited(_startPreviewGps());
  }

  /// Loading a journal never imports or rolls back data automatically.
  /// If a previous import was interrupted, keep a persistent warning
  /// until the same archive passes the full post-import verification.
  Future<void> _loadImportJournalStatus() async {
    try {
      final entry = await BackupImportJournal.read(
        await getApplicationSupportDirectory());
      if (!mounted) return;
      setState(() {
        _interruptedImportWarning = entry?.needsReview == true
            ? 'Có lần nhập bản sao chưa được xác nhận hoàn tất. '
              'Hãy lưu bản dự phòng trước nhập ra ngoài ứng dụng, '
              'sau đó chọn lại đúng tệp .ttxbackup để kiểm tra và tiếp tục. '
              'Ứng dụng không tự ghi đè hoặc hoàn tác dữ liệu.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _interruptedImportWarning =
            'Không đọc được nhật ký nhập bản sao. '
            'Dữ liệu hiện có được giữ nguyên; không nên nhập tệp khác '
            'trước khi kiểm tra bản dự phòng.';
      });
    }
  }

  Future<void> _initializeData() async {
    try {
      // Begin independent preferences reads while SQLite is opening.
      final dashboardFuture = store.getString(
        DashboardPreferences.storageKey).catchError((Object _) => null);
      final bankLegacyFuture = store.getString('ttx_vietqr_account_v1');
      final bankBookFuture = store.getString('ttx_vietqr_bank_book_v1');
      final vehicleFuture = store.getString('ttx_vehicle_v1');
      final tariffFuture = store.getString('ttx_tariff_v1');
      final catalogFuture = store.getString('ttx_tariff_catalog_v1');
      await repository.initializeAndMigrate(legacyPreferences: store);
      final encodedBank = await bankLegacyFuture;
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
      final savedBankBook = await bankBookFuture;
      if (savedBankBook != null) {
        try {
          bankBook = BankBook.decode(savedBankBook);
        } catch (_) {
          // Legacy account is retained if the newer account book is corrupted.
        }
      }
      VehicleRegistration? registration;
      final rawVehicle = await vehicleFuture;
      if (rawVehicle != null) {
        try {
          registration = VehicleRegistration.decode(rawVehicle);
        } catch (_) {
          // Never trust a malformed registration. Re-prompt explicitly.
        }
      }
      final savedTariff = await tariffFuture;
      if (savedTariff != null) {
        try {
          meter.updateTariff(TariffCodec.decode(savedTariff));
        } catch (_) {
          // Invalid stored tariff does not replace the validated preset.
        }
      }
      TariffCatalog catalog = TariffCatalog.initial(existing: meter.tariff);
      final savedCatalog = await catalogFuture;
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
        _tripVehicleBrand = restored.vehicleBrand;
        _tripFareProfileName = restored.fareProfileName;
        _routePoints.addAll(restored.routePoints);
        // Reconcile a recovered v2 or v3 route in the next transaction.
        // INSERT OR IGNORE makes the one-time replay safe for either format.
        _persistedRouteCount = 0;
        _routeSegment = _routePoints.isEmpty ? 0 :
            _routePoints.last.segment + 1;
        _destinationController.text = restored.dropoff;
        _gpsStatus = 'Chuyến cũ đã được tạm ngắt an toàn';
      }
      DashboardPreferences dashboardPrefs = const DashboardPreferences();
      try {
        final preferences = await dashboardFuture;
        if (preferences != null) {
          dashboardPrefs = DashboardPreferences.decode(preferences);
        }
      } catch (_) {
        // A bad presentation preference must never block fare recovery.
      }
      if (!mounted) return;
      setState(() {
        _dashboardPrefs = dashboardPrefs;
        // Paint a lightweight 2D frame first; native MapLibre can initialize
        // after position is known, avoiding a cold-start platform-view stall.
        _is3D = false;
        _enableSaved3DAfterFirstMapFrame =
            meter.status == MeterStatus.idle && dashboardPrefs.default3D;
        _startupError = null;
        _bankBook = bankBook;
        _vehicle = registration;
        _tariffCatalog = catalog;
        _storageReady = true;
      });
      unawaited(_loadImportJournalStatus());
      if (meter.status != MeterStatus.idle) await _stopPreviewGps();
      unawaited(CarStateBridge.publish(meter));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _storageReady &&
            _enableSaved3DAfterFirstMapFrame && _mapLat != null) {
          setState(() {
            _enableSaved3DAfterFirstMapFrame = false;
            _is3D = true;
          });
        }
      });
      // Request location at first launch; automatically center the map.
      // Registration comes later so two dialogs never overlap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_initialLocationSetup(
          needsVehicle: registration == null || registration.needsDetails,
        ));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _startupError = error.toString());
      _notify('Lỗi khởi tạo lịch sử SQLite: ' + error.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _gps?.cancel();
    _previewGps?.cancel();
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
        unawaited(_startPreviewGps());
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

  /// Map GPS preview is foreground-only and never calculates fare or route.
  Future<void> _startPreviewGps() async {
    if (!mounted || !_appVisible || _previewGps != null ||
        _previewGpsStarting || _gps != null ||
        (meter.status != MeterStatus.idle &&
         meter.status != MeterStatus.finished)) return;
    _previewGpsStarting = true;
    _lastPreviewGpsAttempt = DateTime.now();
    final generation = ++_previewGpsGeneration;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;
      if (!mounted || !_appVisible || _previewGps != null || _gps != null ||
          (meter.status != MeterStatus.idle &&
           meter.status != MeterStatus.finished)) return;
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              // Foreground-only preview refreshes the 3D map at 1 Hz.
              // This stream never contributes to meter distance.
              intervalDuration: const Duration(seconds: 1),
              distanceFilter: 1)
          : const LocationSettings(
              accuracy: LocationAccuracy.high, distanceFilter: 1);
      _previewGps = Geolocator.getPositionStream(
        locationSettings: settings).listen(
          (p) {
            if (generation == _previewGpsGeneration) _onPreviewFix(p);
          },
          onError: (Object error) {
            if (generation != _previewGpsGeneration) return;
            final failed = _previewGps;
            _previewGps = null;
            if (failed != null) unawaited(failed.cancel());
            if (mounted && _appVisible) {
              setState(() => _gpsStatus = 'GPS bản đồ: $error');
            }
          },
          onDone: () {
            if (generation == _previewGpsGeneration) _previewGps = null;
          },
        );
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && mounted &&
          generation == _previewGpsGeneration && _previewGps != null &&
          _mapLat == null) _onPreviewFix(cached, cached: true);
    } catch (error) {
      if (mounted && _appVisible &&
          generation == _previewGpsGeneration) {
        setState(() => _gpsStatus = 'Lỗi GPS bản đồ: $error');
      }
    } finally {
      _previewGpsStarting = false;
    }
  }

  void _onPreviewFix(Position p, {bool cached = false}) {
    if (!mounted || !_appVisible || _gps != null ||
        (meter.status != MeterStatus.idle &&
         meter.status != MeterStatus.finished)) return;
    if (!p.latitude.isFinite || !p.longitude.isFinite ||
        p.latitude.abs() > 90 || p.longitude.abs() > 180 ||
        !p.accuracy.isFinite || p.accuracy < 0 ||
        p.accuracy > 150) return;
    final age = DateTime.now().difference(p.timestamp);
    if (age.isNegative && age.abs() > const Duration(seconds: 5)) return;
    if (age > (cached
        ? const Duration(seconds: 45)
        : const Duration(seconds: 20))) return;
    setState(() {
      _mapLat = p.latitude;
      _mapLon = p.longitude;
      _previewSpeedKmh = p.speed.isFinite && p.speed > 0
          ? (p.speed * 3.6).clamp(0.0, 300.0).toDouble() : 0;
      if (p.heading.isFinite && p.heading >= 0 &&
          p.heading <= 360 && p.speed > 1.5) _headingDegrees = p.heading;
      _gpsStatus = 'GPS xem bản đồ ±' +
          p.accuracy.round().toString() + ' m';
      if (_storageReady && _enableSaved3DAfterFirstMapFrame) {
        _enableSaved3DAfterFirstMapFrame = false;
        _is3D = true;
      }
    });
  }

  Future<void> _stopPreviewGps() async {
    // Invalidate callbacks from any older stream or async acquisition.
    _previewGpsGeneration++;
    final previous = _previewGps;
    _previewGps = null;
    _previewSpeedKmh = 0;
    if (previous != null) {
      try {
        await previous.cancel();
      } catch (_) {
        // Preview failure must not affect taximeter accounting.
      }
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
      _applyVisibleState(() {
        meter.skipUntrustedInterval(now);
        meter.suspendForInterruption(at: now);
        _gpsStatus = reason;
      });
      _checkpoint(force: true);
    }
    unawaited(_stopGps());
  }

  /// Keep processing GPS while backgrounded without rebuilding the hidden
  /// widget tree. Billing, route storage and checkpoints are unchanged.
  void _applyVisibleState(VoidCallback update) {
    if (!mounted) return;
    if (_appVisible) {
      setState(update);
    } else {
      update();
    }
  }

  void _meterTick(DateTime now) {
    // A manual pause may accrue waiting, but only with reliable GPS.
    // An interruption never adds distance, elapsed time or waiting charges.
    final active = meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused;
    if (!active) return;
    final elapsedBefore = meter.elapsedSeconds;
    final waitingBefore = meter.waitingSeconds;
    final speedBefore = meter.speedKmh;
    final gpsStatusBefore = _gpsStatus;

    if (!meter.requiresManualResume && _trackingPolicy.shouldSuspend(now)) {
      // Keep the foreground location subscription alive; no fabricated
      // mileage, waiting or fare during Android GPS blackouts.
      if (_gps == null) {
        _suspendForGps('Dịch vụ GPS đã dừng: tạm ngắt tính cước');
        return;
      }
      meter.skipUntrustedInterval(now);
      _gpsStatus = 'GPS gián đoạn: đang chờ tín hiệu, không cộng cước';
    } else if (meter.requiresManualResume ||
        _trackingPolicy.hasRecentFix(now)) {
      meter.tick(now);
    } else {
      meter.skipUntrustedInterval(now);
    }

    // GPS may deliver several fixes in one second, yet the meter clock
    // advances only on whole seconds. Avoid rebuilding an unchanged view.
    if (_appVisible && mounted &&
        (meter.elapsedSeconds != elapsedBefore ||
         meter.waitingSeconds != waitingBefore ||
         meter.speedKmh != speedBefore || _gpsStatus != gpsStatusBefore)) {
      setState(() {});
    }
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
              // Request denser fixes; existing trusted-GPS safeguards
              // still decide whether any point can affect the fare.
              intervalDuration: const Duration(seconds: 1),
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
        final age = now.difference(position.timestamp);
        // Reject cached / future telemetry BEFORE changing billing or route.
        if (age.isNegative && age.abs() > const Duration(seconds: 3)) return;
        if (age > const Duration(seconds: 12)) return;
        final fix = GpsFix(
          latitude: position.latitude,
          longitude: position.longitude,
          speedKmh: position.speed * 3.6,
          accuracyMeters: position.accuracy,
          timestamp: position.timestamp,
        );
        if (!meter.isValidGpsObservation(fix)) {
          if (meter.status == MeterStatus.running &&
              _gpsStatus != 'GPS yếu / sai số: đang chờ tín hiệu') {
            _applyVisibleState(() =>
                _gpsStatus = 'GPS yếu / sai số: đang chờ tín hiệu');
          }
          return;
        }
        // Validate first: a rejected GPS sample must never reset the meter
        // baseline or fragment the recorded route.
        final recoveredAfterGap = _trackingPolicy.shouldSuspend(now);
        final firstFix = !_trackingPolicy.hasTrustedFix;
        if (recoveredAfterGap || firstFix) {
          // Discard any unobserved distance and waiting time.
          meter.skipUntrustedInterval(now);
        }
        final accepted = meter.acceptGps(fix);
        if (!accepted) {
          if (meter.status == MeterStatus.running &&
              _gpsStatus != 'GPS yếu / sai số: đang chờ tín hiệu') {
            _applyVisibleState(() =>
                _gpsStatus = 'GPS yếu / sai số: đang chờ tín hiệu');
          }
          return;
        }
        if (recoveredAfterGap && !firstFix) {
          _routeSegment++; // New segment only after a valid accepted fix.
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
        _applyVisibleState(() {
          _mapLat = position.latitude;
          _mapLon = position.longitude;
          if (position.heading.isFinite && position.heading >= 0 &&
              position.heading <= 360 && position.speed > 1.5) {
            _headingDegrees = position.heading;
          }
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
      // Refresh once with meter/GPS fixes accumulated while in background.
      if (mounted) setState(() {});
      if (meter.status == MeterStatus.idle ||
          meter.status == MeterStatus.finished) {
        unawaited(_startPreviewGps());
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) unawaited(_stopPreviewGps());
    if (state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused) return;
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) return;
    // Geolocator already runs a location-type Android foreground service.
    // Do not cancel it just because we leave while acquiring a GPS fix.
    // The watchdog suppresses untrusted billing; a valid fix may recover.
    if (_gps == null && !_gpsStarting) {
      _suspendForGps('Dịch vụ GPS không hoạt động khi ra nền');
    }
  }

  /// A checkpoint carries the meter/tariff only. The GPS route is stored as
  /// ordered SQLite rows instead of being copied/JSON-encoded every 3 seconds.
  TripSessionSnapshot _sessionSnapshot() =>
      TripSessionSnapshot.fromEngine(
    meter, pickup: _tripPickup, dropoff: _tripDropoff,
    vehicleType: _tripVehicleType,
    vehiclePlate: _tripVehiclePlate,
    vehicleBrand: _tripVehicleBrand,
    fareProfileName: _tripFareProfileName,
  );

  /// Freeze vehicle and fare profile at trip start.
  void _captureTripMetadata() {
    _tripVehicleType = _vehicle?.category.label ?? '';
    _tripVehiclePlate = _vehicle?.plate ?? '';
    _tripVehicleBrand = _vehicle?.brand ?? '';
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
    // Capture ONLY the new points at the exact same instant as the meter.
    // If a pending checkpoint fails, the last committed index is unchanged,
    // and the next checkpoint automatically resends all missing samples.
    final snapshot = _sessionSnapshot();
    final firstIndex = _persistedRouteCount;
    final finalIndex = _routePoints.length;
    final appendedPoints = List<TripRoutePoint>.unmodifiable(
      _routePoints.sublist(firstIndex, finalIndex));
    _writeQueue = _writeQueue.then((_) async {
      await repository.saveActiveIncremental(
        snapshot: snapshot,
        routeStartIndex: firstIndex,
        appendedPoints: appendedPoints,
      );
      if (finalIndex > _persistedRouteCount) {
        _persistedRouteCount = finalIndex;
      }
      _checkpointError = null;
      await CarStateBridge.publish(meter);
    }).catchError((Object error) {
      _checkpointError = error.toString();
    });
  }

  Future<bool> _saveNewTrip() async {
    if (_importBackupBusy) return false;
    _savingNewTrip = true;
    try {
      await _writeQueue;
      await repository.beginActive(_sessionSnapshot());
      _persistedRouteCount = 0;
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
    if (meter.status != MeterStatus.idle || !_storageReady ||
        _importBackupBusy) return;
    if ((_vehicle == null || _vehicle!.needsDetails) &&
        !await _configureVehicle()) return;
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
      _persistedRouteCount = 0;
      meter.start(at: now);
    });
    _trackingPolicy.begin(now);
    if (!await _saveNewTrip()) {
      if (mounted) setState(meter.reset);
      _trackingPolicy.clear();
      return;
    }
    if (mounted) {
      await _stopPreviewGps();
      if (mounted) await _enableGps();
      if (mounted && meter.status == MeterStatus.running &&
          _dashboardPrefs.auto3DOnStart) {
        setState(() => _is3D = true);
      }
    }
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
    if (_gps == null) {
      await _stopPreviewGps();
      if (mounted) await _enableGps();
    }
    if (mounted && meter.status == MeterStatus.running &&
        _dashboardPrefs.auto3DOnStart) {
      setState(() => _is3D = true);
    }
  }

  Future<void> _finish() async {
    if (meter.status != MeterStatus.running &&
        meter.status != MeterStatus.paused) return;
    final finished = meter.finish();
    await _stopGps();
    final record = TripRecord.fromReceipt(
      finished,
      pickup: _tripPickup, dropoff: _tripDropoff,
      vehicleType: _tripVehicleType,
      vehiclePlate: _tripVehiclePlate,
      vehicleBrand: _tripVehicleBrand,
      fareProfileName: _tripFareProfileName,
      tariffSnapshot: meter.tariff,
      routePoints: _routePoints);
    setState(() {
      _is3D = false; // End-of-trip map always returns to overhead 2D.
      _pendingUnsaved = record;
    });
    await _saveCompletedRecord();
    if (mounted && _appVisible) unawaited(_startPreviewGps());
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
          _is3D = false;
          _destinationController.clear();
        });
        if (mounted && _appVisible) unawaited(_startPreviewGps());
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
    if (meter.status != MeterStatus.idle || !_storageReady ||
        _importBackupBusy) {
      _notify('Hoàn thành chuyến hiện tại và chờ dữ liệu sẵn sàng trước khi báo giá');
      return;
    }
    if ((_vehicle == null || _vehicle!.needsDetails) &&
        !await _configureVehicle()) return;
    if (!mounted || meter.status != MeterStatus.idle) return;
    final quote = await showDialog<QuoteResult>(
      context: context,
      builder: (context) => QuoteDialog(tariff: meter.tariff),
    );
    if (!mounted || quote == null || quote.amount <= 0) return;
    if (!await _requestLocationReady()) return;
    if (!mounted || !_appVisible || meter.status != MeterStatus.idle ||
        _importBackupBusy) return;
    final now = DateTime.now();
    _tripPickup = quote.pickup;
    _tripDropoff = quote.dropoff;
    _destinationController.text = quote.dropoff;
    _captureTripMetadata();
    setState(() {
      _routePoints.clear();
      _routeSegment = 0;
      _persistedRouteCount = 0;
      meter.start(at: now, fixedFare: quote.amount);
    });
    _trackingPolicy.begin(now);
    if (!await _saveNewTrip()) {
      if (mounted) setState(meter.reset);
      _trackingPolicy.clear();
      return;
    }
    if (mounted) {
      await _stopPreviewGps();
      if (mounted) await _enableGps();
      if (mounted && meter.status == MeterStatus.running &&
          _dashboardPrefs.auto3DOnStart) {
        setState(() => _is3D = true);
      }
    }
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

  bool get _canChangeFare =>
      meter.status == MeterStatus.idle && !_importBackupBusy;

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
    if (!mounted) return;
    if (meter.status == MeterStatus.idle ||
        meter.status == MeterStatus.finished) {
      await _startPreviewGps();
    } else if (_gps == null) {
      await _refreshMapLocation();
    }
  }

  void _showHistory() {
    if (_importBackupBusy) {
      _notify('Đang nhập bản sao lưu; không mở lịch sử cho đến khi hoàn tất.');
      return;
    }
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
      _notify('Đã lưu xe ' + registration.brand + ': ' + registration.plate);
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

  Widget _selectedCompanyCard(MeterStatus status) {
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    final label = status == MeterStatus.idle || _tripFareProfileName.isEmpty
        ? _tariffCatalog.active.label : _tripFareProfileName;
    return InkWell(
      key: const Key('fare-profile-selector'),
      onTap: _showTariffSelector,
      borderRadius: BorderRadius.circular(17),
      child: DriverProPanel(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(children: [
          const Icon(Icons.local_taxi_rounded,
            color: DriverProColors.amber, size: 25),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bảng giá: $label', maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              if (status == MeterStatus.idle)
                Text('Mở cửa: ${vnd(meter.tariff.baseFare)}',
                  style: const TextStyle(
                    fontSize: 12, color: DriverProColors.muted)),
              if (active)
                Text('Đang áp dụng • Không đổi giá giữa chuyến',
                  style: const TextStyle(
                    fontSize: 11, color: DriverProColors.muted)),
              if (status == MeterStatus.finished)
                const Text('Biểu giá đã chốt cho chuyến',
                  style: TextStyle(
                    fontSize: 11, color: DriverProColors.muted)),
            ],
          )),
          const Icon(Icons.chevron_right,
            color: DriverProColors.cyan, size: 23),
        ]),
      ),
    );
  }

  Widget _gpsStatusStrip(MeterStatus status) {
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    final hasPosition = _mapLat != null && _mapLon != null;
    final trusted = active
        ? _trackingPolicy.hasRecentFix(DateTime.now()) && !meter.requiresManualResume
        : hasPosition;
    final label = trusted
        ? (active ? 'GPS đang theo dõi chuyến' : 'Đã có vị trí GPS')
        : _gpsStatus;
    return Container(
      key: const Key('driver-pro-gps-status'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: trusted ? const Color(0xFF073622)
            : const Color(0xFF33260D),
        border: Border.all(
          color: trusted ? const Color(0xFF008E50)
              : const Color(0xFF94661F)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        Icon(trusted ? Icons.satellite_alt_rounded
            : Icons.gps_not_fixed_rounded,
          color: trusted ? DriverProColors.green
              : DriverProColors.amber, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: trusted ? const Color(0xFFD2FFE2)
                : const Color(0xFFFFDC92)))),
        Icon(trusted ? Icons.signal_cellular_alt_rounded
            : Icons.signal_cellular_off_rounded,
          color: trusted ? DriverProColors.green
              : DriverProColors.amber, size: 19),
      ]),
    );
  }

  Widget _tripMetrics(MeterStatus status) {
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused || status == MeterStatus.finished;
    final speed = status == MeterStatus.running ||
        status == MeterStatus.paused
            ? meter.speedKmh : _previewSpeedKmh;
    return Row(children: [
      Expanded(child: DriverProMetricCard(
        label: 'Quãng đường',
        value: '${meter.distanceKm.toStringAsFixed(active ? 1 : 2)} km',
        icon: Icons.route_rounded)),
      const SizedBox(width: 7),
      if (active) ...[
        Expanded(child: DriverProMetricCard(
          label: 'Thời gian',
          value: '${meter.elapsedSeconds ~/ 60} phút',
          icon: Icons.access_time_rounded)),
        const SizedBox(width: 7),
        Expanded(child: DriverProMetricCard(
          label: 'Chờ tính phí',
          value: '${meter.waitingSeconds ~/ 60} phút',
          icon: Icons.local_taxi_rounded)),
      ] else
        Expanded(child: DriverProMetricCard(
          label: 'Tốc độ GPS',
          value: '${speed.toStringAsFixed(1)} km/h',
          icon: Icons.speed_rounded)),
    ]);
  }

  Widget _mainFareCard() => DriverProFareCard(
    amount: vnd(meter.totalFare), status: meter.status);

  Widget _botQuickAction() => InkWell(
    key: const Key('driver-pro-bot-action'),
    onTap: _customTollDialog,
    borderRadius: BorderRadius.circular(14),
    child: DriverProPanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(children: [
        const Icon(Icons.toll_outlined,
          color: DriverProColors.cyan, size: 20),
        const SizedBox(width: 9),
        const Expanded(child: Text('Trạm thu phí (BOT)',
          style: TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w700))),
        Text(vnd(meter.tollFee),
          style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        const Icon(Icons.chevron_right_rounded,
          color: DriverProColors.cyan, size: 21),
      ]),
    ),
  );

  Widget _primaryTripActions(MeterStatus status) {
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    if (status == MeterStatus.idle) {
      return SizedBox(width: double.infinity,
        child: DriverProAction(
          label: 'Bắt đầu', icon: Icons.play_arrow_rounded,
          color: DriverProColors.green, darkText: true,
          onPressed: _storageReady ? _start : null));
    }
    if (active) {
      return Row(children: [
        Expanded(child: DriverProAction(
          label: status == MeterStatus.paused
              ? 'Tiếp tục' : 'Tạm dừng',
          icon: status == MeterStatus.paused
              ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: DriverProColors.amber,
          darkText: true,
          onPressed: status == MeterStatus.paused
              ? _resumeTrip
              : () {
                  setState(() => meter.pause());
                  _checkpoint(force: true);
                },
        )),
        const SizedBox(width: 9),
        Expanded(child: DriverProAction(
          label: 'Kết thúc',
          icon: Icons.stop_rounded,
          color: DriverProColors.red,
          onPressed: _finish,
        )),
      ]);
    }
    return SizedBox(width: double.infinity, child: DriverProAction(
      label: _pendingUnsaved == null
          ? 'Chuyến mới' : 'THỬ LƯU LẠI CHUYẾN',
      icon: _pendingUnsaved == null
          ? Icons.restart_alt_rounded : Icons.save_rounded,
      color: DriverProColors.green,
      darkText: true,
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
    ));
  }

  Future<void> _persistDashboardSettings(
      DashboardPreferences next) async {
    try {
      await store.setString(DashboardPreferences.storageKey, next.encode());
    } catch (error) {
      if (mounted) _notify('Không lưu được cài đặt giao diện: ' + error.toString());
    }
  }

  void _toggleMap3D() {
    final next = !_is3D;
    final settings = _dashboardPrefs.copyWith(default3D: next);
    setState(() {
      _enableSaved3DAfterFirstMapFrame = false;
      _is3D = next;
      _dashboardPrefs = settings;
    });
    unawaited(_persistDashboardSettings(settings));
  }

  void _toggleMapDark() {
    final settings = _dashboardPrefs.copyWith(darkMap: !_dashboardPrefs.darkMap);
    setState(() => _dashboardPrefs = settings);
    unawaited(_persistDashboardSettings(settings));
  }

  Future<void> _editDashboardPreferences() async {
    if (!mounted) return;
    final chosen = await showDialog<DashboardPreferences>(
      context: context,
      builder: (dialogContext) => DashboardPreferencesDialog(
        initial: _dashboardPrefs,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _dashboardPrefs = chosen;
      _enableSaved3DAfterFirstMapFrame = false;
      if (meter.status == MeterStatus.idle) _is3D = chosen.default3D;
    });
    await _persistDashboardSettings(chosen);
  }

  /// User-initiated, export-only protection for completed trip history.
  /// Preferences (tariffs, bank accounts, branding) are stored elsewhere and
  /// are intentionally NOT claimed to be part of this SQLite-only snapshot.
  Future<void> _backupHistory() async {
    if (_exportingBackup) return;
    if (!_storageReady || _savingNewTrip || _pendingUnsaved != null ||
        meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused) {
      _notify('Chỉ sao lưu sau khi chuyến đã kết thúc và lưu thành công.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sao lưu lịch sử chuyến đi'),
        content: const Text('Tạo một bản sao SQLite gồm lịch sử, hóa đơn và '
          'dữ liệu chuyến đã lưu. Bản sao không bao gồm tài khoản VietQR, '
          'cài đặt xe hoặc bảng giá trong bộ nhớ tùy chọn. '
          'Tệp có thể chứa thông tin chuyến đi nhạy cảm: chỉ lưu ở nơi '
          'bạn tin cậy. Chức năng khôi phục chưa được triển khai.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chọn nơi lưu')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _exportingBackup = true);
    File? temporary;
    try {
      // Flush queued checkpoints before a consistent SQLite snapshot.
      await _writeQueue;
      if (meter.status == MeterStatus.running ||
          meter.status == MeterStatus.paused ||
          _pendingUnsaved != null) {
        throw StateError('Chuyến đang hoạt động hoặc chưa lưu xong');
      }
      temporary = await repository.createVerifiedBackup(
        destinationDirectory: await getTemporaryDirectory());
      // FilePicker.saveFile currently accepts bytes, so bound peak RAM
      // instead of risking process termination on an enormous history DB.
      const maxInMemoryBackupBytes = 64 * 1024 * 1024;
      if (await temporary.length() > maxInMemoryBackupBytes) {
        throw StateError('Bản sao lớn hơn 64 MB; chưa thể xuất an toàn '
            'bằng bộ chọn tệp hiện tại.');
      }
      final date = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final fileName = 'TTX_DriverPro_SQLite_'
          '${date.year}${two(date.month)}${two(date.day)}_'
          '${two(date.hour)}${two(date.minute)}${two(date.second)}.db';
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Lưu bản sao SQLite TTX Driver Pro',
        fileName: fileName,
        bytes: await temporary.readAsBytes(),
      );
      if (!mounted) return;
      _notify(destination == null
        ? 'Đã hủy lưu bản sao; lịch sử trên máy không đổi.'
        : 'Đã xuất bản sao lịch sử. Hãy giữ tệp ở nơi an toàn.');
    } catch (error) {
      if (mounted) _notify('Không tạo được bản sao: ${error.toString()}');
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      if (mounted) setState(() => _exportingBackup = false);
    }
  }

  /// Exports the exact app-managed JSON settings stored in preferences.
  /// This intentionally excludes the local SQLite history, Android runtime
  /// permissions and external logo files (the bank book stores logo paths).
  Future<void> _backupSettings() async {
    if (_settingsBackupBusy) return;
    if (!_storageReady || _savingNewTrip ||
        meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused) {
      _notify('Hãy hoàn tất chuyến trước khi sao lưu cấu hình.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sao lưu cấu hình ứng dụng'),
        content: const Text(
          'Xuất bảng giá, thông tin xe, thiết lập bản đồ và tài khoản VietQR '
          'đã lưu thành tệp JSON riêng. '
          'Tệp chứa thông tin tài khoản ngân hàng ở dạng văn bản, '
          'không mã hóa: chỉ lưu ở vị trí riêng tư đáng tin cậy. '
          'Tệp này không chứa lịch sử SQLite hoặc ảnh logo; '
          'để lưu lịch sử, cần xuất thêm bản sao SQLite. '
          'Chưa hỗ trợ nhập/khôi phục tự động.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xuất cấu hình')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _settingsBackupBusy = true);
    try {
      final backup = await SettingsBackupBundle.capture(store);
      final encoded = Uint8List.fromList(utf8.encode(backup.encode()));
      final date = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final filename = 'TTX_DriverPro_CauHinh_'
          '${date.year}${two(date.month)}${two(date.day)}_'
          '${two(date.hour)}${two(date.minute)}${two(date.second)}.json';
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Lưu bản sao cấu hình TTX Driver Pro',
        fileName: filename,
        bytes: encoded,
      );
      if (!mounted) return;
      _notify(destination == null
        ? 'Đã hủy sao lưu cấu hình; dữ liệu trên máy không thay đổi.'
        : 'Đã xuất cấu hình (${backup.settings.length} nhóm). '
          'Hãy cất giữ cùng bản sao SQLite, không chia sẻ công khai.');
    } catch (error) {
      if (mounted) _notify('Không xuất được cấu hình: $error');
    } finally {
      if (mounted) setState(() => _settingsBackupBusy = false);
    }
  }

  /// Preflight only: parse and validate an exported settings file.
  /// Never writes SharedPreferences or applies any imported setting.
  Future<void> _inspectSettingsBackup() async {
    if (_settingsBackupBusy) return;
    setState(() => _settingsBackupBusy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null) return;
      final length = picked.lengthSync() ?? await picked.length();
      if (length == null ||
          length <= 0 ||
          length > SettingsBackupBundle.maxExportBytes) {
        throw const FormatException('Tệp cấu hình trống hoặc vượt 256 KB');
      }
      final bytes = await picked.readAsBytes();
      if (bytes.length > SettingsBackupBundle.maxExportBytes) {
        throw const FormatException('Tệp cấu hình vượt 256 KB');
      }
      final preview = SettingsBackupBundle.decode(
        utf8.decode(bytes, allowMalformed: false));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bản sao cấu hình hợp lệ'),
          content: Text(
            'Thời điểm tạo (UTC): ${preview.exportedAtUtc.toIso8601String()}\n'
            'Số nhóm cấu hình: ${preview.settings.length}\n'
            'Thông tin VietQR: ${preview.includesVietQr ? "Có" : "Không"}\n\n'
            'Đây chỉ là kiểm tra cấu trúc tệp; chưa khôi phục dữ liệu. '
            'Các đường dẫn logo (nếu có) không chứa ảnh logo gốc. '
            'Không gỡ ứng dụng cho đến khi có công cụ khôi phục được thử nghiệm.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _notify('Tệp sao lưu cấu hình không hợp lệ: $error');
    } finally {
      if (mounted) setState(() => _settingsBackupBusy = false);
    }
  }

  /// An export-only archive containing SQLite, preferences and app-owned logos.
  /// Android permissions and non-app files remain outside this format.
  Future<void> _backupCombined() async {
    if (_unifiedBackupBusy || _exportingBackup || _settingsBackupBusy) return;
    if (!_storageReady || _savingNewTrip || _pendingUnsaved != null ||
        meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused) {
      _notify('Hãy kết thúc và lưu chuyến trước khi xuất gói sao lưu.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sao lưu gộp dữ liệu TTX'),
        content: const Text(
          'Xuất một tệp .ttxbackup gồm SQLite (hóa đơn, lịch sử, GPS) '
          'và cấu hình JSON (bảng giá, thông tin xe, VietQR, bản đồ). '
          'Gói có SHA-256 phát hiện lỗi dữ liệu nhưng KHÔNG mã hóa. '
          'Tài khoản ngân hàng và lịch sử vị trí có thể đọc được, '
          'nên chỉ lưu ở nơi riêng tư đáng tin cậy. '
          'Ảnh logo VietQR đã lưu trong ứng dụng sẽ được đóng gói, '
          'nhưng quyền Android và dữ liệu khác ngoài ứng dụng thì không. '
          'Chưa có chức năng khôi phục hoặc chuyển chữ ký APK an toàn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chọn nơi lưu')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unifiedBackupBusy = true);
    File? sqliteCopy;
    try {
      await _writeQueue;
      if (!_storageReady || _savingNewTrip || _pendingUnsaved != null ||
          meter.status == MeterStatus.running ||
          meter.status == MeterStatus.paused) {
        throw StateError('Chuyến chưa hoàn tất hoặc chưa lưu xong');
      }
      final preferences = await SettingsBackupBundle.capture(store);
      final rawBankBook = preferences.settings['ttx_vietqr_bank_book_v1'];
      final logos = await BackupLogoCapture.fromBankBook(
        bankBook: rawBankBook == null
            ? const BankBook() : BankBook.decode(rawBankBook),
        appSupportDirectory: await getApplicationSupportDirectory(),
      );
      sqliteCopy = await repository.createVerifiedBackup(
        destinationDirectory: await getTemporaryDirectory());
      if (await sqliteCopy.length() > UnifiedBackupBundle.maxSqliteBytes) {
        throw StateError('SQLite lớn hơn 64 MiB, chưa hỗ trợ sao lưu gộp');
      }
      final bundle = UnifiedBackupBundle.fromParts(
        settings: preferences,
        sqliteBytes: await sqliteCopy.readAsBytes(),
        logos: logos);
      final date = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final filename = 'TTX_DriverPro_DuLieu_'
          '${date.year}${two(date.month)}${two(date.day)}_'
          '${two(date.hour)}${two(date.minute)}${two(date.second)}.ttxbackup';
      final selected = await FilePicker.saveFile(
        dialogTitle: 'Xuất dữ liệu chính TTX Driver Pro',
        fileName: filename,
        bytes: bundle.encode(),
      );
      if (!mounted) return;
      _notify(selected == null
        ? 'Đã hủy xuất tệp, dữ liệu trên điện thoại giữ nguyên.'
        : 'Đã xuất gói dữ liệu kèm ${logos.length} logo VietQR. '
          'Hãy cất giữ riêng tư và kiểm tra lại tệp.');
    } catch (error) {
      if (mounted) _notify('Sao lưu gộp không thành công: $error');
    } finally {
      if (sqliteCopy != null && await sqliteCopy.exists()) {
        await sqliteCopy.delete();
      }
      if (mounted) setState(() => _unifiedBackupBusy = false);
    }
  }

  /// Read-only preflight of the combined format. Never applies preferences,
  /// replaces the application's SQLite, or modifies any trip.
  Future<void> _inspectCombinedBackup() async {
    if (_unifiedBackupBusy || _exportingBackup || _settingsBackupBusy) return;
    if (meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused) {
      _notify('Hãy kết thúc chuyến trước khi mở trình kiểm tra sao lưu.');
      return;
    }
    setState(() => _unifiedBackupBusy = true);
    Directory? scratch;
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['ttxbackup']);
      if (selected == null) return;
      final length = selected.lengthSync() ?? await selected.length();
      if (length == null || length <= 0 ||
          length > UnifiedBackupBundle.maxBundleBytes) {
        throw const FormatException('Gói sao lưu trống hoặc quá dung lượng cho phép');
      }
      final bytes = await selected.readAsBytes();
      if (bytes.length > UnifiedBackupBundle.maxBundleBytes) {
        throw const FormatException('Gói sao lưu quá lớn');
      }
      final bundle = UnifiedBackupBundle.decode(bytes);
      scratch = await (await getTemporaryDirectory())
          .createTemp('ttx-backup-inspect-');
      final candidate = File('${scratch.path}/candidate.db');
      await candidate.writeAsBytes(bundle.sqliteBytes, flush: true);
      final verification = await TripRepository.inspectBackupFile(candidate);
      // Snapshot currently installed records separately; no values are
      // imported or overwritten as part of this read-only preview.
      final device = await repository.inspectCurrentData();
      final deviceSettings = await SettingsBackupBundle.capture(store);
      final comparison = BackupDifferencePreview.compare(
        archive: verification,
        device: device,
        archiveSettings: bundle.settings,
        deviceSettings: deviceSettings,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kiểm tra và đối chiếu bản sao'),
          content: SingleChildScrollView(child: Text(
            'Ngày tạo (UTC): ${bundle.createdAtUtc.toIso8601String()}\n'
            'Hóa đơn/chuyến đã lưu: ${verification.completedTripCount}\n'
            'Chuyến đang lưu dở: ${verification.hasActiveTrip ? "Có" : "Không"}\n'
            'Điểm GPS đang lưu: ${verification.activeRouteCount}\n'
            'Nhóm cấu hình: ${bundle.settings.settings.length}\n'
            'Có dữ liệu VietQR: ${bundle.settings.includesVietQr ? "Có" : "Không"}\n'
            'Logo VietQR đi kèm: ${bundle.logos.length}\n\n'
            'Đã kiểm tra SHA-256 và cấu trúc SQLite. Đây KHÔNG phải '
            'xác minh tác giả, mã hóa hay thử nghiệm khôi phục.\n\n'
            'ĐỐI CHIẾU VỚI DỮ LIỆU ĐANG CÓ TRÊN MÁY\n'
            'Chuyến chỉ có trong bản sao: ${comparison.archiveOnlyTrips}\n'
            'Chuyến chỉ có trên máy: ${comparison.deviceOnlyTrips}\n'
            'Hóa đơn trùng mã, khác dữ liệu: ${comparison.changedTripPayloads}\n'
            'Hóa đơn giống nhau: ${comparison.identicalTrips}\n'
            'Nhóm cấu hình chỉ có trong bản sao: ${comparison.archiveOnlySettings}\n'
            'Nhóm cấu hình chỉ có trên máy: ${comparison.deviceOnlySettings}\n'
            'Nhóm cấu hình khác nhau: ${comparison.changedSettings}\n'
            'Chuyến dở dang trong bản sao: ${comparison.archiveActiveTrip ? "Có" : "Không"}\n'
            'Chuyến dở dang trên máy: ${comparison.deviceActiveTrip ? "Có" : "Không"}\n\n'
            'CẢNH BÁO: ${comparison.hasTripConflicts ? "Có dữ liệu trên máy phải bảo vệ" : "Không phát hiện xung đột theo mã chuyến"}'
            '. Đây chỉ là đánh giá sơ bộ, chưa cấp quyền khôi phục. '
            'KHÔNG có dữ liệu nào bị thay đổi.')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _notify('Không kiểm tra được gói sao lưu: $error');
    } finally {
      if (scratch != null && await scratch.exists()) {
        await scratch.delete(recursive: true);
      }
      if (mounted) setState(() => _unifiedBackupBusy = false);
    }
  }

  /// Additive, user-confirmed restore from a verified .ttxbackup file.
  /// No existing receipt, active GPS checkpoint or saved setting is replaced.
  /// Pre-import safety archives are kept privately in app support storage.
  Future<void> _importCombinedBackup() async {
    if (_importBackupBusy || _unifiedBackupBusy ||
        _exportingBackup || _settingsBackupBusy) return;
    if (!_storageReady || _savingNewTrip || _pendingUnsaved != null ||
        meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused) {
      _notify('Hãy kết thúc và lưu chuyến trước khi nhập bản sao.');
      return;
    }
    setState(() => _importBackupBusy = true);
    Directory? scratch;
    File? safeSqlite;
    bool changesMayHaveStarted = false;
    BackupImportJournalEntry? importJournal;
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['ttxbackup']);
      if (selected == null) return;
      final fileSize = selected.lengthSync() ?? await selected.length();
      if (fileSize == null || fileSize <= 0 ||
          fileSize > UnifiedBackupBundle.maxBundleBytes) {
        throw const FormatException('Gói sao lưu trống hoặc quá dung lượng');
      }
      final bytes = await selected.readAsBytes();
      if (bytes.length > UnifiedBackupBundle.maxBundleBytes) {
        throw const FormatException('Gói sao lưu vượt giới hạn');
      }
      final archive = UnifiedBackupBundle.decode(bytes);
      final archiveDigest = sha256.convert(bytes).toString();
      final support = await getApplicationSupportDirectory();
      final priorJournal = await BackupImportJournal.read(support);
      if (priorJournal != null && priorJournal.needsReview &&
          priorJournal.archiveSha256 != archiveDigest) {
        throw StateError('Có lần nhập dở dang từ bản sao khác. '
          'Hãy xuất bản dự phòng rồi chọn lại đúng tệp sao lưu trước đó.');
      }
      scratch = await (await getTemporaryDirectory())
          .createTemp('ttx-import-staging-');
      final extractedDb = File('${scratch.path}/incoming.db');
      await extractedDb.writeAsBytes(archive.sqliteBytes, flush: true);
      final inspected = await TripRepository.inspectBackupFile(extractedDb);
      final live = await repository.inspectCurrentData();
      if (live.hasActiveTrip) {
        throw StateError('Máy còn chuyến GPS chưa hoàn tất: không nhập');
      }
      final liveSettings = await SettingsBackupBundle.capture(store);
      final preview = BackupDifferencePreview.compare(
        archive: inspected,
        device: live,
        archiveSettings: archive.settings,
        deviceSettings: liveSettings);
      final incomingBookRaw = archive.settings.settings['ttx_vietqr_bank_book_v1'];
      final deviceBookRaw = liveSettings.settings['ttx_vietqr_bank_book_v1'];
      final vietQrPlan = incomingBookRaw == null
          ? VietQrMergePlan.compare(
              device: const BankBook(), archive: const BankBook(),
              logos: const [])
          : VietQrMergePlan.compare(
              device: deviceBookRaw == null
                ? const BankBook() : BankBook.decode(deviceBookRaw),
              archive: BankBook.decode(incomingBookRaw),
              logos: archive.logos);
      if (preview.archiveOnlyTrips == 0 &&
          preview.archiveOnlySettings == 0 &&
          !vietQrPlan.hasChanges &&
          (priorJournal == null || !priorJournal.needsReview)) {
        // Prior app versions could have persisted VietQR to preferences but
        // left the already-running UI with a stale empty BankBook.
        if (deviceBookRaw != null && mounted) {
          setState(() => _bankBook = BankBook.decode(deviceBookRaw));
        }
        _notify('Không có dữ liệu mới cần nhập. '
          'Đã đồng bộ lại tài khoản VietQR nếu có trên máy.');
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nhập bổ sung bản sao lưu'),
          content: SingleChildScrollView(child: Text(
            'Gói sao lưu đã qua kiểm tra SHA-256, cấu trúc SQLite và '
            'hóa đơn.\n\n'
            'Sẽ bổ sung: ${preview.archiveOnlyTrips} chuyến đi và tối đa '
            '${preview.archiveOnlySettings} nhóm cấu hình.\n'
            'Tài khoản VietQR sẽ bổ sung: ${vietQrPlan.accountsToAdd}\n'
            'Logo VietQR sẽ khôi phục: ${vietQrPlan.logoSlotsToAdd.length}\n'
            'Không thay thế: ${preview.changedTripPayloads} hóa đơn '
            'trùng mã nhưng khác dữ liệu; '
            '${preview.deviceOnlyTrips} chuyến chỉ có trên máy.\n'
            'Bỏ qua chuyến chưa hoàn tất trong bản sao: '
            '${inspected.hasActiveTrip ? "Có" : "Không"}.\n\n'
            'Chỉ cài đặt các cấu hình chưa có trên máy; không thay '
            'bảng giá, tài khoản VietQR hay thiết lập hiện hành. '
            'Logo sẽ nhập nếu danh bạ VietQR còn trống.\n\n'
            'Trước khi nhập, ứng dụng tạo một bản sao an toàn của '
            'dữ liệu đang có trong thư mục riêng của ứng dụng. '
            'Bạn có thể xuất bản sao này ra ngoài sau khi nhập '
            'qua mục Xuất bản dự phòng trước khi nhập. '
            'Bản sao KHÔNG được khôi phục tự động khi có lỗi. '
            'Không thể hoàn tác toàn bộ thao tác bằng một nút. '
            'Việc nhập lại cùng tệp có thể tiếp tục các mục còn thiếu. '
            'Bạn cần mở lại ứng dụng để áp dụng cấu hình mới.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận nhập bổ sung')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await _writeQueue;
      if (!_storageReady || _savingNewTrip || _pendingUnsaved != null ||
          meter.status == MeterStatus.running ||
          meter.status == MeterStatus.paused ||
          (await repository.inspectCurrentData()).hasActiveTrip) {
        throw StateError('Trạng thái chuyến thay đổi; đã hủy nhập an toàn');
      }

      // Persist and verify a private pre-import recovery snapshot FIRST.
      // Import is non-destructive, but this retains an independent baseline.
      final safetyDir = Directory(
        '${support.path}/ttx_pre_import_safety');
      await safetyDir.create(recursive: true);
      if (!path.isWithin(
          await support.resolveSymbolicLinks(),
          await safetyDir.resolveSymbolicLinks())) {
        throw const FormatException('Thư mục dự phòng không an toàn');
      }
      final currentSettings = await SettingsBackupBundle.capture(store);
      final existingBook = currentSettings
          .settings['ttx_vietqr_bank_book_v1'];
      final currentLogos = await BackupLogoCapture.fromBankBook(
        bankBook: existingBook == null
            ? const BankBook() : BankBook.decode(existingBook),
        appSupportDirectory: support);
      safeSqlite = await repository.createVerifiedBackup(
        destinationDirectory: scratch);
      if (await safeSqlite.length() > UnifiedBackupBundle.maxSqliteBytes) {
        throw StateError('SQLite hiện có lớn hơn 64 MiB; không thể '
          'tạo bản sao trước khi nhập');
      }
      final recovery = UnifiedBackupBundle.fromParts(
        settings: currentSettings,
        sqliteBytes: await safeSqlite.readAsBytes(),
        logos: currentLogos);
      final checkpoint = File(
        '${safetyDir.path}/truoc_nhap_'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.ttxbackup');
      // A process crash cannot expose a half-written .ttxbackup as a valid
      // vault entry: only publish it after checksums pass.
      final pendingCopy = File('${checkpoint.path}.tmp');
      try {
        if (await checkpoint.exists() || await pendingCopy.exists()) {
          throw StateError('Tên bản dự phòng đã tồn tại; không ghi đè');
        }
        await pendingCopy.writeAsBytes(recovery.encode(), flush: true);
        final confirmedCopy = UnifiedBackupBundle.decode(
          await pendingCopy.readAsBytes());
        if (confirmedCopy.sqliteBytes.isEmpty) {
          throw const FormatException('Bản sao trước nhập không hợp lệ');
        }
        await pendingCopy.rename(checkpoint.path);
      } finally {
        if (await pendingCopy.exists()) await pendingCopy.delete();
      }

      // For a retry, compare against the ORIGINAL pre-import snapshot,
      // not against a snapshot that may already contain partial new data.
      final baselineName = priorJournal != null && priorJournal.needsReview
          ? priorJournal.safetyCopyName : path.basename(checkpoint.path);
      final baselineFile = File(path.join(safetyDir.path, baselineName));
      if (await FileSystemEntity.type(baselineFile.path,
              followLinks: false) != FileSystemEntityType.file ||
          await baselineFile.length() > UnifiedBackupBundle.maxBundleBytes) {
        throw const FormatException('Bản dự phòng gốc trước nhập không hợp lệ');
      }
      final baseline = UnifiedBackupBundle.decode(
        await baselineFile.readAsBytes());
      final baselineDb = File('${scratch.path}/baseline.db');
      await baselineDb.writeAsBytes(baseline.sqliteBytes, flush: true);
      final originalTrips = await TripRepository.inspectBackupFile(baselineDb);
      if (originalTrips.hasActiveTrip ||
          (await repository.inspectCurrentData()).hasActiveTrip) {
        throw StateError('Có chuyến chưa hoàn tất trước khi nhập');
      }
      // Durable marker must be committed BEFORE any live data writes.
      importJournal = await BackupImportJournal.begin(
        support: support,
        archiveSha256: archiveDigest,
        safetyCopyName: path.basename(checkpoint.path));
      changesMayHaveStarted = true;
      final receipts = await repository.importMissingCompletedTrips(extractedDb);
      final settings = await BackupSettingsImporter.importMissing(
        preferences: store,
        archive: archive.settings,
        logos: archive.logos,
        supportDirectory: support);
      final postflight = BackupImportPostflight.verify(
        before: originalTrips,
        archive: inspected,
        after: await repository.inspectCurrentData(),
        beforeSettings: baseline.settings,
        archiveSettings: archive.settings,
        afterSettings: await SettingsBackupBundle.capture(store),
        archivedLogos: archive.logos,
      );
      await BackupImportJournal.transition(
        support: support,
        expected: importJournal,
        phase: BackupImportPhase.completed);
      importJournal = null;
      final updatedBankBookRaw = await store.getString(
        'ttx_vietqr_bank_book_v1');
      if (!mounted) return;
      if (updatedBankBookRaw != null) {
        // Refresh the in-memory payment source immediately; the QR is
        // generated from BankBook, not stored as an image in the archive.
        setState(() => _bankBook = BankBook.decode(updatedBankBookRaw));
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã nhập bổ sung dữ liệu'),
          content: SingleChildScrollView(child: Text(
            'Chuyến mới: ${receipts.imported}\n'
            'Chuyến đã đối soát sau nhập: ${postflight.verifiedNewTrips}\n'
            'Chuyến trùng dữ liệu được bỏ qua: ${receipts.identical}\n'
            'Hóa đơn trùng mã, khác nội dung (không ghi đè): '
              '${receipts.conflictsSkipped}\n'
            'Nhóm cấu hình bổ sung: ${settings.addedKeys}\n'
            'Nhóm cấu hình đã đối soát: ${postflight.verifiedNewSettings}\n'
            'Nhóm cấu hình có sẵn (không ghi đè): '
              '${settings.skippedExistingKeys}\n'
            'Tài khoản VietQR mới: ${settings.addedBankAccounts}\n'
            'Danh bạ VietQR đã bổ sung: ${settings.updatedBankBook ? "Có" : "Không"}\n'
            'Logo VietQR đã lưu: ${settings.restoredLogos}\n'
            'Tài khoản VietQR đã đối soát: ${postflight.verifiedVietQrAccounts}\n'
            'Logo VietQR đã đối soát: ${postflight.verifiedVietQrLogos}\n'
            'Chuyến chưa hoàn tất từ bản sao: '
              '${receipts.unfinishedBackupSkipped ? "Bỏ qua" : "Không có"}\n\n'
            'Bản sao an toàn trước nhập được giữ trong thư mục '
            'riêng của ứng dụng. Hãy dùng mục Xuất bản dự phòng '
            'trước khi nhập trong Cài đặt để lưu tệp ra ngoài. '
            'Đã đối soát lại dữ liệu gốc và dữ liệu vừa nhập. '
            'VietQR đã được tải lại ngay, có thể mở mục Mã QR thanh toán. '
            'Hãy mở lại ứng dụng nếu muốn tải lại các thiết lập khác.')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng')),
          ],
        ),
      );
    } catch (error) {
      if (changesMayHaveStarted && importJournal != null) {
        try {
          await BackupImportJournal.transition(
            support: await getApplicationSupportDirectory(),
            expected: importJournal,
            phase: BackupImportPhase.needsReview);
        } catch (_) {
          // Leave the previous applying marker intact for crash recovery.
        }
      }
      if (mounted) {
        _notify(changesMayHaveStarted
          ? 'Nhập có thể mới hoàn tất một phần; dữ liệu cũ không bị '
            'ghi đè. Có thể nhập lại cùng bản sao: $error'
          : 'Chưa nhập dữ liệu nào: $error');
      }
    } finally {
      if (safeSqlite != null && await safeSqlite.exists()) {
        await safeSqlite.delete();
      }
      if (scratch != null && await scratch.exists()) {
        await scratch.delete(recursive: true);
      }
      await _loadImportJournalStatus();
      if (mounted) setState(() => _importBackupBusy = false);
    }
  }

  /// Browse and export a verified private pre-import safety snapshot.
  /// The original copy stays in private app storage and is never overwritten.
  Future<void> _exportPreImportSafetyCopy() async {
    if (_vaultExportBusy || _importBackupBusy ||
        _unifiedBackupBusy || _settingsBackupBusy || _exportingBackup) return;
    if (meter.status == MeterStatus.running ||
        meter.status == MeterStatus.paused) {
      _notify('Hãy hoàn thành chuyến trước khi xuất bản dự phòng.');
      return;
    }
    setState(() => _vaultExportBusy = true);
    try {
      final support = await getApplicationSupportDirectory();
      final entries = await PreImportBackupVault.list(support);
      if (!mounted) return;
      if (entries.isEmpty) {
        _notify('Chưa có bản dự phòng trước khi nhập trên điện thoại này.');
        return;
      }
      final selected = await showModalBottomSheet<PreImportSafetyFile>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * 0.64,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 6),
                child: Text('Bản dự phòng trước khi nhập',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Text(
                  'Các bản này nằm trong dữ liệu riêng của ứng dụng. '
                  'Chọn một bản để kiểm tra và lưu ra nơi khác trước khi '
                  'gỡ ứng dụng hoặc chuyển điện thoại.',
                  textAlign: TextAlign.center),
              ),
              Expanded(child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final entry = entries[index];
                  final time = entry.modifiedAt.toLocal();
                  String two(int n) => n.toString().padLeft(2, '0');
                  final displayDate =
                      '${two(time.day)}/${two(time.month)}/${time.year} '
                      '${two(time.hour)}:${two(time.minute)}';
                  final megabytes =
                      (entry.byteLength / (1024 * 1024)).toStringAsFixed(1);
                  return ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(displayDate),
                    subtitle: Text('$megabytes MiB — Chạm để kiểm tra'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(sheet, entry),
                  );
                },
              )),
            ]),
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final verified = await PreImportBackupVault.verify(
        entry: selected,
        temporaryDirectory: await getTemporaryDirectory());
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Bản dự phòng hợp lệ'),
          content: Text(
            'Tạo lúc (UTC): ${verified.createdAtUtc.toIso8601String()}\n'
            'Chuyến hoàn tất: ${verified.completedTrips}\n'
            'Nhóm cấu hình: ${verified.settingsCount}\n'
            'Logo VietQR: ${verified.logoCount}\n'
            'Chuyến dở dang: ${verified.activeTripSkipped ? "Có" : "Không"}\n\n'
            'Đã kiểm tra gói sao lưu và tính toàn vẹn của SQLite. '
            'Đây là bản dự phòng từ trước khi nhập dữ liệu; '
            'xuất tệp không phục hồi hoặc thay thế dữ liệu đang có. '
            'Tệp chứa lịch sử GPS và thông tin VietQR không mã hóa.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Hủy')),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Xuất tệp ra ngoài')),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final date = verified.createdAtUtc.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final filename = 'TTX_TruocNhap_'
          '${date.year}${two(date.month)}${two(date.day)}_'
          '${two(date.hour)}${two(date.minute)}${two(date.second)}.ttxbackup';
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Lưu bản dự phòng trước khi nhập',
        fileName: filename,
        bytes: verified.bytes,
      );
      if (mounted) {
        _notify(destination == null
          ? 'Đã hủy xuất; bản dự phòng trên máy vẫn được giữ nguyên.'
          : 'Đã xuất bản dự phòng. Cất giữ ở nơi riêng tư, an toàn.');
      }
    } catch (error) {
      if (mounted) _notify('Không thể xuất bản dự phòng: $error');
    } finally {
      if (mounted) setState(() => _vaultExportBusy = false);
    }
  }

  Future<void> _settingsMenu() async {
    if (_importBackupBusy) return;
    final item = await showModalBottomSheet<String>(
      context: context, showDragHandle: true,
      builder: (context) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.price_change_outlined),
          title: const Text('Quản lý bảng giá cước'),
          onTap: () => Navigator.pop(context, 'tariff')),
        ListTile(leading: const Icon(Icons.map_outlined),
          title: const Text('Bản đồ 2D / 3D và lời chào'),
          onTap: () => Navigator.pop(context, 'dashboard')),
        ListTile(leading: const Icon(Icons.directions_car_outlined),
          title: const Text('Hãng xe và biển số'),
          onTap: () => Navigator.pop(context, 'vehicle')),
        ListTile(leading: const Icon(Icons.backup_outlined),
          title: const Text('Sao lưu lịch sử chuyến (SQLite)'),
          subtitle: const Text('Xuất bản sao an toàn, không ghi đè dữ liệu'),
          onTap: () => Navigator.pop(context, 'backup')),
        ListTile(leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Sao lưu gộp SQLite + cấu hình'),
          subtitle: const Text('Một tệp .ttxbackup có kiểm tra SHA-256'),
          onTap: () => Navigator.pop(context, 'backupCombined')),
        ListTile(leading: const Icon(Icons.restore_page_outlined),
          title: const Text('Nhập bản sao lưu (.ttxbackup)'),
          subtitle: const Text('Bổ sung dữ liệu, không ghi đè chuyến cũ'),
          onTap: () => Navigator.pop(context, 'importCombined')),
        ListTile(leading: const Icon(Icons.shield_outlined),
          title: const Text('Xuất bản dự phòng trước khi nhập'),
          subtitle: const Text('Kiểm tra và lưu bản gốc ra ngoài ứng dụng'),
          onTap: () => Navigator.pop(context, 'exportSafety')),
        ListTile(leading: const Icon(Icons.settings_backup_restore_outlined),
          title: const Text('Sao lưu cấu hình (JSON)'),
          subtitle: const Text('Bảng giá, xe, VietQR và bản đồ'),
          onTap: () => Navigator.pop(context, 'backupSettings')),
      ])),
    );
    if (!mounted) return;
    switch (item) {
      case 'tariff':
        await _tariffDialog();
      case 'dashboard':
        await _editDashboardPreferences();
      case 'vehicle':
        await _configureVehicle();
      case 'backup':
        await _backupHistory();
      case 'backupSettings':
        await _backupSettings();
      case 'backupCombined':
        await _backupCombined();
      case 'importCombined':
        await _importCombinedBackup();
      case 'exportSafety':
        await _exportPreImportSafetyCopy();
    }
  }

  void _showTools(String choice) {
    if (_importBackupBusy) return;
    switch (choice) {
      case 'vehicle':
        _configureVehicle();
        return;
      case 'bank':
        _configureBank();
        return;
      case 'backup':
        _backupHistory();
        return;
      case 'backupSettings':
        _backupSettings();
        return;
      case 'backupCombined':
        _backupCombined();
        return;
      case 'importCombined':
        _importCombinedBackup();
        return;
      case 'exportSafety':
        _exportPreImportSafetyCopy();
        return;
      case 'inspectCombined':
        _inspectCombinedBackup();
        return;
      case 'inspectSettings':
        _inspectSettingsBackup();
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
      case 'dashboardSettings':
        _editDashboardPreferences();
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
    final mapHeight = (MediaQuery.sizeOf(context).height *
        (active ? 0.35 : 0.39)).clamp(335.0, 405.0).toDouble();

    return Stack(children: [
      Scaffold(
      backgroundColor: DriverProColors.background,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: DriverProColors.backgroundDeep,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 24),
          tooltip: 'Menu cài đặt và bảng giá',
          onPressed: _settingsMenu,
        ),
        titleSpacing: 2,
        centerTitle: true,
        title: const DriverProBrand(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 23),
            tooltip: 'Cài đặt ứng dụng',
            onPressed: _settingsMenu,
          ),
          PopupMenuButton<String>(
            tooltip: 'Tiện ích và cấu hình',
            onSelected: _showTools,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'vehicle',
                child: Text('Cài đặt xe và biển số')),
              PopupMenuItem(value: 'bank',
                child: Text('Tài khoản ngân hàng VietQR')),
              PopupMenuItem(value: 'backup',
                child: Text('Sao lưu lịch sử (SQLite)')),
              PopupMenuItem(value: 'backupSettings',
                child: Text('Sao lưu cấu hình (JSON)')),
              PopupMenuItem(value: 'backupCombined',
                child: Text('Sao lưu gộp dữ liệu (.ttxbackup)')),
              PopupMenuItem(value: 'importCombined',
                child: Text('Nhập bản sao lưu (.ttxbackup)')),
              PopupMenuItem(value: 'exportSafety',
                child: Text('Xuất bản dự phòng trước khi nhập')),
              PopupMenuItem(value: 'inspectCombined',
                child: Text('Kiểm tra gói dữ liệu (.ttxbackup)')),
              PopupMenuItem(value: 'inspectSettings',
                child: Text('Kiểm tra tệp sao lưu cấu hình')),
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
              PopupMenuItem(value: 'dashboardSettings',
                child: Text('Bản đồ 2D / 3D và lời chào')),
            ],
            icon: const Icon(Icons.more_vert_rounded, size: 21),
          ),
        ],
      ),
      body: SafeArea(child: ListView(
        key: const Key('driver-pro-dashboard'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(11, 6, 11, 20),
        children: [
          Center(child: DriverProStatusBanner(
            status: status,
            requiresManualResume: meter.requiresManualResume)),
          if (_interruptedImportWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: DriverProPanel(
                borderColor: DriverProColors.amber,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                    color: DriverProColors.amber),
                  title: const Text('Cần kiểm tra lần nhập trước',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(_interruptedImportWarning!),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _importBackupBusy ? null : _importCombinedBackup,
                ),
              ),
            ),
          const SizedBox(height: 1),
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: LedMarqueeTitle(
              compact: true,
              key: ValueKey('greeting-${status == MeterStatus.finished}'),
              message: status == MeterStatus.finished
                  ? _dashboardPrefs.thanks : _dashboardPrefs.welcome),
          )),
          const SizedBox(height: 8),
          if (!_storageReady)
            DriverProPanel(
              child: SizedBox(
                height: mapHeight - 24,
                child: Center(child: _startupError == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: DriverProColors.cyan),
                          SizedBox(height: 12),
                          Text('Đang tải dữ liệu chuyến đi...'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Không tải được dữ liệu chuyến đi'),
                          TextButton(
                            onPressed: _initializeData,
                            child: const Text('Thử lại')),
                        ],
                      )),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF17577B), width: 1.3),
                borderRadius: BorderRadius.circular(19),
                boxShadow: const [BoxShadow(
                  color: Color(0x2700C9EF), blurRadius: 15)]),
              child: DashboardMap(
                height: mapHeight,
                latitude: _mapLat, longitude: _mapLon,
                routePoints: active ? _routePoints : const [],
                speedKmh: active ? meter.speedKmh : _previewSpeedKmh,
                speedLimitKmh: meter.tariff.speedLimitKmh,
                headingDegrees: _headingDegrees,
                pitchDegrees: _dashboardPrefs.renderedPitch,
                is3D: _is3D,
                dark: _dashboardPrefs.darkMap,
                onToggle3D: _toggleMap3D,
                onToggleDark: _toggleMapDark,
                onLocate: _locateOnMap,
              ),
            ),
          const SizedBox(height: 9),
          if (status == MeterStatus.idle) ...[
            _selectedCompanyCard(status),
            const SizedBox(height: 8),
            DriverProQuoteCard(
              onPressed: _storageReady ? _flatFareDialog : null),
          ] else if (active) ...[
            _mainFareCard(),
            const SizedBox(height: 8),
            _tripMetrics(status),
            const SizedBox(height: 7),
            _botQuickAction(),
            const SizedBox(height: 9),
            _gpsStatusStrip(status),
            const SizedBox(height: 8),
            DriverProPanel(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ExpansionTile(
                iconColor: DriverProColors.cyan,
                collapsedIconColor: DriverProColors.cyan,
                title: const Text('Chi tiết tính tiền',
                  style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
                leading: const Icon(Icons.receipt_long_outlined,
                  color: DriverProColors.cyan, size: 21),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                children: [
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
              ),
            ),
          ] else ...[
            _mainFareCard(),
            const SizedBox(height: 8),
            _tripMetrics(status),
            const SizedBox(height: 7),
            _selectedCompanyCard(status),
          ],
          if (meter.requiresManualResume)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chuyến đã tạm ngắt an toàn. '
                'Chỉ tiếp tục khi GPS đã sẵn sàng.',
                style: TextStyle(
                  color: DriverProColors.amber, fontSize: 12))),
          if (active && !_trackingPolicy.hasTrustedFix &&
              !meter.requiresManualResume)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Text(
                'Đang xác định GPS; không tính cước cho lúc mất tín hiệu.',
                style: TextStyle(
                  fontSize: 12, color: DriverProColors.amber)),
            ),
          if (_checkpointError != null)
            DriverProPanel(
              borderColor: DriverProColors.red,
              child: ListTile(
                title: const Text('Lỗi lưu trạng thái chuyến',
                  style: TextStyle(color: DriverProColors.red)),
                subtitle: Text(_checkpointError!,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  onPressed: () => setState(() {
                    _checkpointError = null;
                    _checkpoint(force: true);
                  }),
                  icon: const Icon(Icons.refresh)),
              ),
            ),
          const SizedBox(height: 10),
          const Center(child: Text(
            'Phiên bản thử nghiệm • Chưa sử dụng thu cước thương mại',
            style: TextStyle(
              color: DriverProColors.muted, fontSize: 10))),
        ],
      )),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: DriverProColors.backgroundDeep,
            border: Border(top: BorderSide(
              color: DriverProColors.border, width: 0.8))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 1),
              child: _primaryTripActions(status)),
            NavigationBar(
          height: 66,
          backgroundColor: DriverProColors.backgroundDeep,
          indicatorColor: const Color(0xFF123A53),
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) _showHistory();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined,
                color: DriverProColors.muted),
              selectedIcon: Icon(Icons.speed_rounded,
                color: DriverProColors.cyan),
              label: 'Đồng hồ cước',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded,
                color: DriverProColors.muted),
              label: 'Doanh thu',
            ),
          ],
            ),
          ]),
        ),
      ),
      ), // End Scaffold child of the import-blocking Stack.
      if (_importBackupBusy)
        const Positioned.fill(child: Stack(children: [
          ModalBarrier(
            dismissible: false,
            color: Color(0xD50A1320),
          ),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: DriverProColors.cyan),
            SizedBox(height: 16),
            Text('Đang kiểm tra và nhập bản sao lưu...',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Không đóng ứng dụng trong lúc nhập dữ liệu.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ])),
    ]);
  }
}
