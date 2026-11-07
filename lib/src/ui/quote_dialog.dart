import 'package:flutter/material.dart';
import '../core/taximeter_engine.dart';
import '../domain/quote_calculator.dart';

class QuoteResult {
  const QuoteResult({
    required this.amount,
    required this.distanceKm,
    required this.pickup,
    required this.dropoff,
    required this.twoWay,
  });
  final double amount;
  final double distanceKm;
  final String pickup, dropoff;
  final bool twoWay;
}

class QuoteDialog extends StatefulWidget {
  const QuoteDialog({super.key, required this.tariff});
  final TariffConfig tariff;

  @override
  State<QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<QuoteDialog> {
  final pickup = TextEditingController();
  final dropoff = TextEditingController();
  final distance = TextEditingController(text: '15');
  late final TextEditingController price =
      TextEditingController(text: widget.tariff.perKmRate.toStringAsFixed(0));
  final toll = TextEditingController(text: '0');
  final calculator = const QuoteCalculator();
  bool twoWay = false;
  double returnDiscount = 0.5;

  @override
  void dispose() {
    pickup.dispose(); dropoff.dispose(); distance.dispose();
    price.dispose(); toll.dispose();
    super.dispose();
  }

  double? get quote {
    try {
      final km = double.parse(distance.text.replaceAll(',', '.'));
      final rate = double.parse(price.text.replaceAll(',', '.'));
      final tollFee = double.parse(toll.text.replaceAll(',', '.'));
      if (km <= 0) return null;
      return calculator.estimate(tariff: widget.tariff,
        distanceKm: km, perKmRate: rate, tollFee: tollFee,
        twoWay: twoWay, returnLegDiscount: returnDiscount);
    } catch (_) { return null; }
  }

  String money(double x) => '${x.round()}'
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

  Widget entry(String label, TextEditingController ctl, {IconData? icon,
      TextInputType? type}) => TextField(
    controller: ctl,
    onChanged: (_) => setState(() {}),
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fare = quote;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: const Color(0xFF111829),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF00D8F0)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SafeArea(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.calculate, color: Color(0xFFFFB800)),
                const SizedBox(width: 10),
                const Expanded(child: Text('TÍNH TRƯỚC CƯỚC & LỘ TRÌNH',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                IconButton(icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 10),
              const Text('Nhập điểm đi, điểm đến và số km để tính giá cước '
                'và báo giá cho hành khách.',
                style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 14),
              const Text('LỘ TRÌNH ĐÓN & TRẢ KHÁCH',
                style: TextStyle(color: Color(0xFF00D8F0),
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              entry('Điểm đi / Điểm đón khách', pickup,
                icon: Icons.my_location),
              const SizedBox(height: 10),
              entry('Điểm đến / Điểm trả khách', dropoff,
                icon: Icons.location_on),
              const SizedBox(height: 18),
              entry('Quãng đường dự kiến (km)', distance,
                type: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 8),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final amount in [5, 10, 20, 50, 100])
                  ActionChip(label: Text('+$amount km'),
                    onPressed: () => setState(() {
                      final km = double.tryParse(
                        distance.text.replaceAll(',', '.')) ?? 0;
                      distance.text = (km + amount).toStringAsFixed(0);
                    })),
              ]),
              const SizedBox(height: 16),
              const Text('Loại hành trình:',
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ChoiceChip(label: const Text('1 CHIỀU'),
                  selected: !twoWay, onSelected: (_) =>
                    setState(() => twoWay = false))),
                const SizedBox(width: 8),
                Expanded(child: ChoiceChip(label: const Text('2 CHIỀU'),
                  selected: twoWay, onSelected: (_) =>
                    setState(() => twoWay = true))),
              ]),
              if (twoWay) ...[
                const SizedBox(height: 8),
                const Text('Ước tính giảm cước chiều về — chưa đối chiếu APK',
                    style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                Wrap(spacing: 8, children: [
                  for (final d in [0.3, 0.5, 0.7])
                    ChoiceChip(label: Text('${(d * 100).toInt()}%'),
                      selected: returnDiscount == d,
                      onSelected: (_) => setState(() => returnDiscount = d)),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: entry('Đơn giá (đ/km)', price,
                  type: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(child: entry('Phí BOT (đ)', toll,
                  type: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2437),
                  border: Border.all(color: const Color(0xFFFFB800),width: 1.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text('TỔNG GIÁ BAO TRỌN GÓI',
                    style: TextStyle(color: Colors.white60)),
                  FittedBox(child: Text(fare == null ? '—' : money(fare),
                    style: const TextStyle(color: Color(0xFFFFB800),
                      fontSize: 40, fontWeight: FontWeight.bold))),
                  Text('${distance.text} km • ${twoWay ? '2 chiều' : '1 chiều'}',
                    style: const TextStyle(color: Color(0xFF00D8F0))),
                ]),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: fare == null ? null :
                    () => Navigator.pop(context, QuoteResult(
                      amount: fare, distanceKm: double.parse(
                        distance.text.replaceAll(',', '.')),
                      pickup: pickup.text, dropoff: dropoff.text,
                      twoWay: twoWay,
                    )),
                icon: const Icon(Icons.local_taxi),
                label: const Text('BẮT ĐẦU CUỐC BAO GIÁ'),
              ),
              const SizedBox(height: 4),
              const Text('Bản thử nghiệm; 2 chiều cần kiểm thử hành vi gốc.',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
        ),
      )),
    );
  }
}
