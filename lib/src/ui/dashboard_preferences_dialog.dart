import 'package:flutter/material.dart';
import '../domain/dashboard_preferences.dart';

class DashboardPreferencesDialog extends StatefulWidget {
  const DashboardPreferencesDialog({super.key, required this.initial});
  final DashboardPreferences initial;
  @override
  State<DashboardPreferencesDialog> createState() =>
      _DashboardPreferencesDialogState();
}

class _DashboardPreferencesDialogState
    extends State<DashboardPreferencesDialog> {
  late DashboardPreferences _draft = widget.initial;
  late final TextEditingController _welcome =
      TextEditingController(text: widget.initial.welcome);
  late final TextEditingController _thanks =
      TextEditingController(text: widget.initial.thanks);
  String? _error;

  @override
  void dispose() {
    _welcome.dispose();
    _thanks.dispose();
    super.dispose();
  }

  void _save() {
    final welcome = _welcome.text.trim(), thanks = _thanks.text.trim();
    if (welcome.isEmpty || thanks.isEmpty ||
        welcome.length > 180 || thanks.length > 180) {
      setState(() => _error = 'Hai lời nhắn phải có nội dung, tối đa 180 ký tự.');
      return;
    }
    Navigator.of(context).pop(_draft.copyWith(
      welcome: welcome, thanks: thanks));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Bản đồ và lời nhắn'),
    content: SizedBox(width: 420,
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lời chào khi đón khách',
            style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('welcome-message'),
            controller: _welcome, maxLength: 180, maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          const Text('Lời cảm ơn khi kết thúc chuyến',
            style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('thanks-message'),
            controller: _thanks, maxLength: 180, maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tự động bật 3D khi Bắt đầu'),
            subtitle: const Text('Kết thúc chuyến trở lại 2D'),
            value: _draft.auto3DOnStart,
            onChanged: (v) => setState(() =>
                _draft = _draft.copyWith(auto3DOnStart: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('3D mặc định khi mở ứng dụng'),
            subtitle: const Text('Cũng được ghi nhớ khi đổi trên bản đồ'),
            value: _draft.default3D,
            onChanged: (v) => setState(() =>
                _draft = _draft.copyWith(default3D: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bản đồ tối (Dark)'),
            subtitle: const Text('Tắt để dùng Light'),
            value: _draft.darkMap,
            onChanged: (v) => setState(() =>
                _draft = _draft.copyWith(darkMap: v)),
          ),
          Text('Góc nghiêng yêu cầu: ' +
            _draft.pitchDegrees.round().toString() + '°',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            key: const Key('map-pitch-slider'),
            min: 50, max: 80, divisions: 6,
            value: _draft.pitchDegrees,
            label: _draft.pitchDegrees.round().toString() + '°',
            onChanged: (v) => setState(() =>
                _draft = _draft.copyWith(pitchDegrees: v)),
          ),
          Text('Góc được dựng thực tế: ' +
            _draft.renderedPitch.round().toString() +
            '°. MapLibre hỗ trợ tối đa khoảng 60° hiện tại.',
            style: const TextStyle(
              fontSize: 11, color: Colors.orangeAccent)),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      )),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Hủy')),
      FilledButton(onPressed: _save, child: const Text('Lưu cài đặt')),
    ],
  );
}
