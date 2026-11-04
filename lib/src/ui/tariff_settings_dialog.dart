import 'package:flutter/material.dart';
import '../core/taximeter_engine.dart';

class TariffSettingsDialog extends StatefulWidget {
  const TariffSettingsDialog({super.key, required this.current});
  final TariffConfig current;

  @override
  State<TariffSettingsDialog> createState() => _TariffSettingsDialogState();
}

class _TariffSettingsDialogState extends State<TariffSettingsDialog> {
  late TariffConfig _preset = widget.current;
  late bool _rounding = widget.current.roundToThousands;

  late final Map<String, TextEditingController> _fields = {
    'baseFare': TextEditingController(),
    'baseDistanceKm': TextEditingController(),
    'perKmRate': TextEditingController(),
    'longDistanceThresholdKm': TextEditingController(),
    'longDistancePerKmRate': TextEditingController(),
    'waitingFeePerHour': TextEditingController(),
    'waitingSpeedThresholdKmh': TextEditingController(),
    'speedLimitKmh': TextEditingController(),
    'gpsMaxAccuracyMeters': TextEditingController(),
    'gpsCalibrationMultiplier': TextEditingController(),
  };

  String? _error;
  String _name = '';

  @override
  void initState() {
    super.initState();
    _fill(widget.current);
  }

  void _fill(TariffConfig config) {
    _preset = config;
    _name = config.name;
    _rounding = config.roundToThousands;
    _fields['baseFare']!.text = config.baseFare.toStringAsFixed(0);
    _fields['baseDistanceKm']!.text = config.baseDistanceKm.toString();
    _fields['perKmRate']!.text = config.perKmRate.toStringAsFixed(0);
    _fields['longDistanceThresholdKm']!.text =
        config.longDistanceThresholdKm.toString();
    _fields['longDistancePerKmRate']!.text =
        config.longDistancePerKmRate.toStringAsFixed(0);
    _fields['waitingFeePerHour']!.text =
        config.waitingFeePerHour.toStringAsFixed(0);
    _fields['waitingSpeedThresholdKmh']!.text =
        config.waitingSpeedThresholdKmh.toString();
    _fields['speedLimitKmh']!.text = config.speedLimitKmh.toString();
    _fields['gpsMaxAccuracyMeters']!.text =
        config.gpsMaxAccuracyMeters.toString();
    _fields['gpsCalibrationMultiplier']!.text =
        config.gpsCalibrationMultiplier.toString();
    setState(() => _error = null);
  }

  @override
  void dispose() {
    for (final ctl in _fields.values) { ctl.dispose(); }
    super.dispose();
  }

  double _num(String name) => double.parse(
      _fields[name]!.text.trim().replaceAll(',', '.'));

  void _save() {
    try {
      final value = TariffConfig(
        name: _name,
        baseFare: _num('baseFare'),
        baseDistanceKm: _num('baseDistanceKm'),
        perKmRate: _num('perKmRate'),
        longDistanceThresholdKm: _num('longDistanceThresholdKm'),
        longDistancePerKmRate: _num('longDistancePerKmRate'),
        waitingFeePerHour: _num('waitingFeePerHour'),
        waitingSpeedThresholdKmh: _num('waitingSpeedThresholdKmh'),
        speedLimitKmh: _num('speedLimitKmh'),
        gpsMaxAccuracyMeters: _num('gpsMaxAccuracyMeters'),
        gpsCalibrationMultiplier: _num('gpsCalibrationMultiplier'),
        roundToThousands: _rounding,
      );
      value.validate();
      Navigator.of(context).pop(value);
    } catch (error) {
      setState(() => _error =
          'Giá trị không hợp lệ. Kiểm tra các ngưỡng km và các trường GPS.');
    }
  }

  Widget _entry(String name, String label, {String? unit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _fields[name],
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: false),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _name = 'Biểu giá tùy chỉnh',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = TariffConfig.demo();
    final presets = [
      base,
      base.copyWith(
        name: 'Taxi 7 Chỗ / SUV (chưa đủ thông số)',
        baseFare: 14000, perKmRate: 16500,
      ),
      base.copyWith(
        name: 'Xe Dịch Vụ / Xe Ghép (chưa đủ thông số)',
        baseFare: 15000, perKmRate: 13000,
      ),
      base.copyWith(
        name: 'Sân Bay / Đường Dài (chưa đủ thông số)',
        baseFare: 20000, perKmRate: 12000,
      ),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: const Color(0xFF111829),
      child: SafeArea(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 570, maxHeight: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(child: Text('CÀI ĐẶT BIỂU CƯỚC & GPS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              const Text('BIỂU GIÁ MẪU',
                style: TextStyle(color: Color(0xFFFFB800),
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final preset in presets)
                  ChoiceChip(
                    label: Text(preset.name,
                      style: const TextStyle(fontSize: 11)),
                    selected: _name == preset.name,
                    onSelected: (_) => _fill(preset),
                  ),
              ]),
              const SizedBox(height: 4),
              const Text('Ba mẫu ngoài xe 4 chỗ mới đối chiếu được giá '
                'mở cửa/km từ video; các ngưỡng còn lại chỉ kế thừa mẫu '
                '4 chỗ để chỉnh tiếp. Không sử dụng nếu chưa xác nhận.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              const SizedBox(height: 15),
              _entry('baseFare', 'Cước mở cửa', unit: 'đ'),
              _entry('baseDistanceKm', 'Quãng đường mở cửa', unit: 'km'),
              _entry('perKmRate', 'Đơn giá km tiếp theo', unit: 'đ/km'),
              _entry('longDistanceThresholdKm', 'Bắt đầu tính giá đường dài tại km'),
              _entry('longDistancePerKmRate', 'Giá đường dài', unit: 'đ/km'),
              _entry('waitingFeePerHour', 'Phí chờ mỗi giờ', unit: 'đ/giờ'),
              _entry('waitingSpeedThresholdKmh', 'Ngưỡng tính chờ', unit: 'km/h'),
              _entry('speedLimitKmh', 'Cảnh báo vượt ngưỡng tốc độ', unit: 'km/h'),
              _entry('gpsMaxAccuracyMeters', 'Độ chính xác GPS tối đa', unit: 'm'),
              _entry('gpsCalibrationMultiplier', 'Hệ số hiệu chuẩn GPS'),
              SwitchListTile(
                value: _rounding,
                title: const Text('Làm tròn cước đến 1.000đ'),
                onChanged: (v) => setState(() => _rounding = v),
              ),
              if (_error != null) Text(_error!,
                style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('LƯU CÀI ĐẶT BIỂU CƯỚC & GPS'),
              ),
              const SizedBox(height: 6),
              const Text('Chưa có cấu hình timer GPS 1/2/3/5 giây, LED, '
                'TTS và phát âm thanh. Không thay đổi giá trong chuyến.',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ),
      )),
    );
  }
}
