import 'package:flutter/material.dart';
import '../payment/bank_book.dart';
import 'vietqr_payment_panel.dart';
import '../domain/trip_record.dart';

String _vnd(num n) => n.round().toString()
  .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

/// Receipt reproduced from the two reference walkthroughs.
/// Choosing a payment method is bookkeeping, NOT verified payment.
class TripReceiptDialog extends StatefulWidget {
  const TripReceiptDialog({
    super.key,
    required this.record,
    this.bankBook = const BankBook(),
    this.onConfigureBank,
  });
  final TripRecord record;
  final BankBook bankBook;
  final Future<BankBook?> Function()? onConfigureBank;

  @override
  State<TripReceiptDialog> createState() => _TripReceiptDialogState();
}

class _TripReceiptDialogState extends State<TripReceiptDialog> {
  late PaymentMethod _method = widget.record.paymentMethod ==
      PaymentMethod.card ? PaymentMethod.cash : widget.record.paymentMethod;
  late BankBook _book = widget.bankBook;

  Future<void> _editBank() async {
    final newBook = await widget.onConfigureBank?.call();
    if (mounted && newBook != null) setState(() => _book = newBook);
  }

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
              if (widget.record.vehicleBrand.isNotEmpty)
                Text('Hãng xe: ' + widget.record.vehicleBrand),
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
              _line('Trạm thu phí', r.tollFee),
              if (r.waitingFare > 0)
                _line('Phí chờ', r.waitingFare),
              if (r.surcharge > 0)
                _line('Phụ thu', r.surcharge),
              if (r.discount > 0)
                _line('Giảm giá', -r.discount),
              const Divider(),
              _line('TỔNG THANH TOÁN', r.totalFare, strong: true),
              const SizedBox(height: 8),
              const Text('Phương thức thanh toán đã chọn:'),
              Wrap(spacing: 7, children: [
                for (final method in const [
                  PaymentMethod.cash, PaymentMethod.bankTransfer,
                ])
                  ChoiceChip(
                    label: Text(method.label),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method),
                  ),
              ]),
              if (_method == PaymentMethod.bankTransfer) ...[
                const SizedBox(height: 10),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: VietQrPaymentPanel(
                    book: _book,
                    amountVnd: r.totalFare.round(),
                    memo: 'TTX TAXI',
                    onConfigure: _editBank,
                  ),
                ),
              ],
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
