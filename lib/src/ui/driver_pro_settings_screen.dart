import 'package:flutter/material.dart';
import '../domain/dashboard_preferences.dart';
import 'driver_pro_design.dart';

class DriverProSettingsScreen extends StatefulWidget {
  const DriverProSettingsScreen({super.key, required this.initial,
    required this.onAction, required this.onPreferencesChanged});
  final DashboardPreferences initial;
  final ValueChanged<String> onAction;
  final ValueChanged<DashboardPreferences> onPreferencesChanged;

  @override
  State<DriverProSettingsScreen> createState() => _DriverProSettingsScreenState();
}

class _SettingEntry {
  const _SettingEntry(this.id, this.name, this.detail, this.icon);
  final String id, name, detail;
  final IconData icon;
}

class _DriverProSettingsScreenState extends State<DriverProSettingsScreen> {
  late DashboardPreferences _prefs = widget.initial;
  final _search = TextEditingController();
  String _query = '';

  static const sections = <(String, IconData, List<_SettingEntry>)>[
    ('Xe & hồ sơ', Icons.directions_car_outlined, [
      _SettingEntry('vehicle', 'Cài đặt xe và biển số',
        'Hãng xe, loại phương tiện và biển số', Icons.directions_car_filled_outlined),
      _SettingEntry('car', 'Car Mode / HUD',
        'Hiển thị dành cho người lái', Icons.personal_video_outlined),
    ]),
    ('Thanh toán', Icons.account_balance_wallet_outlined, [
      _SettingEntry('bank', 'Tài khoản ngân hàng VietQR',
        'Số tài khoản, ngân hàng và logo', Icons.account_balance_outlined),
      _SettingEntry('qr', 'Mã QR thanh toán',
        'Xem và kiểm tra thông tin nhận tiền', Icons.qr_code_2_rounded),
    ]),
    ('Cước phí & chuyến đi', Icons.local_taxi_outlined, [
      _SettingEntry('tariff', 'Quản lý bảng giá',
        'Giá mở cửa và các mức cước', Icons.price_change_outlined),
      _SettingEntry('quote', 'Báo giá chuyến đi',
        'Ước tính cước và giá trọn gói', Icons.calculate_outlined),
      _SettingEntry('toll', 'Nhập phí BOT',
        'Phí trạm thu phí phát sinh', Icons.toll_outlined),
    ]),
    ('Sao lưu & phục hồi', Icons.shield_outlined, [
      _SettingEntry('backupCombined', 'Sao lưu gộp dữ liệu',
        'Lịch sử, cấu hình, logo • .ttxbackup', Icons.inventory_2_outlined),
      _SettingEntry('importCombined', 'Nhập bản sao lưu',
        'Nhập bổ sung, không ghi đè chuyến cũ', Icons.settings_backup_restore),
      _SettingEntry('exportSafety', 'Xuất bản dự phòng trước khi nhập',
        'Lưu bản gốc ra ngoài ứng dụng', Icons.verified_user_outlined),
      _SettingEntry('inspectCombined', 'Kiểm tra gói .ttxbackup',
        'Đối chiếu toàn vẹn và nội dung', Icons.fact_check_outlined),
      _SettingEntry('backup', 'Sao lưu lịch sử SQLite',
        'Chỉ lưu lịch sử và hóa đơn', Icons.storage_outlined),
      _SettingEntry('backupSettings', 'Sao lưu cấu hình JSON',
        'Bảng giá, xe, VietQR và bản đồ', Icons.data_object_outlined),
      _SettingEntry('inspectSettings', 'Kiểm tra cấu hình JSON',
        'Xem và xác thực bản sao cấu hình', Icons.rule_outlined),
    ]),
    ('Quyền & hệ thống', Icons.security_outlined, [
      _SettingEntry('locationPermission', 'Quyền định vị',
        'Thiết lập quyền “Luôn cho phép”', Icons.location_on_outlined),
    ]),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _match(String label, [String detail = '']) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty || label.toLowerCase().contains(q) ||
        detail.toLowerCase().contains(q);
  }

  void _set(DashboardPreferences next) {
    setState(() => _prefs = next);
    widget.onPreferencesChanged(next);
  }

