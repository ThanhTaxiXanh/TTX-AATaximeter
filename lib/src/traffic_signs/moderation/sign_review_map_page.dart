import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../../ui/map_sovereignty_hud.dart';
import '../../ui/vietnam_map_sovereignty.dart';
import '../data/traffic_sign_database.dart';
import '../domain/traffic_sign_catalog.dart';
import 'sign_review_store.dart';

/// A dedicated interactive moderation/map screen. Pending reports are visible
/// ONLY here; the main driver map is fed exclusively by approved_signs.
///
/// This is a LOCAL QA workflow, not a remote submission or a secure
/// administrator portal. Real multi-driver review needs server-side auth.
class SignReviewMapPage extends StatefulWidget {
  const SignReviewMapPage({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialSignId,
  });
  final double initialLatitude, initialLongitude;
  final int? initialSignId;

  @override
  State<SignReviewMapPage> createState() => _SignReviewMapPageState();
}

class _SignReviewMapPageState extends State<SignReviewMapPage> {
  final fm.MapController _controller = fm.MapController();
  final SignReviewStore _store = SignReviewStore.instance;
  late ll.LatLng _selection;
  List<SignChangeReport> _pending = const [];
  List<ApprovedSignPatch> _approved = const [];
  bool _loading = true;
  bool _onlineTiles = true;
  String? _error;
  int _refreshEpoch = 0;

