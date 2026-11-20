import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/traffic_sign_database.dart';
import '../data/traffic_sign_repository.dart';
import '../domain/traffic_sign.dart';
import 'traffic_sign_details.dart';
import 'traffic_sign_layer.dart';

/// Owner's optional offline sign layer. Camera comes from the parent map;
/// it never subscribes to GPS or the taxi fare engine.
class TrafficSignMap2D extends StatefulWidget {
  const TrafficSignMap2D({
    super.key,
    required this.camera,
    required this.onFocus,
    required this.onCluster,
  });

  final ValueListenable<fm.MapCamera?> camera;
  final void Function(double latitude, double longitude) onFocus;
  final ValueChanged<SignMapItem> onCluster;

  @override
  State<TrafficSignMap2D> createState() => TrafficSignMap2DState();
}

class TrafficSignMap2DState extends State<TrafficSignMap2D> {
  static const _enabledKey = 'ttx_signs_layer_enabled_v1';
  static const _speedKey = 'ttx_signs_speed_only_v1';
  static const _typeKey = 'ttx_signs_type_code_v1';

  TrafficSignRepository? _repository;
  TrafficSignFilter _filter = const TrafficSignFilter();
  SignViewportResult _visible = SignViewportResult.empty;
  Timer? _queryTimer;
  int _queryEpoch = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.camera.addListener(_scheduleViewport);
    unawaited(_openDatabase());
  }

  @override
  void didUpdateWidget(covariant TrafficSignMap2D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera) {
      oldWidget.camera.removeListener(_scheduleViewport);
      widget.camera.addListener(_scheduleViewport);
      _scheduleViewport();
    }
  }

  Future<void> _openDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filter = TrafficSignFilter(
        enabled: prefs.getBool(_enabledKey) ?? false,
        speedOnly: prefs.getBool(_speedKey) ?? false,
        typeCode: prefs.getInt(_typeKey),
      );
      final repository = await TrafficSignDatabase.openOptional();
      if (!mounted) {
        await repository?.database.close();
        return;
      }
      setState(() {
        _filter = filter;
        _repository = repository;
        _loading = false;
      });
      _scheduleViewport();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
      debugPrint('Offline traffic-sign layer unavailable: $error');
    }
  }

  void _scheduleViewport() {
    _queryTimer?.cancel();
    final epoch = ++_queryEpoch;
    final camera = widget.camera.value;
    final repository = _repository;
    if (camera == null || repository == null || !_filter.enabled) {
      if (mounted && _visible.total != 0) {
        setState(() => _visible = SignViewportResult.empty);
      }
      return;
    }

    final bounds = camera.visibleBounds;
    final viewport = SignViewport(
      west: bounds.west, east: bounds.east,
      south: bounds.south, north: bounds.north,
    );
    // The supplied dataset is Vietnam-only. Do not interpret an
    // antimeridian-crossing bbox as an ordinary west<=east viewport.
    if (!viewport.isValid) {
      if (mounted && _visible.total != 0) {
        setState(() => _visible = SignViewportResult.empty);
      }
      return;
    }
    final filter = _filter;
    _queryTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(_fetchViewport(repository, viewport, filter, epoch));
    });
  }

  Future<void> _fetchViewport(
    TrafficSignRepository repository, SignViewport viewport,
    TrafficSignFilter filter, int epoch,
  ) async {
    try {
      final result = await repository.viewport(viewport, filter);
      if (mounted && epoch == _queryEpoch) {
        setState(() {
          _visible = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && epoch == _queryEpoch) {
        setState(() {
          _visible = SignViewportResult.empty;
          _error = error.toString();
        });
        debugPrint('Offline traffic-sign query failed: $error');
      }
    }
  }

  Future<void> _setFilter(TrafficSignFilter filter) async {
    if (!mounted) return;
    setState(() {
      _filter = filter;
      _visible = SignViewportResult.empty;
    });
    _scheduleViewport();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, filter.enabled);
      await prefs.setBool(_speedKey, filter.speedOnly);
      if (filter.typeCode == null) {
        await prefs.remove(_typeKey);
      } else {
        await prefs.setInt(_typeKey, filter.typeCode!);
      }
    } catch (error) {
      debugPrint('Traffic-sign preferences unavailable: $error');
    }
  }

  Future<void> _showSignDetails(int id) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final sign = await repository.byId(id);
      if (!mounted) return;
      if (sign == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Không tìm thấy ID biển báo')),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF101D2D),
        isScrollControlled: true,
        builder: (_) => TrafficSignDetails(sign: sign),
      );
    } catch (error) {
      debugPrint('Traffic-sign detail unavailable: $error');
    }
  }

  /// Called by the compact map control; no persistent dialog while driving.
  Future<void> showFilters() async {
    final repository = _repository;
    List<int> codes = const [];
    if (repository != null) {
      try {
        codes = await repository.availableTypeCodes();
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
    }
    if (!mounted) return;
    var chosen = _filter;
    final controller = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF101D2D),
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, rebuild) {
            void choose(TrafficSignFilter next) {
              chosen = next;
              rebuild(() {});
              unawaited(_setFilter(next));
            }
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16,
                  16 + MediaQuery.viewInsetsOf(sheetContext).bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biển báo giao thông', style: TextStyle(
                        fontSize: 18, color: Colors.white,
                        fontWeight: FontWeight.w800,
                      )),
                      const SizedBox(height: 8),
                      Text(
                        _loading ? 'Đang kiểm tra dữ liệu biển báo...' :
                        _error != null ? 'Lỗi dữ liệu: $_error' :
                        repository == null
                            ? 'Chưa đóng gói database biển báo thật vào APK.'
                            : 'Trong vùng bản đồ: ${_visible.total} biển báo',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (repository == null && !_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: FilledButton.icon(
                            icon: const Icon(Icons.file_open_outlined),
                            label: const Text('Nhập SQLite offline từ điện thoại'),
                            onPressed: () async {
                              try {
                                final picked = await FilePicker.pickFile(
                                  type: FileType.any,
                                );
                                if (picked == null) return;
                                final reportedSize =
                                    picked.lengthSync() ?? await picked.length();
                                if (reportedSize != null &&
                                    reportedSize != 21090304) {
                                  throw StateError(
                                    'Dung lượng tệp không khớp dữ liệu thật');
                                }
                                // Android SAF may return a content URI rather
                                // than a readable filesystem path. Stream to
                                // a local temp file without allocating 21 MB
                                // of Dart bytes, then verify its SHA-256.
                                final temporaryFolder = await getTemporaryDirectory();
                                final temporary = File(path.join(
                                  temporaryFolder.path,
                                  'ttx_sign_import_${DateTime.now().microsecondsSinceEpoch}.sqlite',
                                ));
                                late final TrafficSignRepository installed;
                                try {
                                  await picked.readAsByteStream().pipe(
                                    temporary.openWrite(),
                                  );
                                  installed =
                                      await TrafficSignDatabase.installFromFile(
                                          temporary);
                                } finally {
                                  if (await temporary.exists()) {
                                    await temporary.delete();
                                  }
                                }
                                if (!mounted) {
                                  await installed.database.close();
                                  return;
                                }
                                setState(() {
                                  _repository = installed;
                                  _error = null;
                                });
                                unawaited(_setFilter(
                                    _filter.copyWith(enabled: true)));
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  const SnackBar(content: Text(
                                    'Đã xác minh và cài database 151.228 biển báo'
                                  )),
                                );
                              } catch (error) {
                                if (mounted) {
                                  setState(() => _error = error.toString());
                                }
                                if (sheetContext.mounted) rebuild(() {});
                              }
                            },
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hiển thị biển báo'),
                        value: repository != null && chosen.enabled,
                        onChanged: repository == null ? null : (enabled) =>
                            choose(chosen.copyWith(enabled: enabled)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Chỉ dữ liệu tốc độ suy ra'),
                        value: chosen.speedOnly,
                        onChanged: repository == null ? null : (speedOnly) =>
                            choose(chosen.copyWith(speedOnly: speedOnly)),
                      ),
                      Row(children: [
                        const Text('Mã loại biển:  '),
                        DropdownButton<int?>(
                          dropdownColor: const Color(0xFF102438),
                          value: codes.contains(chosen.typeCode)
                              ? chosen.typeCode : null,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null, child: Text('Tất cả')),
                            for (final code in codes)
                              DropdownMenuItem<int?>(
                                value: code, child: Text('$code')),
                          ],
                          onChanged: repository == null ? null : (code) =>
                            choose(chosen.copyWith(
                              typeCode: code, clearType: code == null)),
                        ),
                      ]),
                      TextField(
                        controller: controller,
                        enabled: repository != null,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Tìm theo sign_id',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Tìm biển báo theo ID',
                            icon: const Icon(Icons.search),
                            onPressed: repository == null ? null : () async {
                              final id = int.tryParse(controller.text.trim());
                              if (id == null) return;
                              final sign = await repository.byId(id);
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              if (sign == null) {
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  const SnackBar(
                                    content: Text('Không tìm thấy ID biển báo')));
                                return;
                              }
                              widget.onFocus(sign.latitude, sign.longitude);
                              unawaited(_showSignDetails(sign.signId));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Thông tin tham khảo; mã và hướng biển '
                        'chưa được xác minh. Không dùng cho cảnh báo vượt tốc độ.',
                        style: TextStyle(
                          fontSize: 12, color: Colors.amberAccent)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    widget.camera.removeListener(_scheduleViewport);
    _queryTimer?.cancel();
    _queryEpoch++;
    final repository = _repository;
    if (repository != null) unawaited(repository.database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrafficSignLayer(
    items: _filter.enabled ? _visible.items : const [],
    onSelect: (id) => unawaited(_showSignDetails(id)),
    onCluster: widget.onCluster,
  );
}
