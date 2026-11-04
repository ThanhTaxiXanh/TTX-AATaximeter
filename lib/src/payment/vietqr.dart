import 'package:emv_qr_builder/emv_qr_builder.dart';

/// Only user-entered recipient account data is used for QR creation.
class VietQrAccount {
  const VietQrAccount({
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
  });
  final String bankBin, accountNumber, accountName;

  bool get isValid =>
      RegExp(r'^[0-9]{6}$').hasMatch(bankBin) &&
      RegExp(r'^[A-Za-z0-9]{1,19}$').hasMatch(accountNumber) &&
      accountName.trim().isNotEmpty && accountName.length <= 100;

  Map<String, dynamic> toJson() => {
    'bankBin': bankBin,
    'accountNumber': accountNumber,
    'accountName': accountName,
  };
  factory VietQrAccount.fromJson(Map<String, dynamic> json) => VietQrAccount(
    bankBin: json['bankBin']?.toString() ?? '',
    accountNumber: json['accountNumber']?.toString() ?? '',
    accountName: json['accountName']?.toString() ?? '',
  );


  /// Local EMVCo/NAPAS VietQR payload, no account details sent to a server.
  /// The recipient still must confirm payment in their own banking app.
  String emvPayload({required int amountVnd, required String memo}) {
    if (!isValid || amountVnd < 0 || amountVnd > 9999999999999 ||
        memo.trim().isEmpty || memo.length > 50 ||
        !RegExp(r'^[A-Za-z0-9 ]+$').hasMatch(memo)) {
      throw ArgumentError('Thông tin tạo VietQR không hợp lệ');
    }
    final data = VietQrFactory.createPersonal(
      bankBin: bankBin,
      accountNumber: accountNumber,
      amount: amountVnd == 0 ? null : amountVnd.toString(),
      description: memo.trim(),
    );
    return EmvBuilder.build(data);
  }

  /// Fetching this URL sends account, name, amount and memo to img.vietqr.io.
  /// Call only after explicit user tap in the UI.
  Uri quickLink({required int amountVnd, required String memo}) {
    if (!isValid) throw ArgumentError('Tài khoản ngân hàng không hợp lệ');
    if (amountVnd <= 0 || amountVnd > 9999999999999) {
      throw ArgumentError('Số tiền chuyển khoản không hợp lệ');
    }
    if (memo.trim().isEmpty || memo.length > 50 ||
        !RegExp(r'^[A-Za-z0-9 ]+$').hasMatch(memo)) {
      throw ArgumentError('Nội dung chỉ gồm chữ và số, tối đa 50 ký tự');
    }
    return Uri.https('img.vietqr.io',
      '/image/$bankBin-$accountNumber-compact2.png', {
        'amount': '$amountVnd',
        'addInfo': memo,
        'accountName': accountName.trim(),
      });
  }
}
