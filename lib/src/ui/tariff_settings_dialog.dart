import 'package:flutter/material.dart';
import '../core/taximeter_engine.dart';

class TariffSettingsDialog extends StatefulWidget {
  const TariffSettingsDialog({super.key, required this.current,
    this.companyLabel});
  final TariffConfig current;
  final String? companyLabel;
  @override
  State<TariffSettingsDialog> createState() => _TariffSettingsDialogState();
}

class _FareInput {
  _FareInput(double? end, double rate)
    : end = TextEditingController(text: end?.toString() ?? ''),
      rate = TextEditingController(text: rate.toStringAsFixed(0));
  final TextEditingController end, rate;
  void dispose() { end.dispose(); rate.dispose(); }
}

class _TariffSettingsDialogState extends State<TariffSettingsDialog> {
  late final TextEditingController name = TextEditingController(
    text: widget.companyLabel ?? widget.current.name);
  late final fields = <String, TextEditingController>{
    'base': TextEditingController(text: widget.current.baseFare.toStringAsFixed(0)),
    'baseKm': TextEditingController(text: widget.current.baseDistanceKm.toString()),
    'waiting': TextEditingController(text: widget.current.waitingFeePerHour.toStringAsFixed(0)),
    'waitingGrace': TextEditingController(text: widget.current.waitingGraceMinutes.toString()),
    'speedLimit': TextEditingController(text: widget.current.speedLimitKmh.toString()),
    'accuracy': TextEditingController(text: widget.current.gpsMaxAccuracyMeters.toString()),
    'calibration': TextEditingController(text: widget.current.gpsCalibrationMultiplier.toString()),
  };
  late final List<_FareInput> tiers = widget.current.effectiveFareTiers
      .map((t) => _FareInput(t.upToKm, t.ratePerKm)).toList();
  late bool rounding = widget.current.roundToThousands;
  String? error;

  double parse(String value) => double.parse(value.trim().replaceAll(',', '.'));
  double val(String key) => parse(fields[key]!.text);

  @override
  void dispose() {
    name.dispose();
    for (final c in fields.values) { c.dispose(); }
    for (final t in tiers) { t.dispose(); }
    super.dispose();
  }

  void addTier() {
    if (tiers.length >= 12) return;
    try {
      final start = tiers.length <= 1
          ? val('baseKm') : parse(tiers[tiers.length - 2].end.text);
      final last = tiers.last;
      last.end.text = (start + 10).toString();
      final row = _FareInput(null, parse(last.rate.text));
      setState(() { tiers.add(row); error = null; });
    } catch (_) {
      setState(() => error = 'Nhập đủ đơn giá và mốc km trước khi thêm bậc.');
    }
  }