  @override
  void initState() {
    super.initState();
    final valid = widget.initialLatitude.isFinite &&
        widget.initialLatitude >= -90 && widget.initialLatitude <= 90 &&
        widget.initialLongitude.isFinite &&
        widget.initialLongitude >= -180 && widget.initialLongitude <= 180;
    _selection = valid
        ? ll.LatLng(widget.initialLatitude, widget.initialLongitude)
        : const ll.LatLng(16, 107.5);
    _store.addListener(_refresh);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final epoch = ++_refreshEpoch;
    try {
      final pending = await _store.reports(status: 'pending');
      final approved = await _store.approved();
      if (!mounted || epoch != _refreshEpoch) return;
      setState(() {
        _pending = pending;
        _approved = approved.where((p) => !p.deleted).toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted && epoch == _refreshEpoch) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _createReport(SignChangeOperation operation,
      {int? initialTargetSignId}) async {
    if (!mounted) return;
    final idInput = TextEditingController(
        text: (initialTargetSignId ?? widget.initialSignId)?.toString() ?? '');
    final typeInput = TextEditingController(text: '4');
    final rawInput = TextEditingController(text: '0');
    final directionInput = TextEditingController(text: '255');
    final noteInput = TextEditingController();
    final selected = _selection;
    int? loadedTargetId;
    try {
      // When a sign ID was selected, prefill the type/position from its
      // existing (base or approved) record. User may still edit.
      if (operation != SignChangeOperation.add &&
          int.tryParse(idInput.text) != null) {
        final original = await (await TrafficSignDatabase.openOptional())
            ?.byId(int.parse(idInput.text));
        if (original != null) {
          loadedTargetId = original.signId;
          // Preserve the map point chosen for the EDIT proposal; do not
          // silently snap the report back to the existing sign location.
          typeInput.text = original.signTypeCode.toString();
          rawInput.text = original.valueRaw.toString();
          directionInput.text = original.directionRaw.toString();
        }
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        backgroundColor: const Color(0xFF102338),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16,
                20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (operation) {
                    SignChangeOperation.add => 'Báo cáo biển báo / camera mới',
                    SignChangeOperation.edit => 'Đề xuất sửa biển báo',
                    SignChangeOperation.delete => 'Đề xuất xóa biển báo',
                  }, style: const TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Vị trí: ${selected.latitude.toStringAsFixed(6)}, '
                      '${selected.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  if (operation != SignChangeOperation.add)
                    TextField(controller: idInput,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'sign_id cần sửa/xóa (bắt buộc)',
                        suffixIcon: IconButton(
                          tooltip: 'Tra cứu mã biển trước khi sửa',
                          icon: const Icon(Icons.manage_search),
                          onPressed: () async {
                            try {
                              final id = int.tryParse(idInput.text.trim());
                              if (id == null) {
                                throw ArgumentError('Nhập một sign_id hợp lệ');
                              }
                              final repository =
                                  await TrafficSignDatabase.openOptional();
                              final sign = await repository?.byId(id);
                              if (sign == null) {
                                throw StateError('Không tìm thấy sign_id');
                              }
                              loadedTargetId = id;
                              typeInput.text = sign.signTypeCode.toString();
                              rawInput.text = sign.valueRaw.toString();
                              directionInput.text = sign.directionRaw.toString();
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(content: Text(
                                    'Đã tải thông tin biển. Vị trí báo cáo '
                                    'vẫn là điểm bạn chọn trên bản đồ.')));
                              }
                            } catch (error) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text('$error')));
                              }
                            }
                          },
                        ),
                      )),
                  TextField(controller: typeInput,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Mã loại biển (4 = Camera, 10 = Camera AI)',
                        helperText: 'Nhập mã V1 đã xác minh')),
                  TextField(controller: rawInput,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Giá trị thô (mã 1 là số trên biển tốc độ)')),
                  TextField(controller: directionInput,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Hướng thô (255 = chưa rõ)')),
                  TextField(controller: noteInput,
                    maxLines: 3, maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Mô tả / nguồn quan sát (bắt buộc)',
                      hintText: 'Ví dụ: camera mới, ở cột bên phải đường',
                    )),
                  const SizedBox(height: 8),
                  const Text('Gửi báo cáo chỉ tạo trạng thái CHỜ DUYỆT. '
                      'Không xuất hiện ngay trên bản đồ chính.',
                    style: TextStyle(color: Colors.amberAccent,
                        fontSize: 12)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Gửi vào hàng chờ'),
                    onPressed: () async {
                      try {
                        final target = operation == SignChangeOperation.add
                            ? null : int.tryParse(idInput.text.trim());
                        if (operation != SignChangeOperation.add &&
                            target == null) {
                          throw ArgumentError('Cần sign_id gốc hợp lệ');
                        }
                        if (operation == SignChangeOperation.edit &&
                            loadedTargetId != target) {
                          throw StateError(
                            'Bấm Tra cứu ID để nạp đúng mã/giá trị '
                            'biển nguồn trước khi sửa');
                        }
                        var reportLocation = selected;
                        var reportCode = int.tryParse(typeInput.text.trim());
                        var reportRaw = int.tryParse(rawInput.text.trim());
                        var reportDirection =
                            int.tryParse(directionInput.text.trim());
                        if (reportCode == null || reportRaw == null ||
                            reportDirection == null) {
                          throw ArgumentError('Mã, giá trị hoặc hướng không hợp lệ');
                        }
                        if (operation != SignChangeOperation.add) {
                          final repository =
                              await TrafficSignDatabase.openOptional();
                          final existing = await repository?.byId(target!);
                          if (existing == null) {
                            throw StateError('Không tìm thấy sign_id nguồn');
                          }
                          // Delete always targets the original record
                          // position and code rather than a random map click.
                          if (operation == SignChangeOperation.delete) {
                            reportLocation = ll.LatLng(
                                existing.latitude, existing.longitude);
                            reportCode = existing.signTypeCode;
                            reportRaw = existing.valueRaw;
                            reportDirection = existing.directionRaw;
                          }
                        }
                        final draft = SignChangeDraft(
                          operation: operation, targetSignId: target,
                          latitude: reportLocation.latitude,
                          longitude: reportLocation.longitude,
                          typeCode: reportCode,
                          valueRaw: reportRaw, directionRaw: reportDirection,
                          note: noteInput.text,
                        );
                        await _store.submit(draft);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(
                              'Đã nhận báo cáo. Chưa đưa lên bản đồ chính.')));
                        }
                      } catch (e) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('Không thể gửi: $e')));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      idInput.dispose();
      typeInput.dispose();
      rawInput.dispose();
      directionInput.dispose();
      noteInput.dispose();
    }
  }

  Future<void> _review(SignChangeReport report, bool approve) async {
    final note = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(approve ? 'Phê duyệt báo cáo #${report.id}'
              : 'Từ chối báo cáo #${report.id}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Mã ${report.draft.typeCode} · '
                '${TrafficSignCatalog.description(report.draft.typeCode)}'),
            const SizedBox(height: 6),
            Text(report.draft.note),
            TextField(controller: note, maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Ghi chú quyết định (bắt buộc)')),
            const Text('Chỉ có hiệu lực trên máy QA này. '
                'Không thay cho phê duyệt máy chủ.',
              style: TextStyle(fontSize: 11)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy')),
            FilledButton(
              onPressed: !localApprovalQaEnabled ? null : () async {
                try {
                  await _store.review(report.id,
                    approve: approve, reviewerNote: note.text);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text(approve ? 'Xác nhận duyệt' : 'Xác nhận từ chối'),
            ),
          ],
        ),
      );
    } finally {
      note.dispose();
    }
  }

  Future<void> _showReviewHistory() async {
    try {
      final records = await _store.reports();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        backgroundColor: const Color(0xFF14273B),
        builder: (sheet) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * 0.72,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Nhật ký báo cáo & phê duyệt',
                  style: TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Expanded(child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (_, i) {
                  final r = records[i];
                  return ListTile(
                    leading: Icon(switch (r.status) {
                      'approved' => Icons.verified,
                      'rejected' => Icons.cancel_outlined,
                      _ => Icons.pending_outlined,
                    }, color: r.status == 'approved'
                        ? Colors.lightGreenAccent
                        : r.status == 'rejected'
                            ? Colors.redAccent : Colors.amberAccent),
                    title: Text('#${r.id} · ${r.draft.operation.name} · '
                        '${r.status}', style: const TextStyle(
                          color: Colors.white)),
                    subtitle: Text(
                      '${TrafficSignCatalog.description(r.draft.typeCode)}\n'
                      '${r.draft.note}\n'
                      'Tạo: ${r.createdAt}\n'
                      'Duyệt: ${r.reviewedAt ?? 'Chưa có'} · '
                      '${r.reviewerNote ?? ''}',
                      style: const TextStyle(color: Colors.white70)),
                    isThreeLine: true,
                  );
                },
              )),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không mở được lịch sử: $error')));
      }
    }
  }

  @override
  void dispose() {
    _refreshEpoch++;
    _store.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081522),
      appBar: AppBar(
        title: const Text('Quản lý biển báo & camera'),
        actions: [
          IconButton(
            tooltip: 'Nhật ký đã duyệt/từ chối',
            icon: const Icon(Icons.history),
            onPressed: () => unawaited(_showReviewHistory()),
          ),
          IconButton(
            tooltip: _onlineTiles ? 'Tắt tile để dùng offline' : 'Bật tile',
            icon: Icon(_onlineTiles ? Icons.wifi_off : Icons.layers_outlined),
            onPressed: () => setState(() => _onlineTiles = !_onlineTiles),
          ),
          IconButton(onPressed: () => unawaited(_refresh()),
            tooltip: 'Làm mới', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(child: Column(children: [
        SizedBox(height: 330, child: Stack(children: [
          fm.FlutterMap(
            mapController: _controller,
            options: fm.MapOptions(
              initialCenter: _selection, initialZoom: 15,
              minZoom: 3, maxZoom: 19,
              onTap: (tap, position) =>
                  setState(() => _selection = position),
              onLongPress: (tap, position) {
                setState(() => _selection = position);
                unawaited(_createReport(SignChangeOperation.add));
              },
            ),
            children: [
              if (_onlineTiles)
                fm.TileLayer(
                  urlTemplate: VietnamMapSovereignty.osmRasterTiles,
                  userAgentPackageName: 'vn.thanhtaxixanh.ttx_aataximeter',
                )
              else
                const ColoredBox(color: Color(0xFF172D42)),
              fm.PolygonLayer(polygons: [
                for (final zone
                    in VietnamMapSovereignty.maritimeRedactionZones)
                  fm.Polygon(points: [
                    ll.LatLng(zone.south, zone.west),
                    ll.LatLng(zone.south, zone.east),
                    ll.LatLng(zone.north, zone.east),
                    ll.LatLng(zone.north, zone.west),
                  ], borderStrokeWidth: 0,
                    color: const Color(0xFF132A42)),
              ]),
              // Pending locations ONLY appear in this review screen.
              fm.MarkerLayer(markers: [
                for (final report in _pending)
                  fm.Marker(
                    point: ll.LatLng(report.draft.latitude,
                        report.draft.longitude),
                    width: 34, height: 34,
                    child: Tooltip(
                      message: 'Chờ duyệt #${report.id}',
                      child: const Icon(Icons.report_rounded,
                        color: Colors.amberAccent, size: 27),
                    ),
                  ),
                for (final approved in _approved)
                  fm.Marker(
                    point: ll.LatLng(
                        approved.latitude, approved.longitude),
                    width: 32, height: 32,
                    child: Tooltip(
                      message: 'Đã duyệt #${approved.signId}',
                      child: const Icon(Icons.verified_rounded,
                        color: Colors.lightGreenAccent, size: 24),
                    ),
                  ),
                fm.Marker(point: _selection, width: 32, height: 40,
                  child: const Icon(Icons.place_rounded,
                    color: Colors.cyanAccent, size: 34)),
              ]),
              fm.MarkerLayer(markers: [
                for (final label in VietnamMapSovereignty.labels)
                  fm.Marker(point: ll.LatLng(label.latitude, label.longitude),
                    width: 166, height: 32, child: IgnorePointer(
                      child: Center(child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xEE0A1C2D),
                          borderRadius: BorderRadius.circular(6)),
                        child: Padding(padding: const EdgeInsets.all(5),
                          child: Text(label.name,
                            style: const TextStyle(color: Colors.white,
                              fontSize: 11))),
                      )),
                    ),
                  ),
              ]),
            ],
          ),
          const Positioned(top: 10, left: 10, right: 10,
            child: Align(alignment: Alignment.topLeft,
              child: MapSovereigntyHud())),
          Positioned(bottom: 8, left: 8, right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xEE0B2032),
                borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Text(
                  'Chạm bản đồ để chọn vị trí, nhấn giữ để báo cáo mới · '
                  '${_selection.latitude.toStringAsFixed(6)}, '
                  '${_selection.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white,
                    fontSize: 11)),
              ),
            )),
        ])),
        const Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 5),
          child: Text('Vàng = chờ duyệt · Xanh lá = đã duyệt · '
              'Xanh lam = vị trí đang chọn',
            style: TextStyle(color: Colors.white70, fontSize: 11))),
        Wrap(spacing: 6, runSpacing: 2, children: [
          OutlinedButton.icon(onPressed: () =>
              unawaited(_createReport(SignChangeOperation.add)),
            icon: const Icon(Icons.add), label: const Text('Thêm')),
          OutlinedButton.icon(onPressed: () =>
              unawaited(_createReport(SignChangeOperation.edit)),
            icon: const Icon(Icons.edit), label: const Text('Sửa')),
          OutlinedButton.icon(onPressed: () =>
              unawaited(_createReport(SignChangeOperation.delete)),
            icon: const Icon(Icons.delete_outline), label: const Text('Xóa')),
        ]),
        if (!localApprovalQaEnabled)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('Chỉ tạo báo cáo cục bộ. Phê duyệt bị khóa khi '
                'chưa có máy chủ quản trị xác thực.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
          )
        else
          const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('QA CỤC BỘ: phê duyệt chỉ áp dụng trên thiết bị này, '
                'không có xác thực người dùng qua máy chủ.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11))),
        if (_error != null)
          Text('Lỗi: $_error', style: const TextStyle(color: Colors.redAccent)),
        if (_loading) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('Hàng chờ phê duyệt: ${_pending.length}',
              style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)))),
        Expanded(child: _pending.isEmpty
          ? const Center(child: Text('Chưa có báo cáo chờ duyệt',
              style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              itemCount: _pending.length,
              itemBuilder: (context, index) {
                final report = _pending[index];
                final d = report.draft;
                return Card(color: const Color(0xFF14293D),
                  child: ListTile(
                    title: Text('#${report.id} · ${d.operation.name} · '
                        '${TrafficSignCatalog.description(d.typeCode)}',
                      style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${d.latitude.toStringAsFixed(6)}, '
                      '${d.longitude.toStringAsFixed(6)}\n${d.note}',
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      setState(() {
                        _selection = ll.LatLng(d.latitude, d.longitude);
                      });
                      _controller.move(_selection, 17);
                    },
                    trailing: localApprovalQaEnabled
                      ? PopupMenuButton<String>(
                        tooltip: 'Quyết định báo cáo',
                        onSelected: (value) => unawaited(_review(
                            report, value == 'approve')),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'approve',
                            child: Text('Phê duyệt')),
                          PopupMenuItem(value: 'reject',
                            child: Text('Từ chối')),
                        ],
                      )
                      : const Icon(Icons.hourglass_empty,
                          color: Colors.amberAccent),
                  ),
                );
              },
            )),
      ])),
    );
  }
}
