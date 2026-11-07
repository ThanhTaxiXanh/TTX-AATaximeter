import 'dart:convert';
import 'vietqr.dart';

class SavedBankAccount {
  const SavedBankAccount({
    required this.id, required this.bankName, required this.account,
  });
  final String id, bankName;
  final VietQrAccount account;

  Map<String, dynamic> toJson() => {
    'id': id, 'bankName': bankName, 'account': account.toJson(),
  };
  factory SavedBankAccount.fromJson(Map<String,dynamic> data) {
    final account = VietQrAccount.fromJson(
        Map<String,dynamic>.from(data['account'] as Map));
    if (!account.isValid) {
      throw const FormatException('Tài khoản VietQR không hợp lệ');
    }
    return SavedBankAccount(
      id: data['id']?.toString() ?? '',
      bankName: data['bankName']?.toString() ?? account.bankBin,
      account: account,
    );
  }
}

class BankBook {
  const BankBook({
    this.accounts = const [],
    this.defaultId,
    this.centerLogoPath,
    this.footerLogoPath,
  });
  final List<SavedBankAccount> accounts;
  final String? defaultId, centerLogoPath, footerLogoPath;
  SavedBankAccount? get selected {
    if (accounts.isEmpty) return null;
    for (final x in accounts) {
      if (x.id == defaultId) return x;
    }
    return accounts.first;
  }
  void validate() {
    if (accounts.length > 15) {
      throw const FormatException('Tối đa 15 tài khoản ngân hàng');
    }
    final ids = <String>{};
    for (final x in accounts) {
      if (!x.account.isValid || x.id.isEmpty || !ids.add(x.id)) {
        throw const FormatException('Tài khoản ngân hàng không hợp lệ hoặc trùng');
      }
    }
  }
  BankBook copyWith({
    List<SavedBankAccount>? accounts,
    String? defaultId,
    String? centerLogoPath,
    String? footerLogoPath,
    bool removeCenterLogo = false,
    bool removeFooterLogo = false,
  }) => BankBook(
    accounts: accounts ?? this.accounts,
    defaultId: defaultId ?? this.defaultId,
    centerLogoPath: removeCenterLogo ? null :
        centerLogoPath ?? this.centerLogoPath,
    footerLogoPath: removeFooterLogo ? null :
        footerLogoPath ?? this.footerLogoPath,
  );
  String encode() {
    validate();
    return jsonEncode({
      'version': 1,
      'accounts': accounts.map((x) => x.toJson()).toList(),
      'defaultId': defaultId,
      'centerLogoPath': centerLogoPath,
      'footerLogoPath': footerLogoPath,
    });
  }
  factory BankBook.decode(String input) {
    final data = jsonDecode(input);
    if (data is! Map || data['version'] != 1 ||
        data['accounts'] is! List) {
      throw const FormatException('Dữ liệu tài khoản VietQR lỗi');
    }
    final book = BankBook(
      accounts: (data['accounts'] as List).map((e) =>
          SavedBankAccount.fromJson(Map<String,dynamic>.from(e as Map)))
        .toList(growable: false),
      defaultId: data['defaultId']?.toString(),
      centerLogoPath: data['centerLogoPath']?.toString(),
      footerLogoPath: data['footerLogoPath']?.toString(),
    );
    book.validate();
    return book;
  }
  static BankBook migrateLegacy(VietQrAccount account) => BankBook(
    accounts: [SavedBankAccount(
      id: 'legacy_0', bankName: account.bankBin, account: account)],
    defaultId: 'legacy_0',
  );
}
