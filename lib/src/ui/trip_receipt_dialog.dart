import 'package:flutter/material.dart';

import '../core/taximeter_engine.dart';
import '../domain/trip_record.dart';
import '../payment/bank_book.dart';
import 'driver_pro_design.dart';
import 'vietqr_payment_panel.dart';

String _vnd(num n) => n.round().toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

/// TTX Driver Pro receipt. Selecting a payment method is bookkeeping only:
/// showing VietQR must never be confused with confirmation of funds received.
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

  Widget _detail(String label, String value, {
    IconData icon = Icons.receipt_long_outlined,
    bool highlight = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, color: DriverProColors.cyan, size: 17),
      const SizedBox(width: 9),
      Expanded(child: Text(label, style: const TextStyle(
        fontSize: 12, color: DriverProColors.muted))),
      Flexible(child: Text(value,
        textAlign: TextAlign.end, maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12,
          color: highlight ? DriverProColors.amber : Colors.white,
          fontWeight: FontWeight.w800))),
    ]),
  );

  Widget _paymentOption(PaymentMethod method, IconData icon) {
    final selected = _method == method;
    return Expanded(child: InkWell(
      key: Key('driver-pro-payment-${method.name}'),
      onTap: () => setState(() => _method = method),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: selected ? const LinearGradient(colors: [
            DriverProColors.blue, Color(0xFF00A2E9),
          ]) : null,
          color: selected ? null : const Color(0xFF102744),
          border: Border.all(color: selected
            ? DriverProColors.cyan : DriverProColors.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17,
            color: selected ? Colors.white : DriverProColors.muted),
          const SizedBox(width: 5),
          Flexible(child: Text(method.label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : DriverProColors.muted,
              fontSize: 12, fontWeight: FontWeight.w800))),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record.receipt;
    return Dialog(
      key: const Key('driver-pro-receipt'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      backgroundColor: DriverProColors.backgroundDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(21),
        side: const BorderSide(color: DriverProColors.border, width: 1)),
      child: SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 16),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.receipt_long_rounded,
                  color: DriverProColors.cyan, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Hóa đơn chuyến đi',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900))),
                IconButton(
                  tooltip: 'Đóng hóa đơn',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 5),
              const Center(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                    color: DriverProColors.green, size: 19),
                  SizedBox(width: 5),
                  Text('HOÀN THÀNH',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: DriverProColors.green,
                      letterSpacing: 0.6)),
                ],
              )),
              const SizedBox(height: 9),
              DriverProFareCard(
                amount: _vnd(r.totalFare),
                status: MeterStatus.finished),
              const SizedBox(height: 12),
              DriverProPanel(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                child: Column(children: [
                  _detail('Quãng đường',
                    '${r.distanceKm.toStringAsFixed(2)} km',
                    icon: Icons.route_rounded),
                  _detail('Thời gian chuyến',
                    '${r.durationSeconds ~/ 60} phút',
                    icon: Icons.access_time_rounded),
                  _detail('Thời gian chờ tính phí',
                    '${r.waitingSeconds ~/ 60} phút',
                    icon: Icons.hourglass_bottom_rounded),
                  _detail('Trạm thu phí', _vnd(r.tollFee),
                    icon: Icons.toll_outlined),
                  if (r.waitingFare > 0)
                    _detail('Phí chờ', _vnd(r.waitingFare),
                      icon: Icons.timer_outlined),
                  if (r.surcharge > 0)
                    _detail('Phụ thu', _vnd(r.surcharge),
                      icon: Icons.add_circle_outline),
                  if (r.discount > 0)
                    _detail('Giảm giá', '-${_vnd(r.discount)}',
                      icon: Icons.discount_outlined),
                  const Divider(color: DriverProColors.border, height: 12),
                  _detail('Tổng thanh toán', _vnd(r.totalFare),
                    icon: Icons.payments_outlined, highlight: true),
                ]),
              ),
              if (widget.record.fareProfileName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Bảng giá: ${widget.record.fareProfileName}',
                    style: const TextStyle(fontSize: 11,
                      color: DriverProColors.muted))),
              if (widget.record.vehiclePlate.isNotEmpty)
                Text('Xe: ${widget.record.vehicleBrand} '
                  '${widget.record.vehicleType} • '
                  '${widget.record.vehiclePlate}',
                  style: const TextStyle(fontSize: 11,
                    color: DriverProColors.muted)),
              if (widget.record.pickup.isNotEmpty)
                Text('Đón: ${widget.record.pickup}',
                  style: const TextStyle(fontSize: 11,
                    color: DriverProColors.muted)),
              if (widget.record.dropoff.isNotEmpty)
                Text('Trả: ${widget.record.dropoff}',
                  style: const TextStyle(fontSize: 11,
                    color: DriverProColors.muted)),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'Thời gian: ${r.startedAt.toLocal().toString().substring(0, 16)}'
                  ' → ${r.endedAt.toLocal().toString().substring(11, 16)}',
                  style: const TextStyle(fontSize: 11,
                    color: DriverProColors.muted))),
              const SizedBox(height: 11),
              const Text('Thanh toán',
                style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Row(children: [
                _paymentOption(
                  PaymentMethod.cash, Icons.payments_outlined),
                const SizedBox(width: 7),
                _paymentOption(
                  PaymentMethod.bankTransfer, Icons.account_balance_outlined),
              ]),
              if (_method == PaymentMethod.bankTransfer) ...[
                const SizedBox(height: 9),
                DriverProPanel(
                  padding: const EdgeInsets.all(8),
                  borderColor: DriverProColors.cyan,
                  child: Column(children: [
                    const Text('VIETQR',
                      style: TextStyle(color: DriverProColors.cyan,
                        fontSize: 17, fontWeight: FontWeight.w900,
                        letterSpacing: 1.1)),
                    const SizedBox(height: 7),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13)),
                      padding: const EdgeInsets.all(7),
                      child: VietQrPaymentPanel(
                        book: _book,
                        amountVnd: r.totalFare.round(),
                        memo: 'TTX TAXI',
                        onConfigure: _editBank,
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              DriverProAction(
                label: 'Xong và lưu phương thức',
                icon: Icons.check_rounded,
                color: DriverProColors.green,
                darkText: true,
                onPressed: () => Navigator.pop(context, _method),
              ),
              const SizedBox(height: 7),
              const Text(
                'Chọn Chuyển khoản không xác nhận đã nhận tiền. '
                'Vui lòng kiểm tra giao dịch trong ngân hàng.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10,
                  color: DriverProColors.muted)),
            ],
          ),
        ),
      )),
    );
  }
}
