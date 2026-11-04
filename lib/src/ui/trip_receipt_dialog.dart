import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/trip_record.dart';
import 'fare_breakdown_section.dart';

String _vnd(num n) => n.round().toString()
  .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

/// Receipt reproduced from the two reference walkthroughs.
/// Choosing a payment method is bookkeeping, NOT verified payment.
class TripReceiptDialog extends StatefulWidget {
  const TripReceiptDialog({
    super.key,
    required this.record,
    this.onQr,
  });
  final TripRecord record;
  final VoidCallback? onQr;

  @override
  State<TripReceiptDialog> createState() => _TripReceiptDialogState();
}

class _TripReceiptDialogState extends State<TripReceiptDialog> {
  late PaymentMethod _method = widget.record.paymentMethod;

  Widget _line(String label, num value,
      {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        fontWeight: strong ? FontWeight.bold : FontWeight.normal))),
      Text(_vnd(value), style: TextStyle(
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
    ]),
  );

  String _summary() {
    final r = widget.record;
    return 'TTX AATaximeter\n'
      'Bắt đầu: ' + r.receipt.startedAt.toString() + '\n'
      'Kết thúc: ' + r.receipt.endedAt.toString() + '\n'
      'Điểm đón: ' + r.pickup + '\n'
      'Điểm trả: ' + r.dropoff + '\n'
      'Bảng giá: ' + r.fareProfileName + '\n'
      'Loại xe: ' + r.vehicleType + '\n'
      'Biển số: ' + r.vehiclePlate + '\n'
      'Quãng đường: ' + r.receipt.distanceKm.toStringAsFixed(2) + ' km\n'
      'Cước: ' + _vnd(r.receipt.totalFare) + '\n'
      'Hình thức thanh toán: ' + _method.label;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record.receipt;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      backgroundColor: const Color(0xFF101827),
      child: SafeArea(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        child: SingleChildScrollView(padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: Color(0xFFFFB800)),
                const SizedBox(width: 8),
                const Expanded(child: Text('HÓA ĐƠN CHUYẾN ĐI',
                  style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 10),
              Text(_vnd(r.totalFare),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFB800),
                  fontSize: 35, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (widget.record.fareProfileName.isNotEmpty)
                Text('Bảng giá: ' + widget.record.fareProfileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold)),
              if (widget.record.vehicleType.isNotEmpty)
                Text('Loại xe: ' + widget.record.vehicleType),
              if (widget.record.vehiclePlate.isNotEmpty)
                Text('Biển số: ' + widget.record.vehiclePlate),
              if (widget.record.pickup.isNotEmpty)
                Text('Điểm đón: ' + widget.record.pickup),
              if (widget.record.dropoff.isNotEmpty)
                Text('Điểm trả: ' + widget.record.dropoff),
              Text('Thời gian: ' +
                r.startedAt.toLocal().toString().substring(0, 16) +
                ' → ' + r.endedAt.toLocal().toString().substring(11, 16),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const Divider(),
              Text('Quãng đường: ' + r.distanceKm.toStringAsFixed(2) +
                ' km  •  Thời gian chờ: ' +
                (r.waitingSeconds ~/ 60).toString() + ' phút'),
              const SizedBox(height: 8),
              if (widget.record.tariffSnapshot != null)
                FareBreakdownSection(
                  tariff: widget.record.tariffSnapshot!,
                  distanceKm: r.distanceKm,
                  tripStarted: true,
                  totalFare: r.totalFare,
                  isFlatFare: r.isFlatFare,
                  waitingFare: r.waitingFare,
                  tollFee: r.tollFee,
                  surcharge: r.surcharge,
                  discount: r.discount,
                )
              else ...[
                _line(r.isFlatFare ? 'Cước bao giá' : 'Cước mở cửa',
                  r.baseFare),
                if (!r.isFlatFare) ...[
                  _line('Cước theo km', r.distanceFare),
                  _line('Cước chờ', r.waitingFare),
                ],
                _line('Phí BOT', r.tollFee),
                _line('Phụ thu', r.surcharge),
                _line('Giảm giá', -r.discount),
                const Divider(),
                _line('TỔNG THANH TOÁN', r.totalFare, strong: true),
              ],
              const SizedBox(height: 8),
              const Text('Phương thức thanh toán đã chọn:'),
              Wrap(spacing: 6, children: [
                for (final method in PaymentMethod.values)
                  ChoiceChip(label: Text(method.label),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method)),
              ]),
              const SizedBox(height: 12),
              if (widget.onQr != null)
                OutlinedButton.icon(
                  onPressed: widget.onQr,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Mã VietQR chuyển khoản')),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _summary()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép biên lai')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép nội dung biên lai')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, _method),
                child: const Text('XONG & LƯU PHƯƠNG THỨC'),
              ),
              const Text('Chưa đối soát thanh toán ngân hàng',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.white54)),
          ]),
        ),
      )),
    );
  }
}
