import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../payment/vietqr.dart';

String _amountText(num amount) => amount.round().toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

/// Edits only an account entered by the driver, not a reference APK account.
class BankAccountDialog extends StatefulWidget {
  const BankAccountDialog({super.key, this.initial});
  final VietQrAccount? initial;

  @override
  State<BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<BankAccountDialog> {
  late final TextEditingController _bin = TextEditingController(
    text: widget.initial?.bankBin ?? '');
  late final TextEditingController _number = TextEditingController(
    text: widget.initial?.accountNumber ?? '');
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.accountName ?? '');
  String? _error;

  @override
  void dispose() {
    _bin.dispose(); _number.dispose(); _name.dispose();
    super.dispose();
  }

  void _save() {
    final account = VietQrAccount(
      bankBin: _bin.text.trim(),
      accountNumber: _number.text.trim(),
      accountName: _name.text.trim(),
    );
    if (!account.isValid) {
      setState(() => _error = 'Nhập mã BIN 6 số, tài khoản tối đa 19 ký tự chữ/số, tên chủ tài khoản.');
      return;
    }
    Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cấu hình tài khoản VietQR'),
    content: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chỉ nhập thông tin ngân hàng của bạn. '
          'Tài khoản được lưu cục bộ trên điện thoại.'),
        const SizedBox(height: 12),
        TextField(controller: _bin,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Mã BIN ngân hàng (6 chữ số)',
            hintText: 'Ví dụ: 970415 (VietinBank)')),
        TextField(controller: _number,
          maxLength: 19,
          decoration: const InputDecoration(labelText: 'Số tài khoản / Alias')),
        TextField(controller: _name,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Tên chủ tài khoản')),
        if (_error != null) Text(_error!,
          style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 8),
        const Text('Khi mở ảnh QR, ngân hàng, số tài khoản, chủ tài khoản, '
          'số tiền và nội dung sẽ được gửi tới dịch vụ VietQR.',
          style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
      ],
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Hủy')),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

/// Never request remote QR image until user taps 'Tạo mã VietQR'.
class PaymentQrDialog extends StatefulWidget {
  const PaymentQrDialog({
    super.key, required this.account, required this.amountVnd,
    required this.memo,
  });

  final VietQrAccount account;
  final int amountVnd;
  final String memo;

  @override
  State<PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<PaymentQrDialog> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    Uri? uri;
    try {
      uri = widget.account.quickLink(
        amountVnd: widget.amountVnd, memo: widget.memo);
    } catch (_) {
      // Validation error is shown below without firing any network request.
    }
    return AlertDialog(
      title: const Text('Thanh toán VietQR'),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Text(_amountText(widget.amountVnd),
            style: const TextStyle(color: Color(0xFFFFB800),
              fontWeight: FontWeight.bold, fontSize: 28)),
          const SizedBox(height: 8),
          Text('Ngân hàng: ' + widget.account.bankBin),
          Text('Số tài khoản: ' + widget.account.accountNumber),
          Text('Chủ tài khoản: ' + widget.account.accountName),
          Text('Nội dung: ' + widget.memo),
          const SizedBox(height: 12),
          if (uri == null)
            const Text('Không thể tạo liên kết QR: kiểm tra cấu hình tài khoản.'),
          if (!_requested && uri != null)
            FilledButton.icon(
              onPressed: () => setState(() => _requested = true),
              icon: const Icon(Icons.qr_code),
              label: const Text('Tạo mã VietQR'),
            ),
          if (_requested && uri != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: Image.network(
                uri.toString(), width: 270, height: 320,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const SizedBox(height: 260, child:
                        Center(child: CircularProgressIndicator())),
                errorBuilder: (ctx, error, stack) =>
                  const SizedBox(height: 200, child: Center(
                    child: Text('Lỗi tải mã QR. Kiểm tra Internet.'))),
              ),
            ),
          const SizedBox(height: 8),
          const Text('Mã QR không tự xác nhận tiền đã tới tài khoản. '
              'Hãy kiểm tra bằng ứng dụng ngân hàng.',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      )),
      actions: [
        TextButton(
          onPressed: uri == null ? null : () {
            Clipboard.setData(ClipboardData(text: uri!.toString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép liên kết VietQR')));
          },
          child: const Text('Sao chép liên kết')),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng')),
      ],
    );
  }
}
