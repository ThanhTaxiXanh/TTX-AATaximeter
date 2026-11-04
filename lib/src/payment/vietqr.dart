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