  void removeTier(int index) {
    if (tiers.length <= 1) return;
    final removed = tiers.removeAt(index);
    tiers.last.end.text = '';
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void save() {
    try {
      if (name.text.trim().isEmpty) {
        throw const FormatException('Tên hãng/bảng giá còn trống');
      }
      final rows = <FareTier>[];
      for (var i = 0; i < tiers.length; i++) {
        rows.add(FareTier(
          upToKm: i == tiers.length - 1 ? null : parse(tiers[i].end.text),
          ratePerKm: parse(tiers[i].rate.text),
        ));
      }
      if (val('base') <= 0 ||
          rows.any((tier) => tier.ratePerKm <= 0)) {
        throw const FormatException(
          'Cước mở cửa và tất cả đơn giá mỗi bậc phải lớn hơn 0');
      }
      final config = TariffConfig(
        name: name.text.trim(),
        baseFare: val('base'),
        baseDistanceKm: val('baseKm'),
        perKmRate: rows.first.ratePerKm,
        longDistanceThresholdKm: rows.first.upToKm ?? val('baseKm'),
        longDistancePerKmRate: rows.last.ratePerKm,
        waitingFeePerHour: val('waiting'),
        waitingSpeedThresholdKmh: widget.current.waitingSpeedThresholdKmh,
        waitingGraceMinutes: val('waitingGrace'),
        speedLimitKmh: val('speedLimit'),
        gpsMaxAccuracyMeters: val('accuracy'),
        gpsCalibrationMultiplier: val('calibration'),
        roundToThousands: rounding,
        fareTiers: rows,
      );
      config.validate();
      Navigator.pop(context, config);
    } catch (e) {
      setState(() => error = 'Lỗi biểu giá: ' + e.toString());
    }
  }

  Widget field(String key, String title, String unit) =>
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: fields[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: title, suffixText: unit,
            border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    backgroundColor: const Color(0xFF101827),
    child: SafeArea(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 570, maxHeight: 850),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            const Expanded(child: Text('BIỂU GIÁ THEO BẬC KM',
              style: TextStyle(fontWeight: FontWeight.w900,
                color: Color(0xFFFFB800)))),
            IconButton(icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
          ])),
        Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
          TextField(controller: name, maxLength: 72,
            decoration: const InputDecoration(
              labelText: 'Tên hãng / bảng giá',
              prefixIcon: Icon(Icons.local_taxi),
              border: OutlineInputBorder())),
          field('base', 'Cước mở cửa', 'đ'),
          field('baseKm', 'Quãng đường trong giá mở cửa', 'km'),
          Row(children: [
            const Expanded(child: Text('CÁC BẬC CƯỚC LŨY TIẾN',
              style: TextStyle(fontWeight: FontWeight.bold,
                color: Color(0xFF00D8F0)))),
            TextButton.icon(onPressed: tiers.length < 12 ? addTier : null,
              icon: const Icon(Icons.add),
              label: const Text('Thêm bậc')),
          ]),
          const Text('Đơn giá của mỗi bậc chỉ tính cho đoạn km thuộc bậc đó. '
            'Bậc cuối luôn không giới hạn.',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
          for (var i = 0; i < tiers.length; i++)
            Card(color: const Color(0xFF1B2437),
              child: Padding(padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('BẬC ' + (i + 1).toString(),
                        style: const TextStyle(
                          color: Color(0xFFFFB800),
                          fontWeight: FontWeight.w800))),
                      if (tiers.length > 1)
                        IconButton(icon: const Icon(Icons.delete_outline),
                          onPressed: () => removeTier(i)),
                    ]),
                    if (i < tiers.length - 1)
                      TextField(controller: tiers[i].end,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Đến mốc km tích lũy',
                          suffixText: 'km', border: OutlineInputBorder())),
                    if (i == tiers.length - 1)
                      const Text('Đến hết hành trình • Không giới hạn'),
                    const SizedBox(height: 10),
                    TextField(controller: tiers[i].rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Đơn giá trong bậc',
                        suffixText: 'đ/km', border: OutlineInputBorder())),
                  ]),
              )),
          const Divider(),
          const Text('PHÍ CHỜ • CẤU HÌNH GPS',
            style: TextStyle(fontWeight: FontWeight.bold,
              color: Color(0xFF00D8F0))),
          field('waiting', 'Phí chờ', 'đ/giờ'),
          field('waitingGrace', 'Bắt đầu tính phí chờ sau', 'phút'),
          const Text('Ví dụ 5 phút: xe dừng hoặc chạy dưới ngưỡng tốc độ '
            'liên tục 5 phút thì mới tính phí cho thời gian tiếp theo. '
            'Khi xe di chuyển trở lại, bộ đếm chờ bắt đầu lại.',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 8),
          field('speedLimit', 'Giới hạn cảnh báo', 'km/h'),
          field('accuracy', 'Độ chính xác GPS', 'm'),
          field('calibration', 'Hệ số hiệu chuẩn', 'x'),
          SwitchListTile(
            value: rounding,
            onChanged: (v) => setState(() => rounding = v),
            title: const Text('Làm tròn cước đến 1.000đ')),
          if (error != null) Text(error!,
              style: const TextStyle(color: Colors.redAccent)),
          const Text('Chỉ dùng các đơn giá đã được người có thẩm quyền xác nhận. '
            'Thông số nhập không được tự động kiểm định.',
            style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
        ])),
        Padding(padding: const EdgeInsets.all(12),
          child: SizedBox(width: double.infinity,
            child: FilledButton.icon(onPressed: save,
              icon: const Icon(Icons.save),
              label: const Text('LƯU BIỂU GIÁ THEO BẬC')))),
      ]),
    )),
  );
}