  Widget _row(_SettingEntry item) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(12, 4, 10, 4),
    leading: Container(width: 43, height: 43,
      decoration: BoxDecoration(color: const Color(0xFF12364B),
        borderRadius: BorderRadius.circular(12)),
      child: Icon(item.icon, color: DriverProColors.cyan, size: 22)),
    title: Text(item.name, style: const TextStyle(
      fontSize: 13.5, fontWeight: FontWeight.w700)),
    subtitle: Text(item.detail, style: const TextStyle(
      fontSize: 11, color: DriverProColors.muted)),
    trailing: const Icon(Icons.chevron_right_rounded,
      color: DriverProColors.muted, size: 19),
    onTap: () => widget.onAction(item.id),
  );

  Widget _group(String title, IconData icon, List<_SettingEntry> entries) {
    final visible = entries.where((e) => _match(e.name, e.detail)).toList();
    if (visible.isEmpty && !_match(title)) return const SizedBox.shrink();
    final shown = visible.isEmpty ? entries : visible;
    return Padding(padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(5, 0, 0, 10),
          child: Row(children: [
            Icon(icon, size: 18, color: DriverProColors.cyan),
            const SizedBox(width: 9),
            Text(title, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16)),
          ])),
        _surface(Column(children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 67, endIndent: 14,
                color: Color(0xFF20394F)),
            _row(shown[i]),
          ],
        ])),
      ]));
  }

  Widget _surface(Widget child) => Container(
    decoration: BoxDecoration(
      color: DriverProColors.panel,
      border: Border.all(color: DriverProColors.border),
      borderRadius: BorderRadius.circular(18)),
    child: child,
  );

  Widget _switch(String name, String explanation, bool value,
      ValueChanged<bool> change, IconData icon) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.fromLTRB(15, 3, 12, 3),
    secondary: Icon(icon, color: DriverProColors.cyan, size: 22),
    title: Text(name, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700)),
    subtitle: Text(explanation, style: const TextStyle(
      color: DriverProColors.muted, fontSize: 11)),
    activeTrackColor: DriverProColors.blue,
    value: value, onChanged: change,
  );

  Widget _mapGroup() {
    if (!_match('Bản đồ và điều hướng',
        '2D 3D tối sáng GPS tên đường góc nghiêng lời chào'))
      return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(5, 0, 0, 10),
          child: Row(children: [
            Icon(Icons.map_outlined, color: DriverProColors.cyan, size: 18),
            SizedBox(width: 9),
            Text('Bản đồ & điều hướng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ])),
        _surface(Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 12, 5),
            child: Row(children: [
              const Expanded(child: Text('Chế độ mặc định',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('2D')),
                  ButtonSegment(value: true, label: Text('3D')),
                ],
                selected: {_prefs.default3D},
                showSelectedIcon: false,
                onSelectionChanged: (selected) =>
                  _set(_prefs.copyWith(default3D: selected.first)),
              ),
            ])),
          _switch('Bản đồ tối', 'Tăng tương phản đường khi lái đêm',
            _prefs.darkMap, (v) => _set(_prefs.copyWith(darkMap: v)),
            Icons.dark_mode_outlined),
          _switch('Hiển thị tên đường đang đi',
            'Thanh tên đường gần vị trí GPS',
            _prefs.showCurrentRoadName,
            (v) => _set(_prefs.copyWith(showCurrentRoadName: v)),
            Icons.signpost_outlined),
          _switch('Tự động 3D khi Bắt đầu',
            'Chuyển sang 3D khi chạy chuyến',
            _prefs.auto3DOnStart,
            (v) => _set(_prefs.copyWith(auto3DOnStart: v)),
            Icons.view_in_ar_outlined),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              const Expanded(child: Text('Độ nghiêng 3D',
                style: TextStyle(fontWeight: FontWeight.w700))),
              Text(_prefs.pitchDegrees.round().toString() + '°',
                style: const TextStyle(color: DriverProColors.cyan)),
            ])),
          Slider(min: 50, max: 80, divisions: 6,
            value: _prefs.pitchDegrees,
            onChanged: (v) => _set(_prefs.copyWith(pitchDegrees: v))),
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text('Góc dựng thực tế tối đa 60° trên MapLibre.',
              style: TextStyle(color: DriverProColors.muted, fontSize: 11))),
          const Divider(height: 1, color: Color(0xFF20394F)),
          _row(const _SettingEntry('dashboardSettings', 'Lời chào & cảm ơn',
            'Nội dung hiển thị khi đón và trả khách',
            Icons.waving_hand_outlined)),
        ])),
      ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DriverProColors.background,
    appBar: AppBar(title: const Text('Cài đặt',
      style: TextStyle(fontWeight: FontWeight.w800)),
      actions: const [Padding(padding: EdgeInsets.only(right: 18),
        child: Icon(Icons.tune, color: DriverProColors.cyan))]),
    body: SafeArea(child: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
      children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xFF10436B), Color(0xFF0A1D36)]),
            border: Border.all(color: const Color(0xFF1F6385)),
            borderRadius: BorderRadius.circular(20)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriverProBrand(),
              SizedBox(height: 10),
              Text('Trung tâm điều khiển', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Xe, bảng giá, bản đồ, VietQR và bảo vệ dữ liệu.',
                style: TextStyle(fontSize: 12, color: Color(0xFFD3E6F5))),
            ]),
        ),
        const SizedBox(height: 16),
        TextField(controller: _search,
          onChanged: (s) => setState(() => _query = s),
          decoration: InputDecoration(
            filled: true, fillColor: DriverProColors.panel,
            prefixIcon: const Icon(Icons.search, color: DriverProColors.cyan),
            hintText: 'Tìm trong cài đặt...',
            suffixIcon: _query.isEmpty ? null : IconButton(
              icon: const Icon(Icons.clear), onPressed: () {
                _search.clear();
                setState(() => _query = '');
              }),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DriverProColors.border))),
        ),
        const SizedBox(height: 24),
        for (final section in sections)
          _group(section.$1, section.$2, section.$3),
        _mapGroup(),
        const Center(child: Text(
          'TTX DRIVER PRO • Phiên bản thử nghiệm',
          style: TextStyle(color: DriverProColors.muted, fontSize: 11))),
      ],
    )),
  );
}
