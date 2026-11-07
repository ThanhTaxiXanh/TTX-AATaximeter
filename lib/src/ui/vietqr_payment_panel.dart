import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../payment/bank_book.dart';
import '../payment/brand_logo_storage.dart';

String _qrCash(num value) => value.round().toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' ₫';

/// Show QR directly on the receipt when the driver selects bank transfer.
class VietQrPaymentPanel extends StatelessWidget {
  const VietQrPaymentPanel({
    super.key, required this.book, required this.amountVnd,
    required this.memo,
    this.onConfigure,
  });
  final BankBook book;
  final int amountVnd;
  final String memo;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final saved = book.selected;
    if (saved == null) {
      return Column(children: [
        const Text('Chưa có tài khoản nhận chuyển khoản.',
          style: TextStyle(color: Colors.orangeAccent)),
        OutlinedButton.icon(
          onPressed: onConfigure,
          icon: const Icon(Icons.account_balance),
          label: const Text('Cài đặt tài khoản ngân hàng')),
      ]);
    }
    late final String payload;
    try {
      payload = saved.account.emvPayload(
        amountVnd: amountVnd, memo: memo);
    } catch (error) {
      return Text('Không tạo được VietQR: ' + error.toString(),
        style: const TextStyle(color: Colors.redAccent));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(saved.bankName, style: const TextStyle(
        fontWeight: FontWeight.w800, color: Color(0xFF151515))),
      Text(saved.account.accountNumber, style: const TextStyle(
        color: Color(0xFF151515))),
      Text(saved.account.accountName, textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF303030))),
      if (amountVnd > 0)
        Text(_qrCash(amountVnd), style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F0F0F))),
      const SizedBox(height: 7),
      SizedBox(width: 274, height: 274, child: Stack(
        alignment: Alignment.center, children: [
          QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 274,
            padding: const EdgeInsets.all(12),
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            errorStateBuilder: (ctx, error) => Text(
              'QR quá dài: ' + error.toString()),
          ),
          if (book.centerLogoPath != null)
            Container(width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 3)),
              child: ClipOval(child: BrandLogoView(
                path: book.centerLogoPath!))),
        ]),
      ),
      if (book.footerLogoPath != null) ...[
        const SizedBox(height: 4),
        SizedBox(width: 268, height: 94,
          child: BrandLogoView(path: book.footerLogoPath!)),
      ],
      const SizedBox(height: 3),
      const Text('Kiểm tra tên và số tài khoản trên app ngân hàng '
        'trước khi chuyển tiền. Mã QR không xác nhận đã nhận tiền.',
        style: TextStyle(fontSize: 10, color: Color(0xFF555555)),
        textAlign: TextAlign.center),
    ]);
  }
}

class PaymentQrDialog extends StatelessWidget {
  const PaymentQrDialog({
    super.key, required this.book, required this.amountVnd,
    required this.memo, this.onConfigure,
  });
  final BankBook book;
  final int amountVnd;
  final String memo;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: SafeArea(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380, maxHeight: 760),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('VIETQR CHUYỂN KHOẢN',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          Container(color: Colors.white,
            padding: const EdgeInsets.all(9),
            child: VietQrPaymentPanel(
              book: book, amountVnd: amountVnd, memo: memo,
              onConfigure: onConfigure)),
          const SizedBox(height: 9),
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Đóng')),
        ]),
      ),
    )),
  );
}
